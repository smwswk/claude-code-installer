#!/bin/bash
# select_industry.sh — 行业多选交互菜单
# 输出：SELECTED_INDUSTRIES 数组 + 选中的技能/命令列表

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

MANIFEST_FILE="$(dirname "${BASH_SOURCE[0]}")/../skills/manifest.json"

# 选择结果
SELECTED_SKILLS=()      # "行业/技能名"
SELECTED_COMMANDS=()    # "命令名"
TOTAL_SKILL_COUNT=0

select_industry() {
    log_step "3" "9" "选择你的行业方案"

    echo "根据你的行业，我会安装对应的专业工具集（技能包）。"
    echo "可以选择多个（用空格分隔编号），也可以选择「全部安装」或「自定义」。"
    echo ""

    # 显示行业选项
    echo "  ${BOLD}[1]${NC} 🏛️   法律 / 行政复议"
    echo "         案件全流程管理 · OCR文识别 · 决定书核对 · 证据目录 · 物流单打印"
    echo ""
    echo "  ${BOLD}[2]${NC} 📷   摄影 / 视觉创作"
    echo "         当代摄影生图 · 哈苏Portra复刻 · 商业片出图 · 旅行攻略 · 直达根源"
    echo ""
    echo "  ${BOLD}[3]${NC} ✍️   内容创作 / 自媒体"
    echo "         小红书发布&总结 · 小说影像化 · 选题拷问 · B站总结 · 公众号解析"
    echo ""
    echo "  ${BOLD}[4]${NC} 🤖   AI 落地 / 创业"
    echo "         全自动总结迭代 · 内容引擎 · AI日报 · 播客/视频总结 · 知乎抓取"
    echo ""
    echo "  ${BOLD}[5]${NC} 🔧   通用工具 (始终安装，无需选择)"
    echo "         基础效率工具：记忆管理 · 数字日记 · 系统清理 · 调试"
    echo ""
    echo "  ${BOLD}[6]${NC} 📦   全部安装 (所有行业方案)"
    echo ""
    echo "  ${BOLD}[7]${NC} 🎯   自定义 (手动挑选单个技能)"
    echo ""

    local choice
    choice=$(ask "请输入编号（多选用空格分隔）" "6")

    # 解析选择
    SELECTED_INDUSTRIES=()
    for num in $choice; do
        case "$num" in
            1) SELECTED_INDUSTRIES+=("法律") ;;
            2) SELECTED_INDUSTRIES+=("摄影") ;;
            3) SELECTED_INDUSTRIES+=("内容") ;;
            4) SELECTED_INDUSTRIES+=("AI") ;;
            5) ;; # 通用始终安装
            6)
                SELECTED_INDUSTRIES=("法律" "摄影" "内容" "AI")
                break
                ;;
            7)
                custom_select
                return
                ;;
            *)
                log_warn "忽略无效选择: $num"
                ;;
        esac
    done

    # 去重
    SELECTED_INDUSTRIES=($(printf '%s\n' "${SELECTED_INDUSTRIES[@]}" | sort -u))

    # 如果没有选择任何行业，默认只有通用
    if [ ${#SELECTED_INDUSTRIES[@]} -eq 0 ]; then
        log_info "未选择行业，仅安装通用工具"
    fi

    resolve_selections
}

custom_select() {
    echo ""
    log_header "自定义：逐个挑选技能"
    echo "输入 y 安装，n 跳过"
    echo ""

    SELECTED_INDUSTRIES=()

    # 用 python 解析 manifest 列出所有技能
    if command -v python3 &>/dev/null; then
        local all_skills
        all_skills=$(python3 -c "
import json
with open('$MANIFEST_FILE') as f:
    m = json.load(f)
for ind_id, ind in m['industries'].items():
    if ind_id == '通用':
        continue
    for skill_id, skill in ind.get('skills', {}).items():
        print(f'{ind_id}|{ind[\"label\"]}|{skill_id}|{skill[\"notes\"]}')
" 2>/dev/null)

        if [ -n "$all_skills" ]; then
            while IFS='|' read -r ind_id ind_label skill_id skill_note; do
                if confirm "  [$ind_label] $skill_id — $skill_note？"; then
                    SELECTED_INDUSTRIES+=("$ind_id")
                    # 手动添加到 SELECTED_SKILLS
                    SELECTED_SKILLS+=("$ind_id/$skill_id")
                fi
            done <<< "$all_skills"
        fi
    else
        log_warn "python3 不可用，回退到全部安装"
        SELECTED_INDUSTRIES=("法律" "摄影" "内容" "AI")
    fi

    # 去重
    SELECTED_INDUSTRIES=($(printf '%s\n' "${SELECTED_INDUSTRIES[@]}" | sort -u))
    resolve_selections
}

resolve_selections() {
    # 用 manifest.json 解析选中行业对应的技能和命令
    if ! command -v python3 &>/dev/null; then
        log_error "需要 python3 来解析 manifest.json"
        return 1
    fi

    echo ""
    echo -e "${BOLD}你选择的方案：${NC}"

    # 通用始终包含
    echo "  ✅ 通用工具 (7个技能，始终安装)"

    # 解析选中的技能和命令
    local resolved
    resolved=$(python3 -c "
import json, sys

with open('$MANIFEST_FILE') as f:
    m = json.load(f)

selected = '${SELECTED_INDUSTRIES[*]}'.split()
skill_count = 0
cmd_count = 0
skills_output = []
cmds_output = []

# 通用始终安装
for skill_id in m['industries']['通用']['skills']:
    skill_count += 1
    skills_output.append(f'通用/{skill_id}')

for ind_id in selected:
    if ind_id not in m['industries']:
        continue
    ind = m['industries'][ind_id]
    # 技能
    for skill_id in ind.get('skills', {}):
        skill_count += 1
        skills_output.append(f'{ind_id}/{skill_id}')
    # 命令
    for cmd in ind.get('commands', []):
        cmd_count += 1
        cmds_output.append(cmd)

print(f'SKILL_COUNT={skill_count}')
print(f'CMD_COUNT={cmd_count}')
for s in skills_output:
    print(f'SKILL:{s}')
for c in cmds_output:
    print(f'CMD:{c}')
" 2>/dev/null)

    if [ -z "$resolved" ]; then
        log_error "无法解析技能清单，请确认 manifest.json 格式正确"
        return 1
    fi

    # 解析输出
    SELECTED_SKILLS=()
    SELECTED_COMMANDS=()
    while IFS= read -r line; do
        case "$line" in
            SKILL_COUNT=*) TOTAL_SKILL_COUNT="${line#SKILL_COUNT=}" ;;
            CMD_COUNT=*) TOTAL_CMD_COUNT="${line#CMD_COUNT=}" ;;
            SKILL:*) SELECTED_SKILLS+=("${line#SKILL:}") ;;
            CMD:*) SELECTED_COMMANDS+=("${line#CMD:}") ;;
        esac
    done <<< "$resolved"

    # 展示摘要
    for ind in "${SELECTED_INDUSTRIES[@]}"; do
        local label
        label=$(python3 -c "import json; m=json.load(open('$MANIFEST_FILE')); print(m['industries']['$ind']['label'])" 2>/dev/null || echo "$ind")
        local s_count
        s_count=$(python3 -c "import json; m=json.load(open('$MANIFEST_FILE')); print(len(m['industries']['$ind'].get('skills',{})))" 2>/dev/null || echo "?")
        echo "  ✅ $label (${s_count}个技能)"
    done

    echo ""
    echo "  共计 ${TOTAL_SKILL_COUNT} 个技能 + ${TOTAL_CMD_COUNT:-0} 个命令"
    echo ""

    export SELECTED_INDUSTRIES SELECTED_SKILLS SELECTED_COMMANDS TOTAL_SKILL_COUNT
}
