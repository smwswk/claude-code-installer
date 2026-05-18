#!/bin/bash
# deploy_skills.sh — 按选择复制技能和命令到 ~/.claude/
# 从包内 skills/commands/ 目录复制，做平台兼容过滤

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

PACKAGE_DIR="$(dirname "${BASH_SOURCE[0]}")/.."
SKILLS_SRC="$PACKAGE_DIR/skills"
COMMANDS_SRC="$PACKAGE_DIR/commands"
MANIFEST_FILE="$SKILLS_SRC/manifest.json"

deploy_skills() {
    log_step "7" "9" "安装技能包"

    local skills_dst="$HOME/.claude/skills"
    local commands_dst="$HOME/.claude/commands"

    mkdir -p "$skills_dst" "$commands_dst"

    # 备份已有技能
    if [ -d "$skills_dst" ] && [ "$(ls -A "$skills_dst" 2>/dev/null)" ]; then
        backup_existing "$skills_dst"
    fi

    local count=0
    local total=${#SELECTED_SKILLS[@]}
    local skipped=0

    echo ""
    for skill_ref in "${SELECTED_SKILLS[@]}"; do
        count=$((count + 1))
        progress_bar $count $total "安装技能"

        local industry skill_name
        industry="${skill_ref%%/*}"
        skill_name="${skill_ref##*/}"

        local src="$SKILLS_SRC/$industry/$skill_name"
        local dst="$skills_dst/$skill_name"

        # 检查平台兼容性
        if ! is_skill_platform_compatible "$industry" "$skill_name"; then
            log_warn "  $skill_name — 平台不兼容，跳过"
            skipped=$((skipped + 1))
            continue
        fi

        # 检查依赖工具
        local missing_tool
        missing_tool=$(check_skill_tools "$industry" "$skill_name")
        if [ -n "$missing_tool" ]; then
            log_warn "  $skill_name — 缺少工具: $missing_tool，技能已安装但可能不可用"
        fi

        # 复制技能
        if [ -d "$src" ]; then
            safe_copy "$src" "$dst"
            log_ok "  $skill_name"
        else
            log_warn "  $skill_name — 源目录不存在: $src"
            skipped=$((skipped + 1))
        fi
    done

    echo ""
    log_ok "技能安装完成：$((total - skipped))/$total 个"

    # 安装命令
    if [ ${#SELECTED_COMMANDS[@]} -gt 0 ]; then
        echo ""
        log_info "正在安装行业命令..."
        local cmd_count=0
        for cmd_name in "${SELECTED_COMMANDS[@]}"; do
            local cmd_src="$COMMANDS_SRC/法律/${cmd_name}.md"
            local cmd_dst="$commands_dst/${cmd_name}.md"

            if [ -f "$cmd_src" ]; then
                safe_copy "$cmd_src" "$cmd_dst"
                log_ok "  /${cmd_name}"
                cmd_count=$((cmd_count + 1))
            else
                log_warn "  命令源文件不存在: ${cmd_name}.md"
            fi
        done
        log_ok "命令安装完成：${cmd_count}/${#SELECTED_COMMANDS[@]} 个"
    fi

    # 为 needs_config 技能创建 _TODO_SETUP.md
    create_todo_files

    echo ""
}

is_skill_platform_compatible() {
    local industry="$1" skill_name="$2"

    if ! command -v python3 &>/dev/null; then
        return 0  # 无法检测则默认通过
    fi

    local platforms
    platforms=$(python3 -c "
import json
with open('$MANIFEST_FILE') as f:
    m = json.load(f)
skill = m['industries']['$industry']['skills'].get('$skill_name', {})
print(','.join(skill.get('platforms', [])))
" 2>/dev/null)

    if [ -z "$platforms" ]; then
        return 0
    fi

    if echo "$platforms" | grep -q "$PLATFORM_OS"; then
        return 0
    fi
    return 1
}

check_skill_tools() {
    local industry="$1" skill_name="$2"

    if ! command -v python3 &>/dev/null; then
        return 0
    fi

    python3 -c "
import json, subprocess, shutil

with open('$MANIFEST_FILE') as f:
    m = json.load(f)

skill = m['industries']['$industry']['skills'].get('$skill_name', {})
tools = skill.get('requires_tools', [])
missing = []

# 特殊工具名检查（不是命令名的情况）
tool_cmd_map = {
    'Reminders.app': None,  # macOS 专有，无法用 command -v 检查
    'tesseract': 'tesseract',
    'python3': 'python3',
    'ffmpeg': 'ffmpeg',
    'git': 'git',
    'hugo': 'hugo',
    'curl': 'curl',
}

for t in tools:
    cmd = tool_cmd_map.get(t, t)
    if cmd and not shutil.which(cmd):
        missing.append(t)

if missing:
    print(' '.join(missing))
" 2>/dev/null
}

create_todo_files() {
    # 为标记 needs_config 的技能创建配置提醒
    if ! command -v python3 &>/dev/null; then
        return 0
    fi

    local todos
    todos=$(python3 -c "
import json
with open('$MANIFEST_FILE') as f:
    m = json.load(f)

# 检查所有已选技能
selected = '${SELECTED_INDUSTRIES[*]}'.split()
todos = []

# 检查通用
for skill_id, skill in m['industries']['通用']['skills'].items():
    if skill.get('portability') == 'needs_config':
        todos.append(f'通用/{skill_id}: {skill[\"notes\"]}')

for ind_id in selected:
    if ind_id not in m['industries']:
        continue
    for skill_id, skill in m['industries'][ind_id].get('skills', {}).items():
        if skill.get('portability') == 'needs_config':
            todos.append(f'{ind_id}/{skill_id}: {skill[\"notes\"]}')

for t in todos:
    print(t)
" 2>/dev/null)

    if [ -n "$todos" ]; then
        local todo_file="$HOME/.claude/_SETUP_TODO.md"
        {
            echo "# 需要额外配置的技能"
            echo ""
            echo "以下技能已安装，但需要额外配置才能正常使用："
            echo ""
            echo "$todos" | while IFS= read -r line; do
                echo "- $line"
            done
            echo ""
            echo "---"
            echo "生成时间：$(date '+%Y-%m-%d %H:%M:%S')"
        } > "$todo_file"
        log_info "配置提醒已写入 ~/.claude/_SETUP_TODO.md"
    fi
}
