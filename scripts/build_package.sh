#!/bin/bash
# build_package.sh — 构建可分发的安装包
# 从 ~/.claude/ 同步最新技能 → 脱敏 → 打包为 zip
#
# 用法：
#   bash scripts/build_package.sh          # 构建并打包
#   bash scripts/build_package.sh --sync   # 仅同步技能（不打包）
#   bash scripts/build_package.sh --zip    # 仅打包（不同步）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PACKAGE_DIR/build"
DIST_NAME="claude-code-installer-$(date +%Y%m%d)"
DIST_DIR="$BUILD_DIR/$DIST_NAME"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_ok() { echo -e "${GREEN}[✓]${NC} $*"; }
log_info() { echo -e "${CYAN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[⚠]${NC} $*"; }
log_error() { echo -e "${RED}[✗]${NC} $*"; }

sync_skills() {
    log_info "正在从 ~/.claude/skills/ 同步技能..."
    python3 "$SCRIPT_DIR/sync_skills.py"
    log_ok "技能同步完成"
}

build_dist() {
    log_info "正在构建分发目录..."

    # 清理并创建 build 目录
    rm -rf "$DIST_DIR"
    mkdir -p "$DIST_DIR"

    # 复制核心文件
    log_info "复制安装脚本..."
    cp "$PACKAGE_DIR/install.sh" "$DIST_DIR/"
    cp "$PACKAGE_DIR/install.ps1" "$DIST_DIR/"
    chmod +x "$DIST_DIR/install.sh"

    # 复制 lib/
    log_info "复制函数库..."
    mkdir -p "$DIST_DIR/lib"
    cp "$PACKAGE_DIR/lib/"*.sh "$DIST_DIR/lib/"
    chmod +x "$DIST_DIR/lib/"*.sh

    # 复制 skills/（已同步的技能包）
    log_info "复制技能包..."
    mkdir -p "$DIST_DIR/skills"
    cp -R "$PACKAGE_DIR/skills/"* "$DIST_DIR/skills/"

    # 复制 commands/
    log_info "复制命令包..."
    mkdir -p "$DIST_DIR/commands"
    cp -R "$PACKAGE_DIR/commands/"* "$DIST_DIR/commands/"

    # 复制 templates/
    log_info "复制配置模板..."
    mkdir -p "$DIST_DIR/templates"
    cp "$PACKAGE_DIR/templates/"*.json "$DIST_DIR/templates/"
    cp "$PACKAGE_DIR/templates/"*.md "$DIST_DIR/templates/"

    # 复制 assets/
    if [ -d "$PACKAGE_DIR/assets" ] && [ "$(ls -A "$PACKAGE_DIR/assets" 2>/dev/null)" ]; then
        cp -R "$PACKAGE_DIR/assets/"* "$DIST_DIR/assets/"
    fi

    # 清理编辑器临时文件
    find "$DIST_DIR" -name ".DS_Store" -delete
    find "$DIST_DIR" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

    log_ok "分发目录构建完成"
}

package_zip() {
    log_info "正在打包为 zip..."

    cd "$BUILD_DIR"
    rm -f "${DIST_NAME}.zip"
    zip -r "${DIST_NAME}.zip" "$DIST_NAME" -x "*.DS_Store" -x "*__pycache__*"

    local zip_path="$BUILD_DIR/${DIST_NAME}.zip"
    local zip_size
    zip_size=$(du -h "$zip_path" | cut -f1)

    log_ok "打包完成：$zip_path ($zip_size)"
    echo ""

    # 打开 Finder 揭示
    if command -v open &>/dev/null; then
        open -R "$zip_path"
    fi
}

# ── 主流程 ──────────────────────────────────────────────

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  安装包构建工具${NC}"
echo -e "${CYAN}  品牌：小明老师 AI 落地咨询${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

case "${1:-}" in
    --sync)
        sync_skills
        ;;
    --zip)
        build_dist
        package_zip
        ;;
    *)
        # 完整流程：同步 → 构建 → 打包
        sync_skills
        echo ""
        build_dist
        echo ""
        package_zip
        ;;
esac

echo ""
log_ok "构建流程完成！"
