#!/usr/bin/env bash
# scripts/build-local-mac.sh
# 在任何 macOS 机器上跑一次就能出 WellnessWatch.unsigned.app
#
# 用法：
#   bash scripts/build-local-mac.sh
#
# 输出：
#   out/WellnessWatch-unsigned.app.tar.gz    未签名版（AltStore 用）
#   out/WellnessWatch.app/                   解压后的 .app
#
# 跑完直接把 out/WellnessWatch-unsigned.app.tar.gz 拖到 iPhone → AltStore 安装。

set -euo pipefail

cd "$(dirname "$0")/.."

# 1. 检查环境
echo "→ 检查环境..."
if ! command -v xcodebuild &>/dev/null; then
  echo "❌ xcodebuild 不存在。请装 Xcode：xcode-select --install 或 App Store 装 Xcode"
  exit 1
fi

if ! command -v xcodegen &>/dev/null; then
  echo "→ 装 XcodeGen..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/null
  brew install xcodegen
fi

xcodebuild -version
xcodegen --version

# 2. 生成 .xcodeproj
echo "→ 生成 Xcode 工程..."
xcodegen generate --spec project.yml

# 3. 编译
echo "→ 编译 watchOS App（首次需 3-5 分钟）..."
mkdir -p build out
xcodebuild \
  -project WellnessWatch.xcodeproj \
  -scheme WellnessWatch \
  -configuration Release \
  -archivePath build/WellnessWatch.xcarchive \
  -destination 'generic/platform=watchOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  ONLY_ACTIVE_ARCH=NO \
  archive

# 4. 打包
echo "→ 打包 .app..."
cp -R build/WellnessWatch.xcarchive/Products/Applications/WellnessWatch.app out/
(cd out && tar czf WellnessWatch-unsigned.app.tar.gz WellnessWatch.app)

# 5. 输出
echo ""
echo "============================================="
echo "  ✅ 构建完成"
echo "============================================="
echo "  产物：out/WellnessWatch-unsigned.app.tar.gz"
echo "  体积：$(du -h out/WellnessWatch-unsigned.app.tar.gz | cut -f1)"
echo ""
echo "  下一步："
echo "  1. 把 .tar.gz 传回 iPhone（AirDrop / 微信文件 / iCloud）"
echo "  2. 解压得到 WellnessWatch.app"
echo "  3. 用 AltStore 打开 → Install → 选 .app"
echo "  4. 配对的 Apple Watch 自动同步"
echo "============================================="
