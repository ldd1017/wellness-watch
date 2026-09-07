# WellnessWatch 架构设计

## 一、设计目标

- **快速上线**：单 watchOS App 独立运行，不依赖 iOS 配套宿主也能用
- **零运维成本**：不引入第三方后端，全部使用 Apple 系统 API（HealthKit / UNUserNotificationCenter）
- **可扩展**：4 种 TimerItem kind 用 enum + 协议化设计，新增"喝水提醒""久坐提醒"等只需加枚举值
- **可复用 Manager**：把触发调度逻辑放到单例 `TimerManager`，View 只做显示

## 二、模块边界

```
┌─────────────────────────────────────────────┐
│                 Views (SwiftUI)             │
│   HomeView / TimerListView / EatingView …   │
└──────────────────┬──────────────────────────┘
                   │ @EnvironmentObject
                   ▼
┌─────────────────────────────────────────────┐
│               Managers (singletons)          │
│   TimerManager · HealthManager · …         │
└──────────────────┬──────────────────────────┘
                   │ codable / NSNotification
                   ▼
┌─────────────────────────────────────────────┐
│                 Models + System APIs         │
│   TimerItem · HKHealthStore · …             │
└─────────────────────────────────────────────┘
```

- **Views**：只做状态展示和事件发起，不做调度
- **Managers**：唯一持有调度状态，可被多个 View 共享；标记 `@MainActor` 保证主线程安全
- **Models**：纯值类型（struct），可持久化

## 三、状态机：TimerItem 的生命周期

```
                                add (新建)
                                   │
                                   ▼
                          ┌─────────────────┐
                          │  isEnabled = NO │
                          └────────┬────────┘
                                   │ toggle()
                                   ▼
                          ┌─────────────────┐
                          │  isEnabled = YES │
                          └────────┬────────┘
              ┌────────────────────┼─────────────────────┐
              ▼                    ▼                     ▼
        ┌──────────┐         ┌──────────┐          ┌──────────────┐
        │ repeated │         │  eating  │          │ sleep / bp   │
        │ Foundation.Timer  节律 + 上限 │ 被动触发(到点 / HealthKit 回调)  │
        └──────────┘         └──────────┘          └──────────────┘
              │                                       │
              └─────────→  disarm() / toggle() ←──────┘
                                   │
                                   ▼
                          ┌─────────────────┐
                          │  isEnabled = NO │
                          └─────────────────┘
```

## 四、调度实现要点

### 4.1 多次计时器（Repeated）

- 每条 enabled 的 repeated `TimerItem` 关联一个 `Foundation.Timer.scheduledTimer(repeats:)`
- App 进入后台时被 watchOS 挂起 → 用 `WKExtendedRuntimeSession` 保活，单实例够用
- 触发时调用 `HapticManager.gentle()` 抖动 + 更新 `firedCount`

### 4.2 进食（Eating）

- 用户显式 `timerManager.startEating(itemId:)` 开启会话
- 单个 `Timer(30s repeat)` 检查 `nextTickAt` / `limitAt`，分别触发节律震 / 超限强震
- 每次节律 tick 用 `UNTimeIntervalNotificationTrigger` 预排通知，保证锁屏仍能看到
- 用户停止 → 释放 timer → 收回 `WKExtendedRuntimeSession`

### 4.3 睡眠（Sleep）

- 用 `UNCalendarNotificationTrigger(repeats: true)` 调度，每天到点响一次
- App 不在前台也能触发，不依赖 WKExtendedRuntimeSession
- 编辑时间里 `scheduleSleepNotification(for:)` 用 `removePendingNotificationRequests` 先清旧的，确保只有新的一条

### 4.4 血压（Blood Pressure）

- `HKObserverQuery` 监听 `bloodPressureSystolic` + `bloodPressureDiastolic`
- 系统检测到新样本时回调 `onRiseDetected(systolic, diastolic)`
- `TimerManager.evaluateBloodPressure` 比对：
  - 是否过阈值（默认 140）→ 强震 + 推送
  - 是否比上次高 ≥10 mmHg → 警示震 + 推送"注意情绪"
- 第一次启动需用户授权 HealthKit（`NSHealthShareUsageDescription` 必填）

## 五、扩展指引

新增一种 TimerKind（如 `.hydration`）只需要：

1. **Models/TimerItem.swift**：在 `enum Kind` 加 case，加默认预设工厂
2. **TimerManager.arm(item)**：加 switch case
3. **TimerEditView**：加对应 `Stepper / Picker`
4. **可选**：新建独立 View 展示（如 `HydrationReminderView`）

调度逻辑保持一致：periodic 走 Foundation.Timer + WKExtendedRuntimeSession；被动事件走 Notification / HealthKit。

## 六、性能 & 功耗

- 单实例 `WKExtendedRuntimeSession`：多次计时器 / 进食进行中才激活，平时系统可挂起
- HealthKit observerQuery 只注册一次，backgroundDelivery 频率 `immediate` 但依赖外部血压计推送
- 每次通知最多 3-4 条 pending，避免通知队列堆积
- TimerManager 中 `Timer.publish(every: 1)` 仅用于 View 端时钟显示，App 不在前台时主动 `pause`

## 七、已知限制

- watchOS 不能自动检测"用户在吃饭"，必须手动触发；后续可结合心率变异度尝试自动识别
- 血压数据依赖外部血压计同步（Apple Watch 本身不测血压）
- 仅 watchOS 10+；不支持更早版本（避免 NavigationStack / 新 API 兼容代码膨胀）
