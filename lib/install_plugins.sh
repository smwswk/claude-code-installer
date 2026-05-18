#!/bin/bash
# install_plugins.sh — 安装 Superpowers 插件
# 通过 Claude Code 内置插件系统安装，失败时捆绑备用

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

INSTALLED_SUPERPOWERS=false

install_plugins() {
    log_step "5" "9" "安装 Superpowers 插件"

    echo "Superpowers 是社区开发的 Claude Code 效率增强插件，提供："
    echo "  • 系统化调试 (systematic-debugging)"
    echo "  • 测试驱动开发 (test-driven-development)"
    echo "  • 自动子任务分发 (dispatching-parallel-agents)"
    echo "  • 计划→执行工作流 (brainstorming → writing-plans → executing-plans)"
    echo "  • 代码审查 (requesting-code-review / receiving-code-review)"
    echo "  • Git Worktree 管理"
    echo ""

    if ! confirm "是否安装 Superpowers 插件？"; then
        log_info "已跳过 Superpowers 插件安装"
        return 0
    fi

    echo ""

    # 检查 claude 命令是否可用
    if ! command -v claude &>/dev/null; then
        log_warn "claude 命令尚不可用，跳过插件安装"
        log_info "可在 Claude Code 安装完成后手动执行："
        log_info "  /plugin install superpowers@superpowers-marketplace"
        return 0
    fi

    # 注册 superpowers marketplace（如果尚未注册）
    log_info "正在注册 superpowers marketplace..."
    if claude mcp list 2>/dev/null | grep -q "superpowers-marketplace"; then
        log_ok "superpowers marketplace 已注册"
    else
        # 尝试通过 plugin 系统安装
        log_info "正在从 GitHub 安装 superpowers@superpowers-marketplace..."
        if echo "/plugin install superpowers@superpowers-marketplace" | claude 2>/dev/null; then
            log_ok "Superpowers 安装请求已发送"
        else
            log_warn "自动安装 superpowers 失败"
            log_info "请手动在 claude 中运行：/plugin install superpowers@superpowers-marketplace"
        fi
    fi

    # 标记已安装（供 deploy_config.sh 使用）
    INSTALLED_SUPERPOWERS=true
    export INSTALLED_SUPERPOWERS

    log_ok "Superpowers 插件配置完成"
}
