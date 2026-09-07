#!/usr/bin/env bash
# scripts/build-signed-ipa.sh
# 在 GitHub Actions macos runner 中使用，签名 .p12 + Provisioning Profile，
# 输出 WellnessWatch.ipa。
#
# 前提：在仓库 Settings → Secrets and variables 配置了：
#   secrets.MACOS_CERT_P12           base64 编码的 .p12 证书
#   secrets.MACOS_CERT_PASSWORD      .p12 密码
#   secrets.KEYCHAIN_PASSWORD        临时 keychain 密码（任意强密码）
#   vars.APPLE_TEAM_ID               Apple Developer Team ID
#   secrets.APPSTORE_PROVISIONING_PROFILE  base64 编码的 .mobileprovision
#
# 本地手动跑也可以：export 上述变量后 bash scripts/build-signed-ipa.sh

set -euo pipefail

TEAM_ID="${APPLE_TEAM_ID:-}"
P12_B64="${MACOS_CERT_P12:-}"
P12_PASS="${MACOS_CERT_PASSWORD:-}"
KC_PASS="${KEYCHAIN_PASSWORD:-TempKeychainPass2026!}"
PROV_B64="${APPSTORE_PROVISIONING_PROFILE:-}"
PROV_NAME="WellnessWatch_WatchOS_App_Store.mobileprovision"

if [ -z "$P12_B64" ] || [ -z "$TEAM_ID" ] || [ -z "$PROV_B64" ]; then
  echo "skip signed build: missing required env"
  exit 0
fi

# 1. 解码证书和 profile
mkdir -p ~/signing
echo "$P12_B64" | base64 --decode > ~/signing/cert.p12
echo "$PROV_B64" | base64 --decode > ~/signing/$PROV_NAME

# 2. 建临时 keychain 装证书
security create-keychain -p "$KC_PASS" /tmp/wb.keychain
security set-keychain-settings -lut 21600 /tmp/wb.keychain
security unlock-keychain -p "$KC_PASS" /tmp/wb.keychain
security list-keychains -d user -s /tmp/wb.keychain $(security list-keychains -d user | tr -d '"')

security import ~/signing/cert.p12 -k /tmp/wb.keychain -P "$P12_PASS" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KC_PASS" /tmp/wb.keychain

# 3. 注册 provisioning profile
mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
cp ~/signing/$PROV_NAME ~/Library/MobileDevice/Provisioning\ Profiles/

# 4. 用 xcodebuild archive + export 产生 IPA
xcodebuild \
  -project WellnessWatch.xcodeproj \
  -scheme WellnessWatch \
  -destination 'generic/platform=watchOS' \
  -archivePath build/WellnessWatch-Signed.xcarchive \
  -configuration Release \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Apple Distribution" \
  PROVISIONING_PROFILE_SPECIFIER="$PROV_NAME" \
  archive

mkdir -p out
xcodebuild \
  -exportArchive \
  -archivePath build/WellnessWatch-Signed.xcarchive \
  -exportPath out \
  -exportOptionsPlist scripts/ExportOptions.plist

# 5. 清理 keychain
security delete-keychain /tmp/wb.keychain
echo "signed ipa: out/WellnessWatch.ipa"
