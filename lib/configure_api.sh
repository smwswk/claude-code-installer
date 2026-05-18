#!/bin/bash
# configure_api.sh — API后端配置交互 + Key 验证
# 三路分支：DeepSeek / Anthropic / OpenAI兼容

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# 配置结果变量（供后续模块使用）
API_PROVIDER=""       # deepseek | anthropic | openai_compat | skip
API_KEY=""
API_BASE_URL=""
API_MODEL_NAME=""
API_DISABLE_AUTOUPDATER="1"

configure_api() {
    log_step "4" "9" "配置 AI 模型接口"

    echo "Claude Code 需要连接一个大语言模型 API 来运行。"
    echo ""

    # 根据网络环境推荐默认值
    local default_choice="1"
    if $PLATFORM_IS_CHINA; then
        echo -e "  ${GREEN}检测到你在中国大陆，推荐使用 DeepSeek API（国内直连，无需代理）${NC}"
        default_choice="1"
    else
        echo -e "  ${GREEN}检测到海外网络，可以使用 Anthropic 官方 API${NC}"
        default_choice="2"
    fi
    echo ""

    echo "  [1] DeepSeek API (推荐，国内直连，Claude兼容)"
    echo "  [2] Anthropic 官方 API (海外/有代理)"
    echo "  [3] 自定义 OpenAI 兼容 API (硅基流动/Groq/OpenRouter 等)"
    echo "  [4] 跳过，稍后手动配置"
    echo ""

    local choice
    choice=$(ask "请选择" "$default_choice")

    case "$choice" in
        1) configure_deepseek ;;
        2) configure_anthropic ;;
        3) configure_openai_compat ;;
        4)
            API_PROVIDER="skip"
            log_info "已跳过 API 配置，稍后可在 ~/.claude/settings.json 手动配置"
            return 0
            ;;
        *)
            log_warn "无效选择，使用默认 DeepSeek API"
            configure_deepseek
            ;;
    esac

    # 验证 API Key
    if [ -n "$API_KEY" ] && [ "$API_PROVIDER" != "skip" ]; then
        echo ""
        log_info "正在验证 API Key..."
        if verify_api_key; then
            log_ok "API Key 验证通过"
        else
            log_warn "API Key 验证失败，但已保存配置（可稍后修改）"
        fi
    fi

    export API_PROVIDER API_KEY API_BASE_URL API_MODEL_NAME API_DISABLE_AUTOUPDATER
}

configure_deepseek() {
    API_PROVIDER="deepseek"
    API_BASE_URL="https://api.deepseek.com/anthropic"

    echo ""
    echo -e "${CYAN}使用 DeepSeek API 作为后端${NC}"
    echo ""
    echo "优势："
    echo "  ✅ 国内可直接访问，无需代理"
    echo "  ✅ 支持 Claude API 兼容模式"
    echo "  ✅ 价格实惠"
    echo ""
    echo "需要准备："
    echo "  - DeepSeek API Key (在 platform.deepseek.com 获取)"
    echo ""

    echo -e "${YELLOW}请打开浏览器访问：https://platform.deepseek.com/api_keys${NC}"
    echo -e "${YELLOW}注册/登录后在「API Keys」页面创建一个新 Key${NC}"
    echo ""

    API_KEY=$(ask_secret "请粘贴 DeepSeek API Key（留空稍后配置）")

    if [ -n "$API_KEY" ]; then
        echo ""
        echo "可用模型：deepseek-v4-pro / deepseek-chat / deepseek-reasoner"
        API_MODEL_NAME=$(ask "默认模型" "deepseek-v4-pro")
        API_DISABLE_AUTOUPDATER="1"
    else
        API_MODEL_NAME="deepseek-v4-pro"
        log_info "API Key 留空，配置文件将保留占位符"
    fi

    log_ok "DeepSeek API 配置完成"
}

configure_anthropic() {
    API_PROVIDER="anthropic"
    API_BASE_URL=""

    echo ""
    echo -e "${CYAN}使用 Anthropic 官方 API${NC}"
    echo ""
    echo "需要准备："
    echo "  - Anthropic API Key (console.anthropic.com → API Keys)"
    echo "  - 国际信用卡或支持美元支付的渠道"
    echo "  - 在中国大陆需要可靠的代理/VPN"
    echo ""

    API_KEY=$(ask_secret "请粘贴 Anthropic API Key（留空稍后配置）")

    if [ -n "$API_KEY" ]; then
        echo ""
        echo "选择模型："
        echo "  [1] claude-opus-4-7 (最强，最贵)"
        echo "  [2] claude-sonnet-4-6 (均衡，推荐)"
        echo "  [3] 自定义模型名"
        local model_choice
        model_choice=$(ask "请选择" "2")
        case "$model_choice" in
            1) API_MODEL_NAME="claude-opus-4-7" ;;
            2) API_MODEL_NAME="claude-sonnet-4-6" ;;
            3) API_MODEL_NAME=$(ask "请输入模型名" "claude-sonnet-4-6") ;;
            *) API_MODEL_NAME="claude-sonnet-4-6" ;;
        esac

        # Anthropic 官方推荐开启自动更新
        API_DISABLE_AUTOUPDATER="0"
    else
        API_MODEL_NAME="claude-sonnet-4-6"
    fi

    log_ok "Anthropic API 配置完成"
}

configure_openai_compat() {
    API_PROVIDER="openai_compat"

    echo ""
    echo -e "${CYAN}使用 OpenAI 兼容 API${NC}"
    echo ""
    echo "支持：硅基流动、Groq、OpenRouter、One API 等所有兼容接口"
    echo "常用接口地址参考："
    echo "  硅基流动：https://api.siliconflow.cn/v1"
    echo "  OpenRouter：https://openrouter.ai/api/v1"
    echo "  Groq：https://api.groq.com/openai/v1"
    echo ""

    API_BASE_URL=$(ask "接口地址 (Base URL)" "")
    API_KEY=$(ask_secret "API Key（留空稍后配置）")

    if [ -n "$API_KEY" ] && [ -n "$API_BASE_URL" ]; then
        API_MODEL_NAME=$(ask "模型名称" "claude-3-5-sonnet-20241022")
        API_DISABLE_AUTOUPDATER="1"
    else
        API_MODEL_NAME="claude-3-5-sonnet-20241022"
    fi

    log_ok "自定义 API 配置完成"
}

verify_api_key() {
    # 轻量验证：发送一个简单请求检查 Key 是否有效
    local test_url=""
    local test_header=""
    local test_body=""
    local http_code

    case "$API_PROVIDER" in
        deepseek)
            test_url="${API_BASE_URL}/v1/messages"
            test_header="Authorization: Bearer ${API_KEY}"
            test_body='{"model":"'${API_MODEL_NAME}'","max_tokens":1,"messages":[{"role":"user","content":"hi"}]}'
            ;;
        anthropic)
            test_url="https://api.anthropic.com/v1/messages"
            test_header="x-api-key: ${API_KEY}"
            test_body='{"model":"'${API_MODEL_NAME}'","max_tokens":1,"messages":[{"role":"user","content":"hi"}]}'
            ;;
        openai_compat)
            test_url="${API_BASE_URL}/chat/completions"
            test_header="Authorization: Bearer ${API_KEY}"
            test_body='{"model":"'${API_MODEL_NAME}'","max_tokens":1,"messages":[{"role":"user","content":"hi"}]}'
            ;;
        *)
            return 1
            ;;
    esac

    http_code=$(curl -s --connect-timeout 10 --max-time 15 \
        -o /dev/null -w "%{http_code}" \
        -H "Content-Type: application/json" \
        -H "$test_header" \
        -d "$test_body" \
        "$test_url" 2>/dev/null || echo "000")

    case "$http_code" in
        200|201) return 0 ;;
        401|403)
            log_error "API Key 被拒绝 (HTTP $http_code)，请检查 Key 是否正确"
            return 1
            ;;
        429)
            log_warn "API 请求频率限制 (HTTP 429)，Key 格式可能正确但无法确认"
            return 0  # 不确定但也不阻止
            ;;
        *)
            log_warn "验证请求返回 HTTP $http_code，可能是网络问题"
            return 0  # 不阻止安装
            ;;
    esac
}
