#!/bin/bash
# common.sh — 共享函数库：颜色、日志、spinner、OS检测
# 被 install.sh 和其他 lib 模块 source

set -euo pipefail

# ── 颜色定义 ──────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# ── 全局状态 ──────────────────────────────────────────────
INSTALLER_VERSION="2.0.0"
INSTALLER_BRAND="小明老师 AI 落地咨询"
DRY_RUN=false
SELECTED_INDUSTRIES=()
SKIP_CONFIRM=false
BACKUP_DIR=""

# ── 日志函数 ──────────────────────────────────────────────

log_info() {
    echo -e "${BLUE}[INFO]${NC}  $*"
}

log_ok() {
    echo -e "${GREEN}[✓]${NC}   $*"
}

log_warn() {
    echo -e "${YELLOW}[⚠]${NC}   $*"
}

log_error() {
    echo -e "${RED}[✗]${NC}   $*"
}

log_step() {
    local step="$1" total="$2" title="$3"
    echo ""
    echo -e "${BOLD}${CYAN}━━━ 第${step}步/${total}步：${title} ━━━${NC}"
    echo ""
}

log_header() {
    echo -e "${CYAN}${BOLD}$*${NC}"
}

# ── 用户交互 ──────────────────────────────────────────────

confirm() {
    local prompt="${1:-确认？}"
    if $SKIP_CONFIRM; then
        return 0
    fi
    local answer
    read -r -p "$(echo -e "${YELLOW}${prompt} [Y/n]：${NC} ")" answer
    case "${answer:-y}" in
        [Yy]|[Yy][Ee][Ss]|"") return 0 ;;
        *) return 1 ;;
    esac
}

ask() {
    local prompt="$1" default="$2"
    local answer
    read -r -p "$(echo -e "${CYAN}${prompt}${NC} [${default}]：")" answer
    echo "${answer:-$default}"
}

ask_secret() {
    local prompt="$1"
    local answer
    read -r -s -p "$(echo -e "${CYAN}${prompt}${NC}：")" answer
    echo "${answer}"
}

# ── Spinner（长时间任务） ─────────────────────────────────

spinner() {
    local pid=$1
    local message="${2:-处理中}"
    local delay=0.1
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    while kill -0 "$pid" 2>/dev/null; do
        for frame in "${frames[@]}"; do
            printf "\r  ${CYAN}%s${NC} %s" "$frame" "$message"
            sleep "$delay"
        done
    done
    printf "\r"
}

# ── 平台检测 ──────────────────────────────────────────────

detect_os() {
    case "$(uname -s)" in
        Darwin)  echo "macos" ;;
        Linux)   echo "linux" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *)       echo "unknown" ;;
    esac
}

detect_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        arm64|aarch64) echo "arm64" ;;
        x86_64|amd64)  echo "x86_64" ;;
        *)             echo "$arch" ;;
    esac
}

detect_shell() {
    basename "${SHELL:-$(ps -p $$ -o comm=)}"
}

is_wsl() {
    grep -qi microsoft /proc/version 2>/dev/null && return 0 || return 1
}

is_china_network() {
    # 轻量检测：用超时短连接测 DeepSeek 可达性
    if curl -s --connect-timeout 3 --max-time 5 -o /dev/null -w "%{http_code}" \
        https://api.deepseek.com/v1/models 2>/dev/null | grep -q '200\|401\|403'; then
        return 0
    fi
    return 1
}

# ── 版本比较 ──────────────────────────────────────────────

version_ge() {
    # 返回0如果 $1 >= $2
    printf '%s\n%s\n' "$2" "$1" | sort -V -C 2>/dev/null
}

# ── 文件操作 ──────────────────────────────────────────────

backup_existing() {
    local target="$1"
    if [ -e "$target" ]; then
        BACKUP_DIR="${BACKUP_DIR:-$HOME/.claude/backups/$(date +%Y-%m-%d-%H%M%S)}"
        mkdir -p "$BACKUP_DIR"
        local basename
        basename=$(basename "$target")
        cp -R "$target" "$BACKUP_DIR/$basename"
        log_warn "已备份到 $BACKUP_DIR/$basename"
    fi
}

safe_copy() {
    local src="$1" dst="$2"
    if $DRY_RUN; then
        log_info "[DRY-RUN] cp $src → $dst"
        return 0
    fi
    mkdir -p "$(dirname "$dst")"
    cp -R "$src" "$dst"
}

safe_write() {
    local content="$1" dst="$2"
    if $DRY_RUN; then
        log_info "[DRY-RUN] write → $dst"
        return 0
    fi
    mkdir -p "$(dirname "$dst")"
    echo "$content" > "$dst"
}

# ── 进度条 ────────────────────────────────────────────────

progress_bar() {
    local current="$1" total="$2" label="$3"
    local width=30
    local filled=$(( current * width / total ))
    local empty=$(( width - filled ))
    printf "\r  [%s%s] %s/%s %s" \
        "$(printf '#%.0s' $(seq 1 $filled))" \
        "$(printf '.%.0s' $(seq 1 $empty))" \
        "$current" "$total" "$label"
    if [ "$current" -eq "$total" ]; then
        echo ""
    fi
}

# ── 必要工具检查 ──────────────────────────────────────────

require_tool() {
    local tool="$1" min_version="${2:-}"
    if ! command -v "$tool" &>/dev/null; then
        log_warn "$tool 未安装"
        return 1
    fi
    if [ -n "$min_version" ]; then
        local installed
        installed=$("$tool" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
        if [ -n "$installed" ] && ! version_ge "$installed" "$min_version"; then
            log_warn "$tool 版本 $installed < 需要 $min_version"
            return 1
        fi
    fi
    log_ok "$tool $installed"
    return 0
}
