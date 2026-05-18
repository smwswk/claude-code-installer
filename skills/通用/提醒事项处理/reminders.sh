#!/bin/bash
#
# 提醒事项批量处理 - 封装 osascript 读写 Reminders.app
# 用法: reminders.sh list          # 列出所有未完成事项
#       reminders.sh complete <list> <item>  # 标记指定事项为已完成
#       reminders.sh delete <list> <item>    # 删除指定事项
#       reminders.sh create <list> <item>    # 创建新事项（如列表不存在则自动创建）
#
set -euo pipefail

list_all() {
    osascript -e '
    tell application "Reminders"
        set out to ""
        repeat with l in lists
            set listName to name of l
            repeat with r in (reminders of l whose completed is false)
                set itemName to name of r
                set dueDate to due date of r
                if dueDate is missing value then
                    set dueStr to "无"
                else
                    set dueStr to dueDate as string
                end if
                set out to out & listName & "|" & itemName & "|" & dueStr & linefeed
            end repeat
        end repeat
        return out
    end tell
    '
}

complete_item() {
    local list_name="$1"
    local item_name="$2"
    osascript -e "
    tell application \"Reminders\"
        set targetList to first list whose name is \"$list_name\"
        set targetItem to first reminder of targetList whose name is \"$item_name\"
        set completed of targetItem to true
    end tell
    "
}

delete_item() {
    local list_name="$1"
    local item_name="$2"
    osascript -e "
    tell application \"Reminders\"
        set targetList to first list whose name is \"$list_name\"
        set targetItem to first reminder of targetList whose name is \"$item_name\"
        delete targetItem
    end tell
    "
}

create_item() {
    local list_name="$1"
    local item_name="$2"
    osascript -e "
    tell application \"Reminders\"
        if not (exists list \"$list_name\") then
            make new list with properties {name:\"$list_name\"}
        end if
        tell list \"$list_name\"
            make new reminder with properties {name:\"$item_name\"}
        end tell
    end tell
    "
}

case "${1:-}" in
    list|l)
        list_all
        ;;
    complete|c)
        if [ $# -lt 3 ]; then
            echo "Usage: $0 complete <list_name> <item_name>" >&2
            exit 1
        fi
        complete_item "$2" "$3"
        echo "Completed: [$2] $3"
        ;;
    delete|d)
        if [ $# -lt 3 ]; then
            echo "Usage: $0 delete <list_name> <item_name>" >&2
            exit 1
        fi
        delete_item "$2" "$3"
        echo "Deleted: [$2] $3"
        ;;
    create|cr)
        if [ $# -lt 3 ]; then
            echo "Usage: $0 create <list_name> <item_name>" >&2
            exit 1
        fi
        create_item "$2" "$3"
        echo "Created: [$2] $3"
        ;;
    *)
        echo "Usage: $0 {list|complete|c|delete|d|create|cr} [args...]" >&2
        exit 1
        ;;
esac
