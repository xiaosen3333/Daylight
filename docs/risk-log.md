# Daylight 风险清单

- 范围：iOS SwiftUI MVP（Today/LightChain/Settings），基于 `Daylight` 方案。
- 更新时间：2025-11-26。

## 风险明细
1. 【高】连续天数计算忽略日期连续性  
   - 位置：`Daylight/Domain/UseCases/DaylightUseCases.swift:181`  
   - 现象：缺失日期也被计入 streak；例如仅有 11/01 与 11/03 完成，`current/longest` 仍为 2。  
   - 影响：灯链统计与用户实际完成情况不一致。  
   - 建议：按日期递减遍历时校验是否为前一天，否则重置计数（使用 `Calendar.isDate(_:equalTo:toGranularity:)`）。

2. 【高】“今日”键未考虑夜间窗口  
   - 位置：`Daylight/Presentation/Today/TodayView.swift:241`、`Presentation/LightChain/LightChainPage.swift:25/39` 等。  
   - 现象：夜窗 22:30–00:30 内（如 00:10）写入落在前一日，但 UI/灯链按自然日显示，导致 CTA/统计错位。  
   - 建议：统一使用 `dateHelper.localDayString(nightWindow:)` 生成 todayKey，并在 View/卡片/加载月数据处复用。

3. 【高】跨日不刷新 UI/状态  
   - 位置：`Daylight/Presentation/Today/TodayView.swift` & `TodayViewModel.refreshAll()`  
   - 现象：午夜后不主动刷新，仍停留在前一日的 record，CTA/统计/通知调度基于旧数据。  
   - 建议：监听日期边界（定时器或 `scenePhase` 前台事件），对比 `localDayString(nightWindow:)` 变化，触发 `refreshAll()` 并重排通知。

4. 【高】通知内容跨天失真  
   - 位置：`Daylight/Core/Utils/NotificationScheduler.swift:50-115` + `TodayViewModel.scheduleNotifications()`  
   - 现象：日/夜通知使用重复触发器且上下文源于当前 record，跨天后仍推送前一日的“有承诺/承诺内容”。  
   - 建议：每日生成当日 context 的非重复通知，或在 0 点/前台唤醒时重排，先用 `localDayString(nightWindow:)` 生成当日 key。

5. 【中】日迹查询缺少 userId 过滤  
   - 位置：`Daylight/Data/Repositories/DayRecordRepositoryImpl.swift:16,44,51`。  
   - 现象：`record(for:)`、`records(in:)`、`latestRecords` 仅按日期过滤。未来引入账号/多用户时会串读他人数据。  
   - 建议：查询/写入都带 `userId` 过滤；`DayRecordLocalDataSource.loadAll()` 返回后按 `userId` 筛选。

6. 【中】待同步队列仅入队不出队；设置上传错误被吞  
   - 位置：`Daylight/Data/Repositories/DayRecordRepositoryImpl.swift:21-41`、`SettingsRepositoryImpl.swift:23-27`。  
   - 现象：无重试/出队逻辑，`pending_ops.json` 可能无限增长；设置上传失败静默。  
   - 建议：增加后台重放（前台/网络恢复时批量上传并 `removePending`），设置上传失败时提示或入队。

7. 【中】夜间提醒固定 2 次，间隔配置不生效  
   - 位置：`Daylight/Core/Utils/NotificationScheduler.swift:50-115`。  
   - 现象：只使用两个 `nightReminderIds`，长窗口（如 22:00–02:00，间隔 20 分钟）仍只触发前两次。  
   - 建议：根据窗口长度 + 间隔动态生成触发次数；授权请求与 reschedule 解耦，避免重复弹窗。

8. 【低】设置页改动无节流，频繁落盘与调度通知  
   - 位置：`Daylight/Presentation/Settings/SettingsPage.swift:22-81`。  
   - 现象：拖动时间/输入昵称会多次写文件并触发通知重排，增加耗电且可能重复授权提示。  
   - 建议：对保存操作添加 debounce（~300–500ms），昵称提交可改为失焦或“完成”按钮提交。

## 优先级建议
- P0：问题 1、2、3、4 —— 保证核心数据/通知正确性与日切刷新。
- P1：问题 5、6、7 —— 同步可靠性、提醒次数符合配置、多用户安全。
- P2：问题 8 —— 体验与能耗优化。
