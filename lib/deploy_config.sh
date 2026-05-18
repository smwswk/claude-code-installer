#!/bin/bash
# deploy_config.sh — 模板渲染引擎
# 将 templates/ 中的 {{PLACEHOLDER}} 替换为用户实际值
# 输出：~/.claude/settings.json / settings.local.json / ~/CLAUDE.md

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

TEMPLATES_DIR="$(dirname "${BASH_SOURCE[0]}")/../templates"

deploy_config() {
    log_step "6" "9" "部署配置文件"

    local claude_dir="$HOME/.claude"
    mkdir -p "$claude_dir"

    # 备份已有配置
    if [ -f "$claude_dir/settings.json" ]; then
        backup_existing "$claude_dir/settings.json"
    fi
    if [ -f "$claude_dir/settings.local.json" ]; then
        backup_existing "$claude_dir/settings.local.json"
    fi
    if [ -f "$HOME/CLAUDE.md" ]; then
        backup_existing "$HOME/CLAUDE.md"
    fi

    # 1. 渲染 settings.json
    log_info "正在生成 ~/.claude/settings.json..."
    render_settings_json > "$claude_dir/settings.json"
    log_ok "settings.json 已生成"

    # 2. 渲染 settings.local.json
    log_info "正在生成 ~/.claude/settings.local.json..."
    render_settings_local > "$claude_dir/settings.local.json"
    log_ok "settings.local.json 已生成"

    # 3. 渲染 CLAUDE.md
    if confirm "是否安装 CLAUDE.md 锚点规则到 home 目录？(推荐)" ; then
        log_info "正在生成 ~/CLAUDE.md..."
        render_claude_md > "$HOME/CLAUDE.md"
        log_ok "CLAUDE.md 已生成"
    else
        log_info "已跳过 CLAUDE.md 安装"
    fi

    echo ""
}

render_settings_json() {
    # 读取 base 模板
    local base settings_extra merged

    # 先从 base 读取
    if [ -f "$TEMPLATES_DIR/settings.base.json" ]; then
        base=$(cat "$TEMPLATES_DIR/settings.base.json")
    else
        base="{}"
    fi

    # 根据 API provider 选择对应模板
    case "${API_PROVIDER:-skip}" in
        deepseek)
            settings_extra=$(cat "$TEMPLATES_DIR/settings.deepseek.json")
            settings_extra="${settings_extra//\{\{API_KEY\}\}/$API_KEY}"
            settings_extra="${settings_extra//\{\{MODEL_NAME\}\}/$API_MODEL_NAME}"
            ;;
        anthropic)
            settings_extra=$(cat "$TEMPLATES_DIR/settings.anthropic.json")
            settings_extra="${settings_extra//\{\{API_KEY\}\}/$API_KEY}"
            settings_extra="${settings_extra//\{\{MODEL_NAME\}\}/$API_MODEL_NAME}"
            # 为 Anthropic 官方设置不同层级的模型
            case "$API_MODEL_NAME" in
                claude-opus-4-7*)
                    settings_extra="${settings_extra//\{\{HAIKU_MODEL\}\}/claude-haiku-4-5-20251001}"
                    settings_extra="${settings_extra//\{\{SONNET_MODEL\}\}/claude-sonnet-4-6}"
                    settings_extra="${settings_extra//\{\{OPUS_MODEL\}\}/claude-opus-4-7}"
                    ;;
                claude-sonnet-4-6*)
                    settings_extra="${settings_extra//\{\{HAIKU_MODEL\}\}/claude-haiku-4-5-20251001}"
                    settings_extra="${settings_extra//\{\{SONNET_MODEL\}\}/claude-sonnet-4-6}"
                    settings_extra="${settings_extra//\{\{OPUS_MODEL\}\}/claude-sonnet-4-6}"
                    ;;
                *)
                    settings_extra="${settings_extra//\{\{HAIKU_MODEL\}\}/$API_MODEL_NAME}"
                    settings_extra="${settings_extra//\{\{SONNET_MODEL\}\}/$API_MODEL_NAME}"
                    settings_extra="${settings_extra//\{\{OPUS_MODEL\}\}/$API_MODEL_NAME}"
                    ;;
            esac
            settings_extra="${settings_extra//\{\{DISABLE_AUTOUPDATER\}\}/$API_DISABLE_AUTOUPDATER}"
            ;;
        openai_compat)
            settings_extra=$(cat "$TEMPLATES_DIR/settings.openai_compat.json")
            settings_extra="${settings_extra//\{\{BASE_URL\}\}/$API_BASE_URL}"
            settings_extra="${settings_extra//\{\{API_KEY\}\}/$API_KEY}"
            settings_extra="${settings_extra//\{\{MODEL_NAME\}\}/$API_MODEL_NAME}"
            ;;
        *)
            # 跳过API配置，仅输出base
            echo "$base"
            return
            ;;
    esac

    # 简单JSON合并（base + extra）
    merge_json "$base" "$settings_extra"
}

render_settings_local() {
    if [ -f "$TEMPLATES_DIR/settings.local.base.json" ]; then
        cat "$TEMPLATES_DIR/settings.local.base.json"
    else
        echo '{"permissions":{"allow":[]},"hooks":{}}'
    fi
}

render_claude_md() {
    # CLAUDE.md.base 必装
    if [ -f "$TEMPLATES_DIR/CLAUDE.md.base" ]; then
        cat "$TEMPLATES_DIR/CLAUDE.md.base"
    fi

    # 如果安装了 superpowers，追加 superpowers 自动触发
    # (由 install_plugins.sh 设置 INSTALLED_SUPERPOWERS 变量)
    if ${INSTALLED_SUPERPOWERS:-false}; then
        if [ -f "$TEMPLATES_DIR/CLAUDE.md.superpowers.md" ]; then
            cat "$TEMPLATES_DIR/CLAUDE.md.superpowers.md"
        fi
    fi

    # 追加通用技能自动触发（始终安装的 neat-freak, memory-thin 等）
    echo ""
    echo "# 本地自定义自动触发"
    echo ""
    echo "以下为基础 skill，满足条件自动加载："
    echo ""
    echo "- **neat-freak**：verification 通过后自动运行，同步文档/记忆/CLAUDE.md 三层知识体系"
    echo "- **memory-thin**：用户说\"瘦身\"/\"清理记忆\"/\"记忆瘦身\"时触发"
    if [[ " ${SELECTED_INDUSTRIES[*]} " =~ "内容" ]]; then
        echo "- **主页维护**：新项目上线/新工具部署/新出图后主动询问是否更新主页"
    fi

    # 追加行业专属自动触发
    for industry in "${SELECTED_INDUSTRIES[@]}"; do
        case "$industry" in
            法律)
                if [ -f "$TEMPLATES_DIR/CLAUDE.md.industry.legal.md" ]; then
                    echo ""
                    cat "$TEMPLATES_DIR/CLAUDE.md.industry.legal.md"
                fi
                ;;
            摄影)
                if [ -f "$TEMPLATES_DIR/CLAUDE.md.industry.photo.md" ]; then
                    echo ""
                    cat "$TEMPLATES_DIR/CLAUDE.md.industry.photo.md"
                fi
                ;;
            内容)
                if [ -f "$TEMPLATES_DIR/CLAUDE.md.industry.content.md" ]; then
                    echo ""
                    cat "$TEMPLATES_DIR/CLAUDE.md.industry.content.md"
                fi
                ;;
            AI)
                if [ -f "$TEMPLATES_DIR/CLAUDE.md.industry.ai.md" ]; then
                    echo ""
                    cat "$TEMPLATES_DIR/CLAUDE.md.industry.ai.md"
                fi
                ;;
        esac
    done
}

# ── 简单 JSON 合并工具 ───────────────────────────────────

merge_json() {
    local base="$1" extra="$2"
    # 用 python3 做 JSON 深度合并（如果可用），否则简单拼接
    if command -v python3 &>/dev/null; then
        python3 -c "
import json, sys
base = json.loads('''$base''')
extra = json.loads('''$extra''')
# 深度合并 extra 到 base
for key in extra:
    if key in base and isinstance(base[key], dict) and isinstance(extra[key], dict):
        base[key].update(extra[key])
    else:
        base[key] = extra[key]
print(json.dumps(base, indent=2, ensure_ascii=False))
" 2>/dev/null || { echo "$base"; echo "$extra"; }
    else
        # 无 python 时简单输出两者
        echo "$base"
        echo "$extra"
    fi
}
