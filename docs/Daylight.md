Daylight 架构设计文档（Architecture Design）

目标版本：适用于 MVP，但为未来完整产品功能预留所有关键架构位。
原则：MVP 做最少，但架构为 1.0–3.0 做准备，不走回头路，不积累技术债。

目录

产品形态与演进阶段

架构设计原则

客户端架构（分层结构）

设计系统（Design System）

数据模型（Domain Models）

本地数据存储与迁移策略

后端架构（轻后端，可演进）

API 版本化与未来扩展

登录与会员机制的预留

模块化与项目结构

未来演进路线（从 MVP → 1.0 → 2.0）

1）产品形态与演进阶段（Product Lifecycle）

Daylight 最终会是一款有「用户体系 + 会员 + 权益管理 + 多平台同步」的产品。
但 MVP 阶段只做最小功能：白昼承诺、夜间守护、灯链记录。

完整演进路线：

Phase 0 – MVP（无账号，本地为主）

匿名用户

本地存储 DayRecord

本地推送

UI 仅包含「今日之灯 + 灯链 + 白昼/夜间弹窗」

Phase 1 – 账号 + 云同步 + 会员（Pro）

登录（手机号 / 邮箱 / Apple Sign-in）

云同步历史数据

会员订阅（App Store / Play Store）

会员增值功能：主题 / 增强提醒 / 高级报告

Phase 2 – 完整服务化

行为分析

设备多端同步（Pad / Web）

企业合作接口（可选）

更多内容与干预链路

本架构文档的宗旨就是：Phase 0 的代码结构，不阻碍 Phase 1、Phase 2。

2）架构设计原则

分层清晰：UI / Domain / Data 分离

所有策略与配色集中在 Design System，不散落在页面

所有数据访问通过 Repository，不允许 UI 直接读写数据库或 API

数据模型必须可演进： versioned schema + migration

API 从第一天就必须版本化（/v1/…）

所有可选未来功能（登录 / 会员 / 多主题）要在 Domain 预留接口，不影响 MVP 代码结构

即使现在不做登录，也要用 user_id（匿名）作为全系统主键

提交的架构要被未来 1.0 产品“认可”，不能为 MVP 写“临时方案”

3）客户端架构（Client Architecture）
3.1 三层结构（推荐 iOS/Android 通用架构）
Presentation （UI 层）
Domain        （领域逻辑）
Data          （数据访问）

3.2 每层职责
Presentation 层（UI）

所有页面、组件、动效、主题

ViewModel / Presenter / Controller（按平台）

不依赖数据库/网络，不包含业务规则

Domain 层（核心逻辑）

核心模型（User、Subscription、DayRecord、Settings）

业务逻辑 UseCase：

SetDayCommitment

ConfirmSleep

GetStreak

GetUserEntitlements

Repository 接口（抽象层）：

UserRepository

DayRecordRepository

SettingsRepository

SubscriptionRepository（预留）

Data 层（具体实现）

LocalDataSource

RemoteDataSource

RepositoryImpl（封装 local + remote）

UI 层永远不能直接访问 Local / Remote DataSource，只能通过 Domain。

4）设计系统（Design System）

Daylight 必须从 Day 1 定义 Design System，即使只有一种主题。

4.1 Colors（颜色）
const Colors = {
  daylightGold: '#FFDCA8',
  daylightGoldDeep: '#FFB950',
  moonlightBlue: '#A9CFFF',
  moonlightBlueDeep: '#6FAFFF',
  backgroundLight: '#FFFFFF',
  backgroundDark: '#2A2E4A',
  textPrimary: '#1A1A1A',
  textSecondary: '#6F7583',
  grayLight: '#E0E0E0'
};

4.2 Typography（字体）
const Typography = {
  titleLarge: { fontSize: 24, fontWeight: '600' },
  titleMedium: { fontSize: 20, fontWeight: '500' },
  body: { fontSize: 16, fontWeight: '400' },
  caption: { fontSize: 12, fontWeight: '400' }
};

4.3 Spacing（间距）

统一 px 值：4, 8, 12, 16, 20, 24, 32, 40

4.4 Theme（主题预留）
interface Theme {
  colors: Colors;
  typography: Typography;
}


未来会员 Pro 可把主题作为权益。

5）数据模型（Domain Models）
5.1 User（预留账号体系字段）
type User = {
  id: string;               // UUID（匿名）
  deviceId: string;
  createdAt: string;
  lastActiveAt: string;
  email?: string;
  phone?: string;
  appleId?: string;
  locale?: string;
  timezone?: string;
};

5.2 Subscription（未来 Pro / Free）
type Subscription = {
  userId: string;
  plan: "free" | "pro_monthly" | "pro_yearly";
  status: "active" | "expired" | "cancelled";
  startedAt: string;
  expiredAt?: string;
};

5.3 Entitlements（未来功能开关）
type EntitlementKey = "max_history_days" | "advanced_themes" | "weekly_report";

type Entitlement = {
  key: EntitlementKey;
  value: number | boolean | string;
};

5.4 DayRecord（核心）
type DayRecord = {
  userId: string;
  date: string;                // YYYY-MM-DD  
  commitmentText?: string;
  dayLightStatus: "ON" | "OFF";
  nightLightStatus: "ON" | "OFF";
  sleepConfirmedAt?: string;
  nightRejectCount: number;
  updatedAt: string;
  version: number;             // 未来用于迁移
};

5.5 Settings
type Settings = {
  userId: string;
  dayReminderTime: string;       // "11:00"
  nightReminderStart: string;    // "22:30"
  nightReminderEnd: string;      // "00:30"
  nightReminderInterval: number; // min
  nightReminderEnabled: boolean;
  version: number;
};

6）本地数据存储与迁移（Local Storage）
6.1 存储方案

iOS：CoreData / SQLite / Realm / MMKV

Android：Room / DataStore / SQLite

MVP 建议：Key-Value + JSON 本地文件即可快速实现

6.2 版本化（关键）

每个模型需携带 version 字段：

schemaVersion = 1;


未来若字段变化，则：

schemaVersion +1

App 启动时读取旧版

Domain 层执行数据迁移

回写新版

确保永远不会因数据结构变动导致崩溃。

7）后端架构（轻后端，可演进）
7.1 架构风格

REST API

Node.js / Go / Python 任意

简单 monolith 服务即可

7.2 模块

Auth（匿名，未来账号）

DayRecord

Settings

Subscription（预留）

Entitlements（预留）

7.3 数据库

可使用：

PostgreSQL（推荐）

MySQL

Firestore（备选）

7.4 后端核心能力（MVP）

匿名用户注册（返回 user_id & token）

上传/查询 DayRecord

上传/查询 Settings

之后再拓展：

Subscription API

Entitlement API

Analytics API

8）API 版本化（Versioning）

所有 API 必须从第一天使用版本前缀：

/v1/auth/anonymous
/v1/day-records
/v1/settings


将来添加：

/v1/subscriptions
/v1/entitlements
/v1/moods
/v1/reports


无论 MVP 多简单，都不能没有版本前缀。

9）登录与会员机制的预留（关键点）
现在不实现，但必须在架构上准备：
9.1 登录（未来）

AuthRepository（Domain 层定义接口）

RemoteAuthDataSource（Data 层）

MVP：用匿名实现即可。

9.2 会员逻辑（未来）

SubscriptionRepository（Domain 层定义接口）

Domain 层 UseCase：GetUserEntitlements

UI 层访问 isPro 即可

UI 不要直接判断 “plan === pro”，要走：

if (userState.isPro) {
  ...
}

9.3 付费墙（未来）

在 Domain 层定义 FeatureGate.ts：

function checkFeature(featureKey: EntitlementKey): boolean;


UI 只问 Domain，不直接看会员状态。

10）模块化与项目结构（客户端）

推荐目录结构：

src/
  ui/
    screens/
    components/
    theme/
  domain/
    models/
    usecases/
    repositories/
  data/
    local/
    remote/
    repositories/
  core/
    utils/
    error/
    config/


全部业务都要严格分层放置，不允许以下做法：

❌ UI 直接调用 API
❌ UI 直接访问数据库
❌ 后端字段直接硬编码在 UI
❌ 颜色/字体写在页面内
❌ 会员逻辑直接写在 UI

11）未来演进路线（MVP → 1.0 → 2.0）
MVP（你当前阶段）

无账号

本地存储 DayRecord

本地推送

简单云备份（可有可无）

1.0（正式版）

登录

多设备同步

APP 内订阅

主题系统

增加“周报告 / 月报告”

2.0（进阶版）

行为分析（复发预测）

短内容库（AI 动机语 + 夜间轻陪伴）

分享系统

结语

MVP 只实现最小功能，但架构必须为完整产品而设计。
所有扩展点必须已经预留接口与结构。

Daylight 的架构现在已经可支持未来多年演进，不会出现“大翻修”或“技术债爆炸”的情况。