# 没有 Mac 也能调试 Apple Watch App —— 完整指南

## 一、先说结论

| 目标 | 是否需要 Mac |
| --- | --- |
| 写代码（Swift / SwiftUI） | ❌ 不需要 |
| 在 Apple Watch 上跑 App | ✅ 需要（直接或间接） |
| 调试 / 看 log / 改 UI | ✅ 需要 |

Apple 的策略是 **iOS / watchOS App 必须用 Xcode 编译**，而 Xcode **只在 macOS 上有**。所以没 Mac 就**不能本地**调试。

但是！**Mac 不一定要在你手里**。下面三种云端方案 = "租"一台远程 Mac，每月几美元就能搞定。

---

## 二、方案对比

| 方案 | 月成本 | 难度 | 优点 | 缺点 |
| --- | --- | --- | --- | --- |
| **A. GitHub Actions** | $0（公开仓无限 / 私有仓 2000min/月） | ⭐⭐ | 集成仓库、自动化、免费额度足 | 第一次需懂一点 GitHub 配置 |
| **B. Codemagic** | $0（500 min/月免费）→ $59/月付费 | ⭐⭐ | 专为移动 App CI 设计、UI 友好 | 免费额度较少 |
| **C. MacinCloud** | $20-50/月 | ⭐ | 拿完整 Mac 远程桌面，最灵活 | 按小时计费、需保持开机 |

**推荐**：先用 **A. GitHub Actions** 跑通流程，配上 TestFlight / AltStore 装到自己的 iPhone + Apple Watch 上。

---

## 三、推荐路径：云端 CI + AltStore（或 TestFlight）

> **国内用户特别提示**：GitHub 国内访问经常抽风/限速。如果你打不开 github.com，跳到本节末尾的 [§7 国内无翻墙方案](#七国内无翻墙方案)。

### 3.1 一次性准备

#### 1）把代码推到 Git 仓库（任选一个）

```bash
# 在 E:\agent\wellness-watch\ 目录下
cd E:\agent\wellness-watch
git init
git add .
git commit -m "feat: initial watchOS health app"
git branch -M main
git remote add origin https://github.com/你的用户名/wellness-watch.git
git push -u origin main
```

`.github/workflows/build.yml` 已配置好，push 完就会自动跑。

#### 2）注册 Apple Developer 账号（如有）

- **个人** $99/年：解锁 TestFlight / App Store / 真机调试
- **免费** Apple ID：也能装"开发模式"App 到自己 iPhone，但 7 天后过期 + 设备限制 3 台

> 没有开发者账号也能继续：workflow 跑出来的 **未签名 .app** 可以用 **AltStore** 装到自己的 iPhone + Apple Watch（每 7 天自动续签一次）。

#### 3）（可选）导出 P12 证书和 Provisioning Profile

只在你想"自动出可分发 IPA"时需要。手动做的话用朋友的 Mac 一次性导出：

```bash
# 在朋友的 Mac 上
# 1. Apple Developer 网站 → Certificates → 创 iOS App Development / Distribution 证书
# 2. 下载 .cer，双击导入 Keychain
# 3. Keychain Access → 找到证书 → 右键 Export → 保存为 .p12，设密码
# 4. Profiles → 创建 watchOS App Store profile，下载 .mobileprovision

# 把 .p12 和 .mobileprovision 编码成 base64 字符串（GitHub secret 用）
base64 -i cert.p12 | pbcopy
base64 -i profile.mobileprovision | pbcopy
```

### 3.2 跑 workflow

去 GitHub 仓库页面 → Actions → 选 "Build watchOS App" → **Run workflow**

3-5 分钟后会看到两个 artifact：
- `WellnessWatch-unsigned`：未签名的 .app（用于 AltStore）
- `WellnessWatch-signed`：签好名的 .ipa（用于 TestFlight / App Store）—— 仅在你配置了 P12 + Profile 后才有

### 3.3 把 App 装到 iPhone + Apple Watch

#### 路径 A：TestFlight（最稳，需要 $99 开发者账号）

1. 拿 signed IPA → 拖到 [Transporter](https://apps.apple.com/us/app/transporter/id1450874784)（需要 Mac）—— 没 Mac？
2. 用 **`xcrun altool`** 上传：但还是需要 Mac
3. **真无 Mac 方案**：用 **App Store Connect API + GitHub Action 自动上传**
   - 我已准备好一个 `upload-testflight.yml`（见仓库 `.github/workflows/`），配 `APP_STORE_CONNECT_API_KEY_P8` 等 secret 就能自动传

#### 路径 B：AltStore（免费！自己签名）

AltStore 用你的 Apple ID 签 IPA，每 7 天自动续签。流程：

1. iPhone 上装 **AltStore**（从 altstore.io 下载，用自己的 Apple ID 登录）
2. Mac / Windows 装 **AltServer** —— **Windows 也可以！** 不需要 Mac
   - 走 iTunes Wi-Fi 同步通道签 IPA
3. 把 .ipa 传到 iPhone（AirDrop / iCloud / 网盘）
4. AltStore → "Install IPA" 选 .ipa → 装到 iPhone
5. watchOS App 是 iPhone 上的配套 App，**装上 iPhone 后会同步到配对的 Apple Watch**
6. Apple Watch 上打开 wellness-watch App 即可

> 详细步骤：[altstore.io/faq](https://altstore.io/faq)

#### 路径 C：用朋友的 Mac 临时调试

最简单粗暴：借一台 Mac，30 分钟搞定：
1. 装 Xcode 15
2. clone 仓库
3. 改 swift 代码看效果 → Cmd+R 真机跑

---

## 四、调试体验对比

| 操作 | 本地 Mac + Xcode | GitHub Actions + AltStore |
| --- | --- | --- |
| 改一行代码 → 看到效果 | 5 秒 | 5 分钟 |
| 看 console log | 实时 | 只能 NSLog 到 os_log，事后查 |
| 打断点 | ✅ | ❌ |
| HealthKit 调试 | 模拟器可注入假数据 | 真机实测 |

**实务建议**：
- 日常功能迭代 / 布局调整：走 CI 5 分钟一版，够用
- 性能 / 多线程 bug：必须借 Mac

---

## 五、本仓库已配的 CI 资源

```
wellness-watch/
├── .github/workflows/
│   └── build.yml              ← GitHub Actions 主构建
├── project.yml                ← XcodeGen 配置（自动生成 .xcodeproj）
├── scripts/
│   ├── build-signed-ipa.sh    ← 签名脚本（依赖 P12 secret）
│   └── ExportOptions.plist    ← xcodebuild export 配置
└── WellnessWatch/Resources/
    └── WellnessWatch.entitlements  ← HealthKit entitlement
```

push 到 GitHub 即可开箱即用。

---

## 六、常见问题

**Q1：免费 Apple ID 能跑吗？**
能，但 App 7 天后过期，AltStore 可以自动续签。

**Q2：GitHub Actions 的 2000 分钟够吗？**
watchOS 构建 + 签名 + 测试每次 3-5 分钟。每月跑 200 次内都免费。

**Q3：能不能直接用 iPad 写代码？**
写可以（Textastic / a-shell），但**不能**编译 watchOS App。App Store 限制。

**Q4：Codemagic 比 GitHub Actions 好在哪？**
- 自动管理证书
- 微信式扫码登录
- 免费 500 分钟 / 月，付费起 $59/月
- 界面更友好

如果你想试 Codemagic，告诉我，我把 `codemagic.yaml` 也加进仓库。

**Q5：我能不能用 iPhone 装个 `swiftc` 直接编译？**
不能。iOS App Store 沙盒禁止运行编译器/链接器。即使越狱，watchOS 工具链也只能在 macOS 上跑。

**Q6：Xcode Cloud 呢？**
Xcode Cloud 是 Apple 官方云端构建，但**仍需要 Apple Developer 账号 + macOS 客户端**才能配置。

---

## 七、国内无翻墙方案

GitHub 在国内经常打不开 / 限速，但 CI 不止 GitHub 一家。下面 5 个方案都能国内直连：

| 平台 | 域名 | macOS 免费 | 难度 | 备注 |
| --- | --- | --- | --- | --- |
| **Codemagic** | codemagic.io | 500 min/月 | ⭐⭐ | **最推荐**，专为移动 App CI，国内能直连 |
| GitLab.com | gitlab.com | 400 min/月 | ⭐⭐ | 国内可直连，配 .gitlab-ci.yml |
| Appcircle | appcircle.io | 100 min/月 | ⭐⭐ | 拖拽配置，国内能访问 |
| Bitrise | bitrise.io | 200 min/月 | ⭐⭐⭐ | 海外大厂常用 |
| Coding.net（腾讯） | coding.tencent.com | 企业版才有 | — | 个人项目不推荐 |
| 极狐 GitLab | jihulab.com | 申请制 | — | 国内 SaaS，需申请 |

**首选：Codemagic**

1. 注册 https://codemagic.io（用 GitHub / Google / 邮箱都行）
2. 关联一个 Git 仓库（GitHub / GitLab / Bitbucket，**但 Codemagic 不直接支持 Gitee**，要先 import 到 GitLab）
3. 项目根目录已备好 `codemagic.yaml`
4. 第一次构建会自动跑，下载 `WellnessWatch-unsigned` artifact
5. 后续修改 .yaml 文件，push 触发自动构建

**备选：GitLab.com**

1. 注册 https://gitlab.com（国内可直连）
2. 推代码：`git remote add gitlab https://gitlab.com/<你的用户名>/wellness-watch.git && git push -u gitlab main`
3. 项目根目录已备好 `.gitlab-ci.yml`
4. GitLab → CI/CD → Pipelines 查看构建
5. 默认会要求开启 SaaS macOS runner：项目 Settings → CI/CD → Runners → Enable instance runners

**备选：Appcircle**

1. 注册 https://appcircle.io
2. Add New App → 选 "Self-Managed" → 接 Git 仓库
3. 选择 iOS / watchOS 构建模板
4. Web 界面配置 signing、profile（不需要命令行）

### 国内 Git 仓库怎么选

| 仓库 | 国内可直连 | 配 CI 难度 |
| --- | --- | --- |
| Gitee（码云） | ✅ 最稳 | 个人版 Gitee Go 只有 Linux runner，不能跑 xcodebuild |
| GitLab.com | ✅ | SaaS macOS runner 申请制 |
| GitCode（CSDN） | ✅ | CI 较弱 |
| 极狐 GitLab SaaS | ✅ | 类似 GitLab.com |
| 阿里云 CodeUp | ✅ | macOS runner 收费 |
| **腾讯云开发者**（Coding） | ✅ | macOS runner 收费 |

**实操推荐组合**：
- 代码 → Gitee（最稳，不丢）
- 构建 → Codemagic 或 GitLab.com（macOS runner 真正能跑）
- 二者通过 GitLab import / mirror 关联

### 把 Gitee 镜像到 GitLab 一行搞定

在 Gitee 仓库 → 设置 → 镜像管理 → 添加 GitLab 仓库地址，保存后 Gitee 每次 push 自动同步。

### 公司 / 学校有 Mac 怎么办

如果有同学 / 同事 / 老师有 Mac，借 30 分钟：
1. 装 Xcode
2. clone 仓库
3. `xcodegen generate` 生成 .xcodeproj
4. Xcode 打开 → 真机调试（Cmd+R）
5. archive 导出一个可分发 .ipa
6. 发给你

### 自己电脑跑 macOS 虚拟机

技术可行但**非常不推荐**：
- VMware / VirtualBox + macOS Sonoma ISO
- 启动后跑 Xcode
- 但 watchOS Simulator 性能极差，**HealthKit 在 VM 里跑不通**
- 仅适合尝鲜，不适合真正开发

### 网吧 / 公共 Mac

一些大学机房、苹果店体验区有 Mac，但**不持久**——一次构建 5-10 分钟够用，但导出后你得用网盘传回来。

---

## 八、终极最简：付费远程 Mac

如果你发现 CI 限制太多（macOS runner 不够、签名麻烦、想断点调试），最简单是**花点小钱租远程 Mac**：

| 服务 | 价格 | 形态 |
| --- | --- | --- |
| MacinCloud | $20/月 起 | 远程桌面，按小时 |
| MacStadium | $50/月 起 | 专业云 Mac |
| Hetzner | €30/月 | 自建 Mac mini（高级） |
| Scaleway | €5/月 | Apple Silicon 云实例 |

**适合**：CI 不够用 + 偶尔需要真机调试的人。

---

## 九、推荐路径总结

按用户场景选：

- **只想让 App 跑起来看效果** → GitHub Actions / Codemagic + AltStore + 免费 Apple ID（$0）
- **国内 GitHub 不稳** → Codemagic（最稳）+ GitLab.com（备选）
- **正式上架 App Store** → 借 Mac 配签名 + TestFlight → 上架
- **专业开发** → 买 Apple Developer ($99) + 借 Mac + Xcode Cloud

**多数个人项目**：$0 方案足够。第一周跑通流程后，第二次开始就只是改代码 → push → 5 分钟后装到 watch。
