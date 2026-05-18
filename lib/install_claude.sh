#!/bin/bash
# install_claude.sh — 安装 Claude Code CLI
# 支持：官方原生安装器 / Homebrew / WinGet / 跳过

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

install_claude_cli() {
    local install_method="${1:-auto}"

    # 如果已安装，询问是否跳过
    if $PLATFORM_CLAUDE_INSTALLED; then
        log_info "Claude Code v$PLATFORM_CLAUDE_VERSION 已安装"
        if confirm "跳过安装步骤？"; then
            return 0
        fi
    fi

    if [ "$install_method" = "auto" ]; then
        install_method=$(choose_install_method)
    fi

    case "$install_method" in
        native)
            install_via_native
            ;;
        brew)
            install_via_brew
            ;;
        winget)
            install_via_winget
            ;;
        skip)
            log_info "已跳过 Claude Code 安装"
            return 0
            ;;
        *)
            log_error "未知安装方法: $install_method"
            return 1
            ;;
    esac

    # 验证安装
    if command -v claude &>/dev/null; then
        local version
        version=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        log_ok "Claude Code v$version 安装成功"
    else
        log_error "Claude Code 安装后仍无法找到 claude 命令"
        log_info "请手动运行: curl -fsSL https://claude.ai/install.sh | bash"
        log_info "然后重新运行本安装器"
        return 1
    fi
}

choose_install_method() {
    echo ""
    log_header "请选择 Claude Code 安装方式："
    echo ""
    echo "  [1] 官方原生安装器 (推荐，零依赖，自动更新)"
    if $PLATFORM_HAS_BREW; then
        echo "  [2] Homebrew (brew install --cask claude-code)"
    fi
    if [ "$PLATFORM_OS" = "windows" ] && $PLATFORM_HAS_WINGET; then
        echo "  [3] WinGet (winget install Anthropic.ClaudeCode)"
    fi
    echo "  [0] 跳过安装（已手动安装）"
    echo ""

    local choice
    choice=$(ask "请选择" "1")

    case "$choice" in
        1) echo "native" ;;
        2)
            if $PLATFORM_HAS_BREW; then echo "brew"; else echo "native"; fi
            ;;
        3)
            if [ "$PLATFORM_OS" = "windows" ] && $PLATFORM_HAS_WINGET; then echo "winget"; else echo "native"; fi
            ;;
        0) echo "skip" ;;
        *) echo "native" ;;
    esac
}

install_via_native() {
    log_info "使用官方原生安装器..."
    echo ""

    if $DRY_RUN; then
        log_info "[DRY-RUN] curl -fsSL https://claude.ai/install.sh | bash"
        return 0
    fi

    if ! $PLATFORM_HAS_CURL; then
        log_error "需要 curl，请先安装 curl 后重试"
        exit 1
    fi

    # 下载并运行官方安装脚本
    if curl -fsSL https://claude.ai/install.sh | bash; then
        log_ok "官方安装器执行完成"
    else
        log_error "官方安装器执行失败"
        log_info "请检查网络连接，或尝试手动安装："
        log_info "  curl -fsSL https://claude.ai/install.sh | bash"
        return 1
    fi

    # 确保 PATH 包含 ~/.local/bin（官方安装器默认位置）
    local local_bin="$HOME/.local/bin"
    if [ -d "$local_bin" ]; then
        case "$PLATFORM_SHELL" in
            zsh)
                if ! grep -q "$local_bin" "$HOME/.zshrc" 2>/dev/null; then
                    echo "export PATH=\"$local_bin:\$PATH\"" >> "$HOME/.zshrc"
                    log_info "已将 $local_bin 添加到 ~/.zshrc"
                fi
                ;;
            bash)
                if ! grep -q "$local_bin" "$HOME/.bashrc" 2>/dev/null; then
                    echo "export PATH=\"$local_bin:\$PATH\"" >> "$HOME/.bashrc"
                    log_info "已将 $local_bin 添加到 ~/.bashrc"
                fi
                ;;
        esac
    fi
}

install_via_brew() {
    log_info "使用 Homebrew 安装..."

    if $DRY_RUN; then
        log_info "[DRY-RUN] brew install --cask claude-code"
        return 0
    fi

    if ! brew install --cask claude-code; then
        log_error "Homebrew 安装失败"
        log_info "回退到官方安装器..."
        install_via_native
        return $?
    fi
    log_ok "Homebrew 安装完成"
}

install_via_winget() {
    log_info "使用 WinGet 安装..."

    if $DRY_RUN; then
        log_info "[DRY-RUN] winget install Anthropic.ClaudeCode"
        return 0
    fi

    if ! winget install Anthropic.ClaudeCode; then
        log_error "WinGet 安装失败，请手动安装"
        return 1
    fi

    # Windows 常见问题：PATH 可能未包含
    local local_bin="$USERPROFILE/.local/bin"
    if [ ! -d "$local_bin" ] && [ -n "${USERPROFILE:-}" ]; then
        local_bin="$USERPROFILE\\.local\\bin"
    fi
    log_warn "如果 claude 命令不可用，请将 %USERPROFILE%\\.local\\bin 添加到 PATH"
    log_ok "WinGet 安装完成"
}
