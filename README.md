# WellnessWatch · 健康守护

Apple Watch 上的健康提醒 app。覆盖四个场景：

| 场景 | 行为 |
| --- | --- |
| 🍴 **进食提醒** | 按节律（如每 10 分钟）温柔提醒，达到上限（如 30 分钟）强力震 + 锁屏推送"放下筷子，不要再吃那么多" |
| 🌙 **睡眠提醒** | 到点（默认 23:30）推送"该睡觉啦"+ 触感震动 |
| ❤️ **血压升高** | 监听 HealthKit 收缩压，超过阈值（默认 140 mmHg）触发强震"深呼吸，不要冲动"；上次->本次升高 ≥10 mmHg 也会预警 |
| ⏱ **多次计时器** | 任意间隔重复震动（如 5 分钟一次），可并行多个 |

## 一、技术栈

- **平台**：watchOS 10+（SwiftUI 现代 API）
- **架构**：MVVM + 单例 Manager（避免 watchOS 上内存过载）
- **数据持久化**：`UserDefaults` + `JSONEncoder`
- **后台运行**：`WKExtendedRuntimeSession`（多次计时器 / 进食会话进行中）
- **系统集成**：`HKHealthStore` observerQuery、`UNUserNotificationCenter`、`WKHapticType`
- **无障碍**：所有交互元素含 `accessibilityLabel`；触感反馈分语义（gentle / warning / strong）

## 二、目录结构

```
wellness-watch/
├── README.md
├── docs/
│   └── ARCHITECTURE.md
└── WellnessWatch/                  ← Xcode watchOS App target
    ├── WellnessWatchApp.swift      ← @main 入口
    ├── ContentView.swift           ← TabView 主框架
    ├── Models/
    │   └── TimerItem.swift         ← 计时器领域模型（4 种 kind）
    ├── Managers/
    │   ├── HapticManager.swift     ← 触感反馈封装
    │   ├── NotificationManager.swift ← 本地通知封装
    │   ├── HealthManager.swift     ← HealthKit 血压监听
    │   ├── TimerManager.swift      ← 多计时器调度中枢
    │   └── ReminderManager.swift   ← 全局文案/阈值偏好
    ├── Views/
    │   ├── HomeView.swift          ← 主页（概览 + 快速入口）
    │   ├── TimerListView.swift     ← 所有计时器列表
    │   ├── TimerEditView.swift     ← 新建 / 编辑计时器
    │   ├── EatingReminderView.swift ← 吃饭节律专用页
    │   ├── SleepReminderView.swift  ← 睡眠时间配置
    │   ├── BloodPressureView.swift  ← 血压阈值 / 当前读数
    │   ├── RemindersView.swift      ← 提醒分类聚合页
    │   └── SettingsView.swift      ← App 设置
    └── Resources/
        └── Info.plist              ← 含 HealthKit / 通知说明文案
```

## 三、调试与构建

### 情况 A：你在 Mac 上（标准流程）

1. 启动 Xcode → File → New → Project
2. 选择 **watchOS → App**
3. 配置：
   - Product Name: `WellnessWatch`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - 不勾选 "Include Notification Scene"（本 App 已用 UNUserNotificationCenter）
4. 把 `WellnessWatch/` 整个目录里的 `Models / Managers / Views` 拖进 Xcode 工程，勾选 "Copy items if needed"、"Add to target: WellnessWatch"
5. 替换 Xcode 生成的 `WellnessWatchApp.swift` 和 `ContentView.swift` 为本仓库里的版本
6. 把 `Resources/Info.plist` 的内容合并进工程的 Info.plist（重点保留 `NSHealthShareUsageDescription`）
7. 在 Signing & Capabilities → + Capability → **HealthKit**
8. 选择调试目标为你的 Apple Watch Series 6+，运行即可

> 也可以跳过手动步骤：用 `xcodegen` + `project.yml` 自动生成 .xcodeproj，CI/脚本里都更方便。

### 情况 B：你只有 iPhone + Apple Watch（**无 Mac**）

详细见 [`docs/NO-MAC-BUILD-GUIDE.md`](docs/NO-MAC-BUILD-GUIDE.md)。简述：

1. 代码 push 到 GitHub
2. `.github/workflows/build.yml` 自动跑（macos-14 runner，**免费 2000min/月**）
3. 下载未签名 .app → 用 **AltStore** 装到 iPhone（Windows / Mac 都能跑 AltServer）
4. iPhone 上配对的 Apple Watch 自动同步 App
5. 打开 wellness-watch，震动、通知、HealthKit 全跑通

每 7 天 AltStore 自动续签一次。完全免费。

## 四、用法速览

启动 App 后第一个 Tab（Home）显示当前状态卡：

- **进食卡**：若未启动 eating session，则显示橙色"开始"按钮；进入 `EatingReminderView` 选已有计时器或新建并启动
- **血压卡**：显示 HealthKit 最近一次读数（橙色/红色提示超阈）
- **睡眠卡**：显示下次睡眠提醒倒计时
- **多次计时计数**：下方小卡显示当前激活的 repeated 计时器数量

新建多次计时器：
1. 第二个 Tab（提醒列表）→ 右上 "+" → 类型选 "多次计时" → 滑块选 5 分钟 → 保存
2. 列表行最右侧拨到 ON 即可启动

修改全局文案 / 阈值：
1. 第四个 Tab（设置）→ "全局文案" 改任意提示语 → 下次触发自动应用

## 五、未来路线

- **V2**：iOS 配套 App（微信小程序 / iOS App）做配置同步
- **V3**：接入 Core ML on-device，根据心跳 / 心率变异度 (HRV) 提前预测压力
- **V3+**：watchOS 上的实时健康算法：心率异常联动降压提醒
