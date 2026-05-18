#!/bin/bash
# ╔═══════════════════════════════════════════════════════════╗
# ║  Claude Code 一键安装工具                                 ║
# ║  品牌：小明老师 AI 落地咨询                               ║
# ║  版本：2.0.0                                             ║
# ║  用法：bash install.sh [--dry-run] [--skip-confirm]      ║
# ║        bash install.sh --add-industry  (追加行业方案)    ║
# ╚═══════════════════════════════════════════════════════════╝

set -euo pipefail

# ── 确定脚本所在目录 ──────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# ── 加载函数库 ────────────────────────────────────────────
source "$LIB_DIR/common.sh"
source "$LIB_DIR/platform_detect.sh"
source "$LIB_DIR/install_claude.sh"
source "$LIB_DIR/select_industry.sh"
source "$LIB_DIR/configure_api.sh"
source "$LIB_DIR/deploy_skills.sh"
source "$LIB_DIR/deploy_config.sh"
source "$LIB_DIR/install_plugins.sh"
source "$LIB_DIR/china_mirror.sh"
source "$LIB_DIR/verify.sh"

# ── 解析参数 ──────────────────────────────────────────────
ADD_INDUSTRY_MODE=false

for arg in "$@"; do
    case "$arg" in
        --dry-run)
            DRY_RUN=true
            log_info "试运行模式：不会实际修改文件"
            ;;
        --skip-confirm)
            SKIP_CONFIRM=true
            ;;
        --add-industry)
            ADD_INDUSTRY_MODE=true
            ;;
        --help|-h)
            echo "用法: bash install.sh [选项]"
            echo ""
            echo "选项："
            echo "  --dry-run         试运行，不修改文件"
            echo "  --skip-confirm    跳过所有确认（自动化部署）"
            echo "  --add-industry    追加行业方案（保留已有配置）"
            echo "  --help            显示此帮助"
            exit 0
            ;;
    esac
done

# ── 前置检查：不在 plan mode 下运行 ─────────────────────
# （claude 命令安装需要实际执行权限）

# ── 欢迎界面 ──────────────────────────────────────────────
clear 2>/dev/null || true
echo ""
echo -e "${CYAN}${BOLD}  ██████╗██╗         █████╗ ██╗   ██╗${NC}"
echo -e "${CYAN}${BOLD} ██╔════╝██║        ██╔══██╗██║   ██║${NC}"
echo -e "${CYAN}${BOLD} ██║     ██║        ███████║██║   ██║${NC}"
echo -e "${CYAN}${BOLD} ██║     ██║        ██╔══██║██║   ██║${NC}"
echo -e "${CYAN}${BOLD} ╚██████╗███████╗   ██║  ██║╚██████╔╝${NC}"
echo -e "${CYAN}${BOLD}  ╚═════╝╚══════╝   ╚═╝  ╚═╝ ╚═════╝${NC}"
echo ""
echo -e "  ${BOLD}Claude Code 智能编程助手 - 一键安装工具${NC}"
echo -e "  ${DIM}v${INSTALLER_VERSION}  |  ${INSTALLER_BRAND}${NC}"
echo ""
echo -e "${DIM}  本工具将帮助你完成：${NC}"
echo -e "${DIM}    1. 环境检测    2. 安装 Claude Code CLI${NC}"
echo -e "${DIM}    3. 选择行业方案  4. 配置 AI 接口${NC}"
echo -e "${DIM}    5. 安装技能包    6. 完成验证${NC}"
echo ""
echo ""

# ── 确认开始 ──────────────────────────────────────────────
if ! $ADD_INDUSTRY_MODE; then
    if ! confirm "开始安装？"; then
        log_info "已取消安装"
        exit 0
    fi
fi

# ── 执行安装步骤 ──────────────────────────────────────────

# 0. 平台检测
echo ""
run_platform_detect

if $ADD_INDUSTRY_MODE; then
    # 追加模式：只跑行业选择+技能部署+配置更新
    log_info "追加行业模式：保留已有配置，仅添加新技能"
    select_industry
    deploy_skills
    deploy_config
    verify_installation
    print_success_message
    exit 0
fi

# 检查必要工具
echo -e "${BOLD}环境检查：${NC}"
echo ""
if ! $PLATFORM_HAS_GIT; then
    log_warn "Git 未安装或版本过低（需要 >= 2.38）"
    if confirm "是否尝试安装 Git？"; then
        case "$PLATFORM_OS" in
            macos)
                if $PLATFORM_HAS_BREW; then
                    brew install git
                else
                    log_info "请安装 Homebrew 后重试：https://brew.sh"
                fi
                ;;
            linux)
                log_info "请使用系统包管理器安装：sudo apt install git / sudo yum install git"
                ;;
        esac
    fi
fi
echo ""

# 1. 安装 Claude Code CLI
log_step "1" "9" "安装 Claude Code CLI"
install_claude_cli "auto"
echo ""

# 2. 选择行业方案
select_industry
echo ""

# 3. 配置 API
configure_api
echo ""

# 4. 部署技能
deploy_skills
echo ""

# 5. 安装 Superpowers 插件
install_plugins
echo ""

# 6. 部署配置
deploy_config
echo ""

# 7. 额外的系统依赖提示
echo -e "${BOLD}额外依赖检查：${NC}"
echo ""
missing_tools=()
for tool in python3 ffmpeg tesseract hugo; do
    if ! command -v "$tool" &>/dev/null; then
        missing_tools+=("$tool")
    fi
done
if [ ${#missing_tools[@]} -gt 0 ]; then
    log_warn "以下工具未安装（部分技能可能需要）：${missing_tools[*]}"
    log_info "可稍后通过 Homebrew 安装：brew install ${missing_tools[*]}"
else
    log_ok "所有常用工具已安装"
fi
echo ""

# 8. 国内镜像加速（仅中国大陆用户）
if $PLATFORM_IS_CHINA; then
    configure_china_mirrors
    install_python_if_needed
fi

# 9. 验证
verify_installation

# 10. 成功消息
print_success_message
