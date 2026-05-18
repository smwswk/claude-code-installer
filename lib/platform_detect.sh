#!/bin/bash
# platform_detect.sh — 完整平台检测 + 环境诊断
# source 后通过 PLATFORM_* 变量获取检测结果

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# ── 平台变量 ──────────────────────────────────────────────
PLATFORM_OS=""
PLATFORM_ARCH=""
PLATFORM_SHELL=""
PLATFORM_IS_WSL=false
PLATFORM_IS_CHINA=false
PLATFORM_HAS_GIT=false
PLATFORM_HAS_CURL=false
PLATFORM_HAS_BREW=false
PLATFORM_HAS_WINGET=false
PLATFORM_HAS_NODE=false
PLATFORM_GIT_VERSION=""
PLATFORM_CLAUDE_INSTALLED=false
PLATFORM_CLAUDE_VERSION=""

run_platform_detect() {
    log_header "🔍 正在检测系统环境..."

    PLATFORM_OS=$(detect_os)
    PLATFORM_ARCH=$(detect_arch)
    PLATFORM_SHELL=$(detect_shell)

    case "$PLATFORM_OS" in
        macos)
            log_ok "操作系统: macOS ($PLATFORM_ARCH)"
            PLATFORM_HAS_BREW=$(command -v brew &>/dev/null && echo true || echo false)
            ;;
        linux)
            if is_wsl; then
                PLATFORM_IS_WSL=true
                log_ok "操作系统: Linux (WSL2, $PLATFORM_ARCH)"
            else
                log_ok "操作系统: Linux ($PLATFORM_ARCH)"
            fi
            PLATFORM_HAS_BREW=$(command -v brew &>/dev/null && echo true || echo false)
            ;;
        windows)
            log_ok "操作系统: Windows ($PLATFORM_ARCH)"
            PLATFORM_HAS_WINGET=$(command -v winget &>/dev/null && echo true || echo false)
            ;;
        *)
            log_error "不支持的操作系统: $PLATFORM_OS"
            echo "Claude Code 支持 macOS 10.15+, Ubuntu 20.04+, Windows 10/11"
            exit 1
            ;;
    esac

    # 检测 shell
    log_ok "Shell: $PLATFORM_SHELL"

    # 检测 git
    if command -v git &>/dev/null; then
        PLATFORM_HAS_GIT=true
        PLATFORM_GIT_VERSION=$(git --version | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
        if version_ge "$PLATFORM_GIT_VERSION" "2.38"; then
            log_ok "Git: $PLATFORM_GIT_VERSION"
        else
            log_warn "Git 版本 $PLATFORM_GIT_VERSION < 2.38，建议升级"
            PLATFORM_HAS_GIT=false
        fi
    else
        log_warn "Git 未安装"
    fi

    # 检测 curl
    if command -v curl &>/dev/null; then
        PLATFORM_HAS_CURL=true
        log_ok "curl: 已安装"
    else
        log_warn "curl 未安装"
    fi

    # 检测 Node.js（非必须）
    if command -v node &>/dev/null; then
        PLATFORM_HAS_NODE=true
    fi

    # 检测 Claude Code 是否已安装
    if command -v claude &>/dev/null; then
        PLATFORM_CLAUDE_INSTALLED=true
        PLATFORM_CLAUDE_VERSION=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        log_ok "Claude Code 已安装: v$PLATFORM_CLAUDE_VERSION"
    else
        log_info "Claude Code 未安装"
    fi

    # 网络检测
    if curl -s --connect-timeout 5 -o /dev/null https://claude.ai 2>/dev/null; then
        log_ok "网络连接正常"
    else
        log_warn "无法连接到 claude.ai，请检查网络"
    fi

    # 检测是否在中国大陆网络
    if is_china_network; then
        PLATFORM_IS_CHINA=true
        log_info "检测到中国大陆网络环境"
    fi

    echo ""
    log_info "平台检测完成"
    echo ""

    # 导出平台摘要
    export PLATFORM_OS PLATFORM_ARCH PLATFORM_SHELL
    export PLATFORM_IS_WSL PLATFORM_IS_CHINA
    export PLATFORM_HAS_GIT PLATFORM_HAS_CURL PLATFORM_HAS_BREW
    export PLATFORM_HAS_WINGET PLATFORM_HAS_NODE
    export PLATFORM_GIT_VERSION
    export PLATFORM_CLAUDE_INSTALLED PLATFORM_CLAUDE_VERSION
}
