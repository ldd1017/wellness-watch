#!/usr/bin/env bash
# scripts/push-to-github.sh
# macOS / Linux 一键推送脚本
#
# 用法：
#   1. 准备 GitHub PAT
#   2. 编辑下方 REPO_URL / GITHUB_USER / GITHUB_EMAIL
#   3. bash scripts/push-to-github.sh

# === 配置区 ===
REPO_URL="https://github.com/ldd1017/wellness-watch.git"
GITHUB_USER="ldd1017"
GITHUB_EMAIL="1204639956@qq.com"
BRANCH="main"
# ==============

set -euo pipefail
cd "$(dirname "$0")/.."

echo "→ 当前目录: $(pwd)"

if ! command -v git &>/dev/null; then
  echo "❌ git 未安装。brew install git 或 apt install git"
  exit 1
fi

# init
if [ ! -d .git ]; then
  echo "→ git init"
  git init -q
  git config user.name  "$GITHUB_USER"
  git config user.email "$GITHUB_EMAIL"
  git branch -M "$BRANCH"
fi

echo "→ git add ."
git add .

if [ -n "$(git status --porcelain)" ]; then
  echo "→ git commit"
  git commit -m "feat: initial watchOS health app"
else
  echo "→ 没有改动，跳过 commit"
fi

if git remote get-url origin &>/dev/null; then
  if [ "$(git remote get-url origin)" != "$REPO_URL" ]; then
    echo "→ 改 origin 到 $REPO_URL"
    git remote set-url origin "$REPO_URL"
  fi
else
  echo "→ git remote add origin"
  git remote add origin "$REPO_URL"
fi

echo ""
echo "→ git push -u origin $BRANCH"
echo "  提示：Username = GitHub 用户名，Password = Personal Access Token"
echo ""

git push -u origin "$BRANCH"

echo ""
echo "============================================="
echo "  ✅ push 成功！"
echo "============================================="
echo ""
echo "下一步："
echo "  1. 打开 https://github.com/<你的用户名>/wellness-watch/actions"
echo "  2. 等待 'Build watchOS App' 跑完（3-5 分钟）"
echo "  3. 下载 WellnessWatch-unsigned artifact"
echo "  4. 参考 docs/STEP-BY-STEP-FIRST-DEPLOY.md"
echo ""
