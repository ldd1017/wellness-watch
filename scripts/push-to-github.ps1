# scripts/push-to-github.ps1
# Windows PowerShell 一键推送脚本
#
# 用法：
#   1. 准备 GitHub PAT (Settings → Developer settings → Personal access tokens)
#   2. 准备好 GitHub 仓库 URL
#   3. 编辑下方 $REPO_URL 和 $GITHUB_USER / $GITHUB_EMAIL
#   4. powershell -ExecutionPolicy Bypass -File scripts/push-to-github.ps1
#
# 也可双击运行（需要在 PowerShell 中"右键 → 用 PowerShell 运行"）

# === 配置区 ===
$REPO_URL    = "https://github.com/ldd1017/wellness-watch.git"
$GITHUB_USER = "ldd1017"
$GITHUB_EMAIL = "1204639956@qq.com"
$BRANCH      = "main"
# ==============

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

Write-Host "→ 当前目录: $(Get-Location)" -ForegroundColor Cyan

# 检查 git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Host "❌ git 未安装。装 Git for Windows: https://git-scm.com/download/win" -ForegroundColor Red
  exit 1
}

# 1. init
if (-not (Test-Path ".git")) {
  Write-Host "→ git init"
  git init | Out-Null
  git config user.name  $GITHUB_USER
  git config user.email $GITHUB_EMAIL
  git branch -M $BRANCH
} else {
  Write-Host "→ .git 已存在，跳过 init"
}

# 2. add + commit
Write-Host "→ git add ."
git add .

$hasChanges = git status --porcelain
if ($hasChanges) {
  Write-Host "→ git commit"
  git commit -m "feat: initial watchOS health app"
} else {
  Write-Host "→ 没有新改动，跳过 commit"
}

# 3. 配 remote
$existingRemote = git remote get-url origin 2>$null
if ($LASTEXITCODE -eq 0) {
  if ($existingRemote -ne $REPO_URL) {
    Write-Host "→ remote origin 已存在但 URL 不同，改成新 URL"
    git remote set-url origin $REPO_URL
  } else {
    Write-Host "→ remote origin 已配置正确"
  }
} else {
  Write-Host "→ git remote add origin"
  git remote add origin $REPO_URL
}

# 4. push
Write-Host ""
Write-Host "→ git push origin $BRANCH" -ForegroundColor Yellow
Write-Host "  提示：Username = GitHub 用户名，Password = Personal Access Token (PAT)" -ForegroundColor Yellow
Write-Host ""

git push -u origin $BRANCH
if ($LASTEXITCODE -ne 0) {
  Write-Host ""
  Write-Host "❌ push 失败。常见原因：" -ForegroundColor Red
  Write-Host "  1. PAT 没勾选 'repo' 权限"
  Write-Host "  2. 仓库 URL 错（用户名不对）"
  Write-Host "  3. 网络问题（GitHub 国内不稳）"
  exit 1
}

Write-Host ""
Write-Host "============================================="
Write-Host "  ✅ push 成功！" -ForegroundColor Green
Write-Host "============================================="
Write-Host ""
Write-Host "下一步："
Write-Host "  1. 打开 https://github.com/$($REPO_URL.Split('/')[-2])/wellness-watch/actions"
Write-Host "  2. 等待 'Build watchOS App' 跑完（3-5 分钟）"
Write-Host "  3. 下载 WellnessWatch-unsigned artifact"
Write-Host "  4. 参考 docs/STEP-BY-STEP-FIRST-DEPLOY.md 第 [3]-[7] 步"
Write-Host ""
