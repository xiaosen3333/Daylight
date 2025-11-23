# Daylight 核心功能规格（MVP + 实现细节）

版本：v0.2  
范围：今日之灯 / 夜间守护 / 灯链  
对象：客户端工程师 / 后端工程师 / 设计 / QA

目录
- 文档范围与最佳实践
- 时间 / 时区 / 切日规则（关键）
- 功能概览
- 核心功能规格（今日之灯 / 夜间守护 / 灯链）
- 流程图 & 状态机
- 通知策略 & 权限降级
- 设计系统组件 & UI 约束
- API / DTO / 错误码 / 速率
- 同步 / 待同步队列 / 冲突与重试
- 离线 / 迁移 / 回滚决策表
- 样例数据 & 关键测试用例
- 埋点 / 日志事件
- 性能与安全

## 文档范围与最佳实践
- 目标：在 MVP 阶段确保“行为稳定可验证”，并为多设备/会员扩展留接口。
- 分层要求：UI 仅通过 UseCase/Repository；所有时间/日期计算统一规则；错误与重试有明确策略。
- 交付预期：阅读后可直接实现功能、测试与验收，不留灰区。
- 当前阶段（MVP）说明：无后端接入，所有读写走本地存储（JSON + Keychain）；API/上传/冲突逻辑可保留接口与开关，默认使用 stub/mock，便于未来接入云同步。

## 时间 / 时区 / 切日规则（关键）
- 序列化：所有时间字段使用 ISO8601 + UTC + 毫秒，示例 `2025-01-09T15:10:00.123Z`；上传服务器必须转 UTC。
- date 定义：`date = 本地时区的年月日`。即使上传时刻已经跨 UTC 日，也不得改动 date。
- 夜间窗口跨日：22:30–23:59 归当日；00:00–00:30 仍归前一天。
  - 伪代码：
    ```
    if nowLocal in [nightStart, 23:59] -> date = today
    else if nowLocal in [00:00, nightEnd] -> date = today - 1
    ```
- DST：使用系统本地时间；切换日不重复提醒，不因 DST 回退导致日期回到前一天。

## 功能概览
- 今日之灯：白天写承诺/动机，点亮白昼灯。
- 夜间守护：夜间高风险时段提醒，确认睡觉点亮夜间灯。
- 灯链：以每天两盏灯为颗粒度，呈现坚持情况与详情。

## 核心功能规格
### 1) 今日之灯（白昼承诺）
- 触发条件：到达 `Settings.dayReminderTime`（默认 11:00，本地）且当日 `dayLightStatus = OFF`。
- 用户流程：提醒→弹窗/通知→输入或选择推荐理由→点亮白昼灯。
- 推荐理由（本地数组 3–9 条，MVP内置，可扩展AB）：
  ```
  明天醒来不会讨厌自己。
  精神好一点，明天的工作压力小很多。
  早点睡就能早点结束今天的不开心。
  给身体一些休息的时间，它一直在替你扛着。
  早起会更轻松，生活节奏更顺一点。
  不用靠咖啡硬撑，省钱又健康。
  为喜欢的事保留更多精力。
  早点睡，你会发现世界对你温柔很多。
  ```
- 输入约束：1–80 字；超长不再接受输入（不截断已有文本）；支持 Emoji。
- 按钮状态：空输入 `disabled`；提交中 `loading`（若有网络写）；正常 `enabled`。
- 错误文案：空输入 “请写一句话作为承诺”；写入失败 “已保存到本地，将在网络恢复后同步”。
- 完成动作：`commitmentText` 写入，`dayLightStatus=ON`，`updatedAt=now`，灯亮动效；在线尝试上传。
- 验收（节选）：提醒必达一次；提交后主界面灯亮并展示承诺前若干字；离线可用，复开 App 不重复弹窗。

### 2) 夜间守护（睡觉确认）
- 触发条件：当日 `dayLightStatus=ON`，`nightLightStatus=OFF`，时间在 `[nightReminderStart, nightReminderEnd]`（默认 22:30–00:30，跨日规则见上），夜间提醒开启。
- 用户流程：提醒→弹窗/通知→展示承诺全文→选择“我现在要睡觉”或“继续玩手机”。
- 行为：
  - 睡觉：`nightLightStatus=ON`，`sleepConfirmedAt=now`，`updatedAt=now`，灯亮动效，上传。
  - 继续玩：`nightRejectCount += 1`，轻遗憾动效；不退出 App。
- 约束：文本必须为当天的 `commitmentText`；提醒次数达上限不再提醒。
- 验收（节选）：仅当日有白昼灯才提醒；点击睡觉后主界面/灯链夜间灯亮；超过最大次数后不再弹窗。

### 3) 灯链（Light Chain）
- 展示默认 7 天（MVP可扩至 30 天）；每天显示上下两灯（白昼/夜间）。
- 状态：ON 有颜色+光晕；OFF 灰色无光。当前日期灯组描边突出。
- 点击一天进入详情，展示日期/双灯状态/承诺/睡觉时间/简短评价（本地生成即可）。
- 验收（节选）：灯状态与本地 DayRecord 一致；无网仍展示缓存；详情数据一致。

## 流程图 & 状态机（mermaid）
### 白昼承诺
```
flowchart TD
  A[每日11:00 本地时间] --> B{今天有 DayRecord?}
  B -- 否 --> C[创建 DayRecord(date=今天)]
  B -- 是 --> D[读取 DayRecord]
  C --> D

  D --> E{dayLightStatus == ON?}
  E -- 是 --> F[不弹窗，结束]
  E -- 否 --> G[展示 白昼承诺弹窗/通知]

  G --> H[用户输入/选择承诺文本]
  H --> I[点击 点亮白昼之灯]
  I --> J[更新 commitmentText]
  J --> K[dayLightStatus = ON; updatedAt = now]
  K --> L[触发灯亮动效]
  L --> M[尝试上传服务器(异步)]
```

### 夜间守护
```
flowchart TD
  A[夜间提醒时间点触发] --> B[读取当天 DayRecord]
  B --> C{dayLightStatus == ON ?}
  C -- 否 --> D[不提醒，结束]
  C -- 是 --> E{nightLightStatus == OFF ?}
  E -- 否 --> F[已点亮夜间灯，不再提醒]
  E -- 是 --> G[展示夜间守护弹窗/通知]

  G --> H{用户选择}
  H -- 我现在要睡觉 --> I[更新 nightLightStatus = ON]
  I --> J[sleepConfirmedAt = now; updatedAt = now]
  J --> K[灯亮动效 + 上传服务器]

  H -- 继续玩手机 --> L[nightRejectCount += 1]
  L --> M[轻遗憾动效]
  M --> N[判断还有没有剩余提醒次数]
```

### DayRecord 状态机
```
stateDiagram-v2
  [*] --> NONE

  NONE: 无记录
  DAY_OFF_NIGHT_OFF: 未承诺 / 未睡觉
  DAY_ON_NIGHT_OFF: 已承诺 / 未睡觉
  DAY_ON_NIGHT_ON: 已承诺 / 已确认睡觉

  NONE --> DAY_OFF_NIGHT_OFF: 创建 DayRecord
  DAY_OFF_NIGHT_OFF --> DAY_ON_NIGHT_OFF: 设置承诺 / 点亮白昼灯
  DAY_ON_NIGHT_OFF --> DAY_ON_NIGHT_ON: 夜间确认睡觉
```

## 通知策略 & 权限降级
- 白昼提醒：默认 11:00；内容示例 `title: 为今晚的你留一句话`，`body: 如果今晚不熬夜，你会得到什么？`，点开跳转白昼弹窗。
- 夜间提醒：默认 22:30–00:30，间隔 30min；每晚最多 4 次；前提：当日白昼灯 ON 且夜间灯 OFF。
- 权限被拒：
  - 前台：仍弹 App 内弹窗。
  - 后台：无法推送；用户下一次进入时，若白昼/夜间未完成且在窗口，立即弹对应弹窗。
- 节流表：
  - 点击“我现在要睡觉”：取消当晚后续夜间提醒。
  - 点击“继续玩手机”：仅累加 `nightRejectCount`，不影响后续提醒。
  - 超过最大次数：当晚不再提醒。
  - 夜间提醒重置：本地 03:00（夜间行为的绝对结束时间）。

## 设计系统组件 & UI 约束
- 组件：LightLamp、LightCard、CommitmentModal、NightPromptModal、LightChainStrip、Primary/Secondary Button。
- 字号（需支持 Dynamic Type）：标题 24/SemiBold；弹窗标题 20/SemiBold；正文 16–17/Regular；次要 14–15；灯链日期 12–13。
- 间距：容器上下 24、左右 16；组件间 24–32；文本与按钮 16。
- 动效：灯亮 600ms 轻弹；灯暗 400ms；使用系统 ease-out / ease-in-out。
- 无障碍：文本对比度 ≥ 4.5:1；触控区域 ≥ 44x44pt；VoiceOver 读出灯状态；图标必须有 label，不仅靠颜色。
- 输入与按钮：白昼承诺 1–80 字；空时按钮 disabled；提交中 loading；本地写入不需 loading，但网络失败不阻塞流程。
- 错误提示：空输入提示；写入失败提示“已保存到本地，将在网络恢复后同步”；夜间弹窗失败提示“现在无法同步，但不会影响使用。”

## API / DTO / 错误码 / 速率
- 匿名注册 `POST /v1/auth/anonymous`
```
{ "device_id": "ios-uuid-123", "platform": "ios", "app_version": "1.0.0" }
=> { "user_id": "u_123456", "api_token": "token_abcdefg" }
```
- 上传 DayRecords 批量 `POST /v1/day-records/batch`
```
{
  "records": [
    {
      "date": "2025-01-08",
      "commitment_text": "明早醒来不会讨厌自己。",
      "day_light_status": "ON",
      "night_light_status": "OFF",
      "sleep_confirmed_at": null,
      "night_reject_count": 1,
      "updated_at": "2025-01-08T03:20:00Z"
    }
  ]
}
```
- 查询区间 `GET /v1/day-records?start_date=2025-01-01&end_date=2025-01-10`
- 错误格式：
```
{ "error": { "code": "UNAUTHORIZED", "message": "Invalid token", "details": {} } }
```
- 建议错误码：UNAUTHORIZED / INVALID_INPUT / SERVER_ERROR / RATE_LIMITED。
- 速率限制（建议）：写 10 次/分钟/用户；读 60 次/分钟/用户。
- 客户端重试：网络/5xx 指数退避 2/4/8/16/30s；4xx 不重试（除非用户重复提交）。

## 同步 / 待同步队列 / 冲突与重试
- 待同步文件格式：
```
{
  "pending": [
    {
      "type": "day_record",
      "payload": { ...DayRecord... },
      "retry_count": 0,
      "last_try_at": "2025-01-09T15:10:00Z"
    }
  ]
}
```
- 重试策略：1→2s，2→4s，3→8s，4→16s，5+→30s（上限 1 分钟间隔）；永不放弃。
- 冲突决策：本地更新更晚 → 本地赢；服务器更晚 → 服务器赢；同时间 → 服务器赢（保守）；MVP 全部静默，不提示用户。
- 冲突 payload 示例已在上方 API 部分；多设备并发视服务器版本为权威（updated_at 最大）。

## 离线 / 迁移 / 回滚决策表
| 场景 | 本地 | 服务器 | 采用 | 行为 |
| ---- | ---- | ------ | ---- | ---- |
| 初次使用无网 | 无 | 无 | 本地 | 创建 DayRecord，标记 PENDING |
| 本地有，服务器无 | 有 | 无 | 本地 | 上传本地记录 |
| 本地较新 | 有 | 有 | 本地 | 覆盖服务器 |
| 服务器较新 | 有 | 有 | 服务器 | 覆盖本地，可选保留旧版日志 |
| 时间相同 | 有 | 有 | 任意 | 保持现状 |
| 两设备同一天 | A/B | 有 | 服务器 | 以服务器最新为准（late updatedAt） |

- 回滚：客户端可选保留每条 DayRecord 的 `previousVersion`（一层）；服务端可有历史版本表（MVP 不暴露）。迁移失败需记录日志并尝试回滚备份文件。

## 样例数据 & 关键测试用例
### 样例数据
```
{
  "user_id": "u_demo",
  "settings": {
    "day_reminder_time": "11:00",
    "night_reminder_start": "22:30",
    "night_reminder_end": "00:30",
    "night_reminder_interval": 30,
    "night_reminder_enabled": true
  },
  "day_records": [
    {
      "date": "2025-01-08",
      "commitment_text": "明早醒来不会讨厌自己。",
      "day_light_status": "ON",
      "night_light_status": "OFF",
      "sleep_confirmed_at": null,
      "night_reject_count": 2
    },
    {
      "date": "2025-01-09",
      "commitment_text": "明天要开会，不想顶着黑眼圈。",
      "day_light_status": "ON",
      "night_light_status": "ON",
      "sleep_confirmed_at": "2025-01-09T15:10:00Z",
      "night_reject_count": 1
    },
    {
      "date": "2025-01-10",
      "commitment_text": null,
      "day_light_status": "OFF",
      "night_light_status": "OFF",
      "sleep_confirmed_at": null,
      "night_reject_count": 0
    }
  ]
}
```

### 关键用例（QA）
- 白昼承诺：正常输入点亮；用推荐理由点亮；空输入禁用按钮；离线点亮 → 重启 → 在线同步。
- 夜间守护：当日有白昼灯才提醒；点击睡觉灯亮并写 sleepConfirmedAt；未承诺不弹窗；连续拒绝至上限后停提醒。
- 灯链：连续 3 天双灯亮呈连续高亮；某天夜间未点亮显示断点；点击历史日详情一致。
- 离线 & 同步：断网写承诺和点灯，网络恢复自动上传；服务器挂掉 pending 不丢；服务器 newer 覆盖本地。
- 时间窗口：22:30–23:59 属当日；00:00–00:30 属前一日；00:31 之后不再提醒；夜间关闭提醒则全晚不提醒。
- 输入限制：80 字含 Emoji 可输入；>80 停止输入。
- 多设备冲突：A 离线点夜间灯，B 在线先点夜间灯，最终以服务器（B）为准。

## 埋点 / 日志事件
- 生命周期：app_open / app_background / app_install_first_open
- 白昼：day_prompt_shown(date, source)；day_commitment_set(date, text_len, from_suggestion)；day_commitment_cancel(date)
- 夜间：night_prompt_shown(date, remind_round)；night_confirm_sleep(date, time, remind_round)；night_reject_sleep(date, time, remind_round)
- 灯链：streak_view(range_days)；streak_day_tap(date)
- 同步：sync_upload(count, success_count, conflict_count)；sync_conflict(date, reason)；sync_error(code)

## 性能与安全
- 本地敏感：Keychain 存 user_id/token；DayRecord 内容不强制加密（MVP），未来市场合规可加密数据库。
- UI 性能：页面切换 <100ms；灯亮动效 60fps（在主线程只做渲染，计算放后台/动画驱动）；灯链支持 30–60 天展示需复用或虚拟列表。
