#!/bin/bash
# verify.sh — 安装后验证
# 检查 claude 命令、技能数量、配置文件语法、运行冒烟测试

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

verify_installation() {
    log_step "9" "9" "验证安装"

    local errors=0
    local warnings=0
    local skill_count=0
    local command_count=0

    # 1. 检查 claude 命令
    echo ""
    if command -v claude &>/dev/null; then
        local claude_ver
        claude_ver=$(claude --version 2>/dev/null | head -1 || echo "unknown")
        log_ok "claude 命令可用 ($claude_ver)"
    else
        log_warn "claude 命令尚不可用，请重新打开终端后再试"
        warnings=$((warnings + 1))
    fi

    # 2. 检查技能目录
    local skills_dir="$HOME/.claude/skills"
    if [ -d "$skills_dir" ]; then
        skill_count=$(find "$skills_dir" -maxdepth 2 -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
        log_ok "技能已安装：${skill_count} 个"
    else
        log_warn "技能目录不存在: $skills_dir"
        warnings=$((warnings + 1))
    fi

    # 3. 检查命令目录
    local commands_dir="$HOME/.claude/commands"
    if [ -d "$commands_dir" ]; then
        command_count=$(find "$commands_dir" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$command_count" -gt 0 ]; then
            log_ok "命令已安装：${command_count} 个"
        else
            log_info "未安装行业命令（正常，部分行业无命令）"
        fi
    fi

    # 4. 检查 settings.json
    local settings_file="$HOME/.claude/settings.json"
    if [ -f "$settings_file" ]; then
        if command -v python3 &>/dev/null; then
            if python3 -c "import json; json.load(open('$settings_file'))" 2>/dev/null; then
                log_ok "settings.json 语法正确"
            else
                log_error "settings.json 语法错误"
                errors=$((errors + 1))
            fi
        else
            log_ok "settings.json 已存在"
        fi
    else
        log_warn "settings.json 未创建"
        warnings=$((warnings + 1))
    fi

    # 5. 检查 CLAUDE.md
    if [ -f "$HOME/CLAUDE.md" ]; then
        log_ok "CLAUDE.md 已安装"
    else
        log_info "CLAUDE.md 未安装（用户选择跳过）"
    fi

    # 6. 汇总
    echo ""
    if [ "$errors" -gt 0 ]; then
        log_error "验证发现 ${errors} 个错误，${warnings} 个警告"
        return 1
    elif [ "$warnings" -gt 0 ]; then
        log_warn "验证通过，有 ${warnings} 个警告（不影响使用）"
        return 0
    else
        log_ok "全部验证通过！"
        return 0
    fi
}

print_success_message() {
    echo ""
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${GREEN}${BOLD}🎉  安装全部完成！Claude Code 已准备就绪！${NC}"
    echo ""
    echo "  你现在可以："
    echo "    1. 打开终端，输入 ${CYAN}claude${NC} 启动"
    echo "    2. 试试说：\"帮我写一个 Python 脚本\""
    echo ""
    if [ "${API_PROVIDER:-skip}" = "skip" ]; then
        echo "  ${YELLOW}⚠ API 尚未配置，请先配置后使用${NC}"
        echo "    手动编辑: ~/.claude/settings.json"
    fi
    echo ""
    echo "  后续如需添加/移除行业方案，重新运行："
    echo "    ${CYAN}bash install.sh --add-industry${NC}"
    echo ""
    echo "  如有问题，联系：${CYAN}${INSTALLER_BRAND}${NC}"
    echo ""
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}
