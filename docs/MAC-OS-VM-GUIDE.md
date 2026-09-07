# 在自己电脑上跑 macOS 虚拟机 — 无 Mac 时的最后一招

> **不推荐**作为常规开发方式（性能差、HealthKit 不工作），但**能跑出可装到真机的 .app**。
> 适合"有 Windows 笔记本 + 不愿意花钱租 Mac + 看得见 Apple Watch 装上" 的场景。

## 一、准备

### 硬件最低要求

| 项 | 最低 | 推荐 |
| --- | --- | --- |
| CPU | Intel i5 / AMD Ryzen 5（4 核） | i7 / Ryzen 7（8 核） |
| 内存 | 16 GB | 32 GB |
| 硬盘 | 80 GB 可用空间 | SSD 120 GB |
| macOS 镜像 | 10 GB ISO |  |

### 软件

- **VMware Workstation Player**（Windows 免费 / 个人使用）
  - 下载：https://www.vmware.com/products/workstation-player.html
  - macOS unlock patch（让 VMware 支持 macOS 客户机）
- 或者 **VirtualBox**（免费，但性能更差）
- **macOS Sonoma IPSW**（Apple 官方系统镜像）

## 二、安装步骤（Windows 上为例）

### 1. 安装 VMware

略。注意：VMware Workstation **Pro 版**才能跑 macOS 客户机，或者用 Player + unlocker patch。

### 2. 装 unlocker

```cmd
# 下载 auto-unlocker
git clone https://github.com/paolo-projects/auto-unlocker.git
cd auto-unlocker
# 右键 → 以管理员身份运行 unlocker.exe
```

成功后 VMware 会多出 "Apple Mac OS X" 客户机类型。

### 3. 创建 macOS 客户机

- File → New Virtual Machine
- 选 "Apple Mac OS X" → macOS 14 (Sonoma)
- 内存分 8-16 GB
- 硬盘 80-120 GB
- 处理器 4-8 核

### 4. 装 macOS

- 从 [黑果小兵](https://blog.daliansky.net/) 或远景论坛下载 macOS Sonoma ISO
- 挂到 VM 的光驱
- 启动 → 跑 macOS 安装器
- 抹盘 → APFS → 安装
- 跑完后进系统

## 三、VM 内的 Xcode 构建

### 1. 装 Xcode

```bash
# VM 内 App Store 搜 Xcode 安装（12 GB）
# 或者命令行
xcode-select --install
xcodebuild -version  # 验证
```

### 2. 装 XcodeGen

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install xcodegen
```

### 3. 把代码弄到 VM 里

方法：
- **共享文件夹**：VMware 设置共享 Windows 目录
- **iCloud Drive**：从 Windows 同步文件夹
- **scp**：VM 装 sshd，Windows 用 scp 推
- **微信传文件**：最简单

### 4. 构建

```bash
cd /path/to/wellness-watch
bash scripts/build-local-mac.sh
```

会输出 `out/WellnessWatch-unsigned.app.tar.gz`，拷回 Windows。

## 四、传到 iPhone + Apple Watch

1. 把 `WellnessWatch-unsigned.app.tar.gz` 拷到 Windows
2. 解压得 `WellnessWatch.app`
3. 通过 AirDrop / iCloud Drive / 微信传 .app 到 iPhone
4. iPhone 装 **AltStore**（参考前面指南）
5. AltStore → Install → 选 .app
6. 配对的 Apple Watch 自动同步

## 五、VM 跑 watchOS App 的限制

| 功能 | VM 内 | 真 Apple Watch |
| --- | --- | --- |
| xcodebuild 编译 | ✅ | — |
| 模拟器调试 | ❌ watchOS 模拟器需要 Metal，VM 不支持 | — |
| HealthKit 测试 | ❌ 模拟器无真实数据 | ✅ |
| 触感反馈模拟 | ✅ 模拟器有触感菜单 | ✅ |
| 通知 | ✅ 模拟器能弹 | ✅ |
| 装到真机 | ✅ 出 .app 即可 | ✅ |

**结论**：VM 主要用来**出可装 .app**。真正调试必须真机（借或租 Mac）。

## 六、VM 跑 SwiftUI 预览

SwiftUI Preview 在 VM 里**完全不可用**（Metal 不支持）。要预览 UI：

- 装到真机看（VM 出 .app → iPhone 装）
- 或直接写代码靠脑补（不推荐）

## 七、替代：Hackintosh

如果你**有台式机**，可以装 **黑苹果**（直接在硬件上装 macOS），比 VM 快 5-10 倍。

需要：
- 兼容硬件清单：见 https://dortania.github.io/OpenCore-Install-Guide/
- 通常：Intel 7-10 代 / AMD 需打补丁
- N 卡需要 web driver，A 卡免驱

技术门槛高，但**性能 + 体验接近真 Mac**。

## 八、终极总结

| 方案 | 成本 | 时间 | 体验 |
| --- | --- | --- | --- |
| 借 Mac 30 分钟 | ¥0 | 30 分钟 | ⭐⭐⭐⭐⭐ |
| 淘宝远程 Mac | ¥5-20 | 5 分钟 | ⭐⭐⭐⭐ |
| 极狐 GitLab SaaS | 申请制 | 1 天 | ⭐⭐⭐ |
| 自己 VM | ¥0 | 半天装系统 + 半天装 Xcode | ⭐⭐ |
| 黑苹果 | ¥0 + 折腾 | 1-3 天 | ⭐⭐⭐⭐ |

**实际上对国内非翻墙用户，借 Mac 30 分钟仍然是综合最优解**。
