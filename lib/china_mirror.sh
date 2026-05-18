#!/bin/bash
# china_mirror.sh — 中国大陆网络镜像加速
# 自动配置 pip / npm / brew 镜像源，加速依赖安装

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

MIRROR_CONFIGURED_PIP=false
MIRROR_CONFIGURED_NPM=false
MIRROR_CONFIGURED_BREW=false

configure_china_mirrors() {
    log_step "8" "9" "配置国内镜像加速"

    echo "检测到你在中国大陆，配置国内镜像源可以大幅加速后续工具安装。"
    echo ""

    # pip 镜像
    if command -v pip3 &>/dev/null || command -v pip &>/dev/null; then
        if confirm "配置 pip 清华镜像源？(推荐)"; then
            configure_pip_mirror
        fi
    fi

    # npm 镜像
    if command -v npm &>/dev/null; then
        if confirm "配置 npm 淘宝镜像源？"; then
            configure_npm_mirror
        fi
    fi

    # brew 镜像
    if $PLATFORM_HAS_BREW; then
        if confirm "配置 Homebrew 中科大镜像源？"; then
            configure_brew_mirror
        fi
    fi

    echo ""
    if $MIRROR_CONFIGURED_PIP || $MIRROR_CONFIGURED_NPM || $MIRROR_CONFIGURED_BREW; then
        log_ok "镜像加速配置完成"
    else
        log_info "跳过镜像配置"
    fi
    echo ""
}

configure_pip_mirror() {
    log_info "配置 pip 清华镜像源..."

    if $DRY_RUN; then
        log_info "[DRY-RUN] pip3 config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple"
        MIRROR_CONFIGURED_PIP=true
        return
    fi

    local pip_cmd="pip3"
    if ! command -v pip3 &>/dev/null; then
        pip_cmd="pip"
    fi

    # 清华源（校园网最快）或阿里源（非校园网更稳定）
    local mirror_url="https://pypi.tuna.tsinghua.edu.cn/simple"
    local fallback_url="https://mirrors.aliyun.com/pypi/simple/"

    if "$pip_cmd" config set global.index-url "$mirror_url" 2>/dev/null; then
        log_ok "pip 镜像: 清华源"
        MIRROR_CONFIGURED_PIP=true
    elif "$pip_cmd" config set global.index-url "$fallback_url" 2>/dev/null; then
        log_ok "pip 镜像: 阿里源"
        MIRROR_CONFIGURED_PIP=true
    else
        log_warn "pip 镜像配置失败，使用默认源"
    fi

    # 配置 trusted host（避免 SSL 警告）
    "$pip_cmd" config set global.trusted-host \
        "pypi.tuna.tsinghua.edu.cn mirrors.aliyun.com" 2>/dev/null || true
}

configure_npm_mirror() {
    log_info "配置 npm 淘宝镜像源..."

    if $DRY_RUN; then
        log_info "[DRY-RUN] npm config set registry https://registry.npmmirror.com"
        MIRROR_CONFIGURED_NPM=true
        return
    fi

    if npm config set registry https://registry.npmmirror.com 2>/dev/null; then
        log_ok "npm 镜像: 淘宝源 (npmmirror.com)"
        MIRROR_CONFIGURED_NPM=true
    else
        log_warn "npm 镜像配置失败"
    fi
}

configure_brew_mirror() {
    log_info "配置 Homebrew 中科大镜像源..."

    if $DRY_RUN; then
        log_info "[DRY-RUN] brew tap 中科大镜像"
        MIRROR_CONFIGURED_BREW=true
        return
    fi

    # Homebrew 核心仓库镜像
    local brew_core="https://mirrors.ustc.edu.cn/homebrew-core.git"
    local brew_cask="https://mirrors.ustc.edu.cn/homebrew-cask.git"
    local brew_bottles="https://mirrors.ustc.edu.cn/homebrew-bottles"

    # 设置 HOMEBREW_BOTTLE_DOMAIN
    if grep -q "HOMEBREW_BOTTLE_DOMAIN" "$HOME/.zshrc" 2>/dev/null; then
        log_info "brew 镜像已配置，跳过"
        MIRROR_CONFIGURED_BREW=true
        return
    fi

    {
        echo ""
        echo "# Homebrew 中科大镜像（由 Claude Code 安装器添加）"
        echo "export HOMEBREW_BOTTLE_DOMAIN=$brew_bottles"
    } >> "$HOME/.zshrc"

    # 也写到 .bashrc
    if [ -f "$HOME/.bashrc" ]; then
        {
            echo ""
            echo "# Homebrew 中科大镜像（由 Claude Code 安装器添加）"
            echo "export HOMEBREW_BOTTLE_DOMAIN=$brew_bottles"
        } >> "$HOME/.bashrc"
    fi

    export HOMEBREW_BOTTLE_DOMAIN="$brew_bottles"
    log_ok "brew 镜像: 中科大源"
    MIRROR_CONFIGURED_BREW=true

    # 如果用户想完整替换，提示命令
    log_info "如需完整替换 brew 仓库源，请手动执行："
    echo "  cd \$(brew --repo) && git remote set-url origin $brew_core"
    echo "  cd \$(brew --repo homebrew/cask) && git remote set-url origin $brew_cask"
}

install_python_if_needed() {
    # 部分技能需要 python3，国内环境下提示安装
    if ! command -v python3 &>/dev/null; then
        log_warn "部分技能需要 Python 3，当前未安装"
        if $PLATFORM_IS_CHINA && confirm "是否安装 Python 3（使用 brew）？"; then
            if $PLATFORM_HAS_BREW; then
                brew install python@3
            else
                log_info "请手动安装 Python 3: https://www.python.org/downloads/"
            fi
        fi
    fi
}
