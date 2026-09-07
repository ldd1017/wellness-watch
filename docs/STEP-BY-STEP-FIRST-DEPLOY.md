# 端到端：第一次把 App 装到 Apple Watch

> 全程约 30 分钟。**需要**：Windows 电脑 + iPhone + Apple Watch + GitHub 账号 + 免费 Apple ID

---

## 流程总览

```
[1] push 代码          5 分钟
    ↓
[2] GitHub Actions     3-5 分钟（自动）
    ↓
[3] 下载 .app          1 分钟
    ↓
[4] iPhone 装 AltStore  3 分钟
    ↓
[5] Windows 装 AltServer  3 分钟
    ↓
[6] AltStore 装 .app    2 分钟
    ↓
[7] Apple Watch 同步    自动
```

---

## [1] push 代码到 GitHub

### A. 准备 PAT（Personal Access Token）

1. 登录 https://github.com
2. 右上头像 → Settings → Developer settings (最下面)
3. Personal access tokens → Tokens (classic) → **Generate new token**
4. Note: `wellness-watch-push`
5. Expiration: 90 days（够用）
6. Scopes 勾选：`repo` (全选)
7. 点 **Generate token**
8. **复制 token 字符串**（只显示一次！建议粘贴到记事本）

### B. 创建 GitHub 仓库

1. https://github.com/new
2. Repository name: `wellness-watch`
3. 选 **Private**（私有仓库，省心）
4. **不要**勾选 Add README / .gitignore / license（避免冲突）
5. 点 **Create repository**
6. 复制仓库 URL（形如 `https://github.com/你的用户名/wellness-watch.git`）

### C. push 代码（Windows PowerShell）

打开 PowerShell：

```powershell
cd E:\agent\wellness-watch

# 1. 初始化 git
git init
git config user.name "你的名字"
git config user.email "你的邮箱"

# 2. 提交
git add .
git commit -m "feat: initial watchOS health app"

# 3. 关联远程仓库
git remote add origin https://github.com/你的用户名/wellness-watch.git

# 4. push（用户名 = GitHub 用户名，密码 = PAT 粘贴）
git branch -M main
git push -u origin main
```

如果 push 时弹出登录框，username 填 GitHub 用户名，password 填 PAT（不是 GitHub 密码）。

### D. 一键脚本

如果嫌命令多，仓库里有 `scripts/push-to-github.ps1`（Windows）或 `scripts/push-to-github.sh`（macOS / Linux），改下参数跑一次即可。

---

## [2] 触发 GitHub Actions

push 完会自动触发。也可以手动触发：

1. 打开 https://github.com/你的用户名/wellness-watch
2. 顶栏点 **Actions**
3. 左侧选 "Build watchOS App"
4. 右侧 **Run workflow** → 选 main 分支 → 绿色按钮
5. 等 3-5 分钟（首次会下 Xcode 工具链，慢一点）

跑完页面会显示 ✅。

---

## [3] 下载 .app

1. 在 Actions 页面点进这次构建（绿色 ✅ 那一行）
2. 滚到最下面 **Artifacts** 区域
3. 下载 `WellnessWatch-unsigned`（zip 约 2-3 MB）
4. 解压得 `WellnessWatch.app`

---

## [4] iPhone 装 AltStore

1. iPhone 打开 App Store
2. 搜 "AltStore"，**别下错成山寨的**
3. 装上 AltStore
4. 打开 AltStore → Settings → Sign in with Apple ID
   - 用**免费 Apple ID** 即可（不需要 $99 的开发者）
   - 第一次会让你信任证书：Settings → General → VPN & Device Management → 信任

---

## [5] Windows 装 AltServer

1. https://altstore.io 点 **Download AltServer for Windows**
2. 下载安装
3. 用数据线把 iPhone 连到 Windows
4. 第一次需要装 iTunes + Apple Mobile Device Support
   - iTunes 装好 → 信任 iPhone
5. AltServer 会显示托盘图标
6. 点托盘图标 → **Install AltStore** → 选你的 iPhone
7. 输 Apple ID + 密码（iPhone 上 AltStore 那个）
8. 装完后 iPhone 上会多一个 AltStore App

> **首次配对后可以拔数据线**，后续 Wi-Fi 即可（保持 iPhone 和电脑同 Wi-Fi 即可续签）。

---

## [6] AltStore 装 .app

1. iPhone 打开 AltStore
2. 底部 **My Apps** 标签
3. 左上 **+** → 选 `WellnessWatch.app`
4. 等 30 秒，App 装到 iPhone 主屏

---

## [7] Apple Watch 自动同步

1. iPhone 打开刚装好的 **WellnessWatch** App 一次（要点开，等 3 秒）
2. watchOS 自动把配套 watchOS App 装到配对的 Apple Watch
3. Apple Watch 上找 App（按下数码表冠，进 App 列表）→ 点 WellnessWatch
4. **享受震动、通知、HealthKit 全跑通！**

---

## 7 天后会自动过期？

会的。免费 Apple ID 签的 App **7 天后失效**。但 AltServer 会自动续签：

- iPhone 和 Windows 在同 Wi-Fi
- Windows 上 AltServer 后台常驻
- 第 7 天凌晨自动续签（你什么都不用做）

> 如果你不想让 Windows 一直开机，可以用 `scripts/refresh-altstore.ps1`（待写）手动触发续签。

---

## 常见问题

**Q1：iPhone 上找不到 AltStore？**
进 App Store → 搜索 → 装。**不要用国区 Apple ID 搜**（可能被下架）。如果搜不到，把 Apple ID 切到美区 / 香港区。

**Q2：AltServer 连不上 iPhone？**
- 装 iTunes 后重启
- Windows 服务里确认 "Apple Mobile Device Service" 已启动
- 重启 AltServer

**Q3：HealthKit 没数据？**
- iPhone 装第三方血压计 App（如 Qardio、欧姆龙），同步数据进 Health App
- 第一次打开 WellnessWatch 时同意 HealthKit 权限
- 等 1-2 分钟让 HealthKit 索引数据

**Q4：build 报错？**
去 Actions 日志看：
- `error: Cannot find type 'X' in scope` → 哪个 swift 文件没被加进 Sources
- `Provisioning profile ... doesn't include ...` → 签名相关（我们走 unsigned 应该没这问题）

**Q5：AltStore 装完闪退？**
第一次打开会弹"未受信任的企业级开发者"对话框，去 iPhone Settings → General → VPN & Device Management → 信任。

---

## 下次再改代码

```powershell
cd E:\agent\wellness-watch
# 改任意 .swift 文件
git add .
git commit -m "fix: 改了啥"
git push
# → GitHub Actions 自动跑 → 3 分钟出新 .app → 下载 → AltStore 装
```

**5 分钟迭代一次**，足够日常开发。
