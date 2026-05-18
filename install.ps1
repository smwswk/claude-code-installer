# ╔═══════════════════════════════════════════════════════════╗
# ║  Claude Code 一键安装工具 — Windows PowerShell 版        ║
# ║  品牌：小明老师 AI 落地咨询                               ║
# ║  用法：.\install.ps1                                     ║
# ║        .\install.ps1 -DryRun -SkipConfirm               ║
# ╚═══════════════════════════════════════════════════════════╝

param(
    [switch]$DryRun,
    [switch]$SkipConfirm,
    [switch]$AddIndustry
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# ── 颜色 ──────────────────────────────────────────────────
function Write-Info  { Write-Host "[INFO]  $args" -ForegroundColor Cyan }
function Write-Ok    { Write-Host "[✓]    $args" -ForegroundColor Green }
function Write-Warn  { Write-Host "[⚠]    $args" -ForegroundColor Yellow }
function Write-Error2 { Write-Host "[✗]    $args" -ForegroundColor Red }
function Write-Step  { Write-Host ""; Write-Host "━━━ $args ━━━" -ForegroundColor Cyan; Write-Host "" }

# ── 品牌 ──────────────────────────────────────────────────
$Brand = "小明老师 AI 落地咨询"
$Version = "2.0.0"

# ── 欢迎界面 ──────────────────────────────────────────────
Clear-Host
Write-Host ""
Write-Host "  ██████╗██╗         █████╗ ██╗   ██╗" -ForegroundColor Cyan
Write-Host " ██╔════╝██║        ██╔══██╗██║   ██║" -ForegroundColor Cyan
Write-Host " ██║     ██║        ███████║██║   ██║" -ForegroundColor Cyan
Write-Host " ██║     ██║        ██╔══██║██║   ██║" -ForegroundColor Cyan
Write-Host " ╚██████╗███████╗   ██║  ██║╚██████╔╝" -ForegroundColor Cyan
Write-Host "  ╚═════╝╚══════╝   ╚═╝  ╚═╝ ╚═════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Claude Code AI编程助手 - 一键安装工具（Windows版）" -ForegroundColor White
Write-Host "  v$Version  |  $Brand" -ForegroundColor DarkGray
Write-Host ""

# ── 确认 ──────────────────────────────────────────────────
if (-not $SkipConfirm -and -not $AddIndustry) {
    $reply = Read-Host "开始安装？[Y/n]"
    if ($reply -ne "" -and $reply -ne "y" -and $reply -ne "Y") {
        Write-Info "已取消安装"
        exit 0
    }
}

# ── 0. 平台检测 ──────────────────────────────────────────
Write-Step "第0步：平台检测"

$OS = (Get-CimInstance Win32_OperatingSystem).Caption
$Arch = $env:PROCESSOR_ARCHITECTURE
Write-Ok "操作系统: $OS ($Arch)"

# 检测 WSL
$inWSL = $false
if ($env:WSL_DISTRO_NAME) {
    $inWSL = $true
    Write-Warn "检测到 WSL 环境，建议在 WSL 内运行 install.sh（Linux版）而非本脚本"
    $reply = Read-Host "继续使用 Windows 原生安装？[y/N]"
    if ($reply -ne "y" -and $reply -ne "Y") {
        Write-Info "请切换到 WSL 终端运行 bash install.sh"
        exit 0
    }
}

# 检测 git
$gitOk = $false
try {
    $gitVer = git --version 2>$null
    if ($gitVer -match "(\d+\.\d+\.\d+)") {
        Write-Ok "Git: $($matches[1])"
        $gitOk = $true
    }
} catch {
    Write-Warn "Git 未安装"
}

# 检测 winget
$wingetOk = Get-Command winget -ErrorAction SilentlyContinue
if ($wingetOk) {
    Write-Ok "WinGet: 可用"
} else {
    Write-Warn "WinGet 不可用，将使用官方安装器"
}

# ── 1. 安装 Claude Code ──────────────────────────────────
Write-Step "第1步：安装 Claude Code CLI"

$claudeInstalled = Get-Command claude -ErrorAction SilentlyContinue
if ($claudeInstalled) {
    Write-Ok "Claude Code 已安装"
    $reply = Read-Host "跳过安装？[Y/n]"
    if ($reply -eq "n" -or $reply -eq "N") {
        $claudeInstalled = $false
    }
}

if (-not $claudeInstalled) {
    Write-Info "选择安装方式："
    Write-Host "  [1] 官方安装器 (推荐)"
    if ($wingetOk) { Write-Host "  [2] WinGet" }
    Write-Host "  [0] 跳过"

    $choice = Read-Host "请选择 [1]"
    if ($choice -eq "" -or $choice -eq "1") {
        Write-Info "使用官方安装器..."
        if ($DryRun) {
            Write-Info "[DRY-RUN] irm https://claude.ai/install.ps1 | iex"
        } else {
            irm https://claude.ai/install.ps1 | iex
        }
    } elseif ($choice -eq "2" -and $wingetOk) {
        Write-Info "使用 WinGet..."
        if ($DryRun) {
            Write-Info "[DRY-RUN] winget install Anthropic.ClaudeCode"
        } else {
            winget install Anthropic.ClaudeCode
        }
    }

    # 检查 PATH
    $localBin = "$env:USERPROFILE\.local\bin"
    if (Test-Path $localBin) {
        $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
        if ($currentPath -notmatch [regex]::Escape($localBin)) {
            [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$localBin", "User")
            Write-Ok "已将 $localBin 添加到 PATH"
        }
    }

    Write-Ok "Claude Code 安装完成"
}

# ── 2. 行业选择（简化版，引导用户到 macOS/Linux 完整安装） ──
Write-Step "第2步：选择行业方案"

Write-Info "Windows 版安装器目前提供基础安装。"
Write-Info "推荐在 WSL2 中使用 Linux 版 install.sh 获得完整行业方案支持。"
Write-Host ""
Write-Host "  [1] 全部安装 (所有32个技能)"
Write-Host "  [2] 仅通用工具 (7个基础技能)"
Write-Host "  [3] 稍后在 WSL 中安装"

$choice = Read-Host "请选择 [1]"
$selectedIndustries = @()

switch ($choice) {
    "2" { $selectedIndustries = @() }
    "3" {
        Write-Info "跳过技能安装。请后续在 WSL 中运行 bash install.sh"
        Write-Ok "基础安装完成！"
        exit 0
    }
    default { $selectedIndustries = @("法律", "摄影", "内容", "AI") }
}

# ── 3. API 配置 ──────────────────────────────────────────
Write-Step "第3步：配置 API"

Write-Host "  [1] DeepSeek API (推荐，国内直连)"
Write-Host "  [2] Anthropic 官方 API"
Write-Host "  [3] 自定义"
Write-Host "  [4] 跳过"

$apiChoice = Read-Host "请选择 [1]"

$apiProvider = "skip"
$apiKey = ""
$apiModel = "deepseek-v4-pro"
$apiBaseUrl = ""

switch ($apiChoice) {
    "1" {
        $apiProvider = "deepseek"
        $apiKey = Read-Host "DeepSeek API Key" -AsSecureString
        $apiModel = Read-Host "模型名 [deepseek-v4-pro]"
        if (-not $apiModel) { $apiModel = "deepseek-v4-pro" }
    }
    "2" {
        $apiProvider = "anthropic"
        $apiKey = Read-Host "Anthropic API Key" -AsSecureString
        $apiModel = Read-Host "模型名 [claude-sonnet-4-6]"
        if (-not $apiModel) { $apiModel = "claude-sonnet-4-6" }
    }
    "3" {
        $apiProvider = "openai_compat"
        $apiBaseUrl = Read-Host "Base URL"
        $apiKey = Read-Host "API Key" -AsSecureString
        $apiModel = Read-Host "模型名"
    }
    default {
        Write-Info "跳过 API 配置"
    }
}

# ── 4. 复制技能 ──────────────────────────────────────────
Write-Step "第4步：安装技能"

$skillsDst = "$env:USERPROFILE\.claude\skills"
$commandsDst = "$env:USERPROFILE\.claude\commands"

if (-not $DryRun) {
    New-Item -ItemType Directory -Force -Path $skillsDst | Out-Null
    New-Item -ItemType Directory -Force -Path $commandsDst | Out-Null

    # 复制通用技能
    $genericSrc = Join-Path $ScriptDir "skills\通用"
    if (Test-Path $genericSrc) {
        Copy-Item -Path "$genericSrc\*" -Destination $skillsDst -Recurse -Force
        Write-Ok "通用技能已安装"
    }

    # 复制行业技能
    foreach ($ind in $selectedIndustries) {
        $indSrc = Join-Path $ScriptDir "skills\$ind"
        if (Test-Path $indSrc) {
            Copy-Item -Path "$indSrc\*" -Destination $skillsDst -Recurse -Force
            Write-Ok "$ind 行业技能已安装"
        }
    }

    # 复制命令
    $cmdSrc = Join-Path $ScriptDir "commands\法律"
    if (Test-Path $cmdSrc) {
        Copy-Item -Path "$cmdSrc\*" -Destination $commandsDst -Force
        Write-Ok "命令已安装"
    }
}

# ── 5. 生成配置 ──────────────────────────────────────────
Write-Step "第5步：生成配置"

if ($apiProvider -ne "skip" -and -not $DryRun) {
    $settingsDir = "$env:USERPROFILE\.claude"
    New-Item -ItemType Directory -Force -Path $settingsDir | Out-Null

    $settings = @{
        outputStyle = "default"
        theme = "auto"
        skipDangerousModePermissionPrompt = $true
        env = @{}
    }

    switch ($apiProvider) {
        "deepseek" {
            $settings.env = @{
                ANTHROPIC_BASE_URL = "https://api.deepseek.com/anthropic"
                ANTHROPIC_AUTH_TOKEN = $apiKey
                ANTHROPIC_MODEL = $apiModel
                ANTHROPIC_DEFAULT_HAIKU_MODEL = $apiModel
                ANTHROPIC_DEFAULT_SONNET_MODEL = $apiModel
                ANTHROPIC_DEFAULT_OPUS_MODEL = $apiModel
                DISABLE_AUTOUPDATER = "1"
            }
        }
        "anthropic" {
            $settings.env = @{
                ANTHROPIC_AUTH_TOKEN = $apiKey
                ANTHROPIC_MODEL = $apiModel
                DISABLE_AUTOUPDATER = "0"
            }
        }
        "openai_compat" {
            $settings.env = @{
                ANTHROPIC_BASE_URL = $apiBaseUrl
                ANTHROPIC_AUTH_TOKEN = $apiKey
                ANTHROPIC_MODEL = $apiModel
                DISABLE_AUTOUPDATER = "1"
            }
        }
    }

    $settingsJson = Join-Path $settingsDir "settings.json"
    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsJson -Encoding UTF8
    Write-Ok "settings.json 已生成"
} elseif ($DryRun) {
    Write-Info "[DRY-RUN] 跳过配置写入"
}

# ── 6. 完成 ──────────────────────────────────────────────
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host ""
Write-Host "  🎉 安装完成！" -ForegroundColor Green
Write-Host ""
Write-Host "  现在你可以："
Write-Host "    1. 打开 PowerShell，输入 claude 启动"
Write-Host ""
Write-Host "  如有问题，联系：$Brand"
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host ""
