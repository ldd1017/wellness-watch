# scripts/一键推送.ps1
# 双击运行（右键 → 用 PowerShell 运行）→ 引导输入 GitHub 仓库信息 → push
# 全程只需要输入：
#   1. GitHub 用户名
#   2. 仓库名（默认 wellness-watch）
#   3. Personal Access Token (PAT)
#
# 提前准备：
#   - 在 https://github.com/new 创建一个空仓库（不要勾 README）
#   - 在 https://github.com/settings/tokens 生成 PAT，勾选 repo 权限

# 检查以管理员身份运行时改变策略
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $IsWindows = $true
}

Set-Location (Join-Path $PSScriptRoot "..")

# 检测 git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "❌ git 未安装" -ForegroundColor Red
    Write-Host "下载 Git for Windows: https://git-scm.com/download/win"
    Write-Host "装完重开 PowerShell 再跑这个脚本"
    pause
    exit 1
}

# 检测 .git
if (-not (Test-Path ".git")) {
    Write-Host "→ git init"
    git init
}

# 配置用户（如果未配置）
$currentName  = git config user.name  2>$null
$currentEmail = git config user.email 2>$null
if (-not $currentName)  { git config user.name  "WellnessWatch User" }
if (-not $currentEmail) { git config user.email "user@example.com" }

# 输入仓库信息
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  WellnessWatch 一键推送" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "提前准备：" -ForegroundColor Yellow
Write-Host "  1. 已在 https://github.com/new 创建空仓库"
Write-Host "  2. 已在 https://github.com/settings/tokens 生成 PAT (勾 repo)"
Write-Host ""

$username = Read-Host "GitHub 用户名 [回车用 ldd1017]"
if (-not $username) { $username = "ldd1017" }

$repo = Read-Host "仓库名 [回车用 wellness-watch]"
if (-not $repo) { $repo = "wellness-watch" }

$token = Read-Host "Personal Access Token (输入时不显示)" -AsSecureString
if (-not $token) { Write-Host "❌ Token 不能为空"; pause; exit 1 }
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($token)
$tokenPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

# 拼接 remote URL
$remoteUrl = "https://$($username):$($tokenPlain)@github.com/$($username)/$($repo).git"

# 检查是否已 commit
$hasCommits = git rev-parse --verify HEAD 2>$null
if (-not $hasCommits) {
    Write-Host "→ git add ."
    git add .
    Write-Host "→ git commit"
    git commit -m "feat: initial watchOS health app"
}

# 配置 remote
$currentRemote = git remote get-url origin 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "→ git remote add origin"
    git remote add origin $remoteUrl
} else {
    Write-Host "→ 替换 remote origin"
    git remote set-url origin $remoteUrl
}

# 切到 main
git branch -M main

# 推送
Write-Host ""
Write-Host "→ git push -u origin main ..." -ForegroundColor Yellow
Write-Host ""

git push -u origin main

$pushOk = $LASTEXITCODE -eq 0

# 清理 token（从 URL 剥离 + 清内存）
git remote set-url origin "https://github.com/$($username)/$($repo).git"
$tokenPlain = $null
[System.GC]::Collect()

Write-Host ""
if ($pushOk) {
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  ✅ 推送成功！" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "下一步：" -ForegroundColor Yellow
    Write-Host "  1. 打开 https://github.com/$username/$repo/actions"
    Write-Host "  2. 等 'Build watchOS App' 跑完（3-5 分钟）"
    Write-Host "  3. 下载 WellnessWatch-unsigned artifact"
    Write-Host "  4. 参考 docs/STEP-BY-STEP-FIRST-DEPLOY.md 第 [3]-[7] 步"
    Write-Host ""
    $open = Read-Host "是否现在打开 GitHub Actions 页面？(y/n)"
    if ($open -eq "y") {
        Start-Process "https://github.com/$username/$repo/actions"
    }
} else {
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "  ❌ 推送失败" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "常见原因："
    Write-Host "  1. PAT 没勾 'repo' 权限（去 https://github.com/settings/tokens 改）"
    Write-Host "  2. 仓库没创建（去 https://github.com/new）"
    Write-Host "  3. 用户名/仓库名拼错"
    Write-Host "  4. 网络不通 GitHub"
    Write-Host ""
}

pause
