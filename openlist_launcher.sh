#!/bin/bash

# 获取当前脚本所在应用程序包的Contents目录
APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Resources目录
RES_DIR="$APP_DIR/Resources"

# 实际的OpenList可执行文件路径
BIN_PATH="$RES_DIR/openlist"

# 数据目录，通常放在 ~/Library/Application Support/OpenList
DATA_DIR="$HOME/Library/Application Support/OpenList"

# 图标路径，用于AppleScript对话框
ICON_PATH="$RES_DIR/openlist.icns"

# 服务访问URL
SERVICE_URL="http://localhost:5244"

# 检查服务是否运行
is_running() {
    pgrep -f "openlist server" >/dev/null
}

# 获取服务状态文本
get_status_text() {
    if is_running; then
        echo "✅ 服务正在运行"
    else
        echo "❌ 服务未运行"
    fi
}

# 启动服务核心逻辑
start_service_core() {
    if ! is_running; then
        mkdir -p "$DATA_DIR"
        nohup "$BIN_PATH" start --data "$DATA_DIR" --force-bin-dir > "$DATA_DIR/openlist_server.log" 2>&1 &
        echo $! > "$DATA_DIR/openlist_pid.txt"
        sleep 2
    fi
}

# 停止服务
stop_service() {
    if is_running; then
        if [ -f "$DATA_DIR/openlist_pid.txt" ]; then
            PID=$(cat "$DATA_DIR/openlist_pid.txt")
            if ps -p $PID > /dev/null; then
                kill $PID
                sleep 1
                if ! is_running; then
                    rm "$DATA_DIR/openlist_pid.txt"
                    return 0
                fi
            fi
        fi
        "$BIN_PATH" stop --data "$DATA_DIR"
        sleep 1
        if ! is_running; then
            return 0
        else
            pkill -f "openlist server"
            sleep 1
            if ! is_running; then
                return 0
            fi
        fi
        return 1
    else
        return 1
    fi
}

# 主菜单
main_menu() {
    while true; do
        local status_text=$(get_status_text)
        choice=$(osascript -e '
            set iconPath to (POSIX file "'"$ICON_PATH"'" as alias)
            display dialog "🌐 OpenList 服务控制面板\n\n'"$status_text"'" buttons {"启动服务", "更多操作", "退出"} default button "退出" with title "OpenList 控制台" with icon iconPath
            return button returned of result
        ')

        case "$choice" in
            "启动服务") handle_start_service_flow ;;
            "更多操作") handle_secondary_menu_flow ;;
            "退出")
                local confirm_exit=$(osascript -e '
                    set iconPath to (POSIX file "'"$ICON_PATH"'" as alias)
                    display dialog "您确定要退出 OpenList 控制台吗？服务将继续在后台运行。" buttons {"继续运行服务并退出", "停止服务并退出", "取消"} default button "继续运行服务并退出" with title "确认退出" with icon iconPath
                    return button returned of result
                ')
                case "$confirm_exit" in
                    "停止服务并退出") stop_service; exit 0 ;;
                    "继续运行服务并退出") exit 0 ;;
                    "取消") ;;
                esac
                ;;
        esac
    done
}

# 启动服务流程
handle_start_service_flow() {
    start_service_core
    local choice=$(osascript -e '
        set iconPath to (POSIX file "'"$ICON_PATH"'" as alias)
        display dialog "OpenList 服务已尝试启动！\n\n'"$(get_status_text)"'" buttons {"访问地址", "返回"} default button "返回" with title "服务状态" with icon iconPath
        return button returned of result
    ')
    case "$choice" in
        "访问地址") handle_access_url_action; exit 0 ;;
        "返回") ;;
    esac 
}

# 二级菜单流程
handle_secondary_menu_flow() {
    local action=$(osascript -e '
        set iconPath to (POSIX file "'"$ICON_PATH"'" as alias)
        display dialog "请选择要执行的操作：" buttons {"停止服务", "重置密码", "返回"} default button "返回" with title "服务操作" with icon iconPath
        return button returned of result
    ')
    case "$action" in
        "停止服务") handle_stop_service_action ;;
        "重置密码") handle_reset_password_flow ;;
        "返回") ;;
    esac
}

# 停止服务操作
handle_stop_service_action() {
    if stop_service; then
        osascript -e 'display notification "OpenList 服务已停止" with title "✅ 操作完成"'
        osascript -e '
            set iconPath to (POSIX file "'"$ICON_PATH"'" as alias)
            display dialog "OpenList 服务已停止！\n\n'"$(get_status_text)"'" buttons {"确定"} default button "确定" with title "操作完成" with icon iconPath
        '
        exit 0
    else
        osascript -e '
            set iconPath to (POSIX file "'"$ICON_PATH"'" as alias)
            display dialog "服务未运行，无法停止。\n\n'"$(get_status_text)"'" buttons {"确定"} default button "确定" with title "操作失败" with icon iconPath
        '
    fi
}

# 访问服务URL
handle_access_url_action() {
    if is_running; then
        open "$SERVICE_URL"
        osascript -e '
            set iconPath to (POSIX file "'"$ICON_PATH"'" as alias)
            display dialog "已在浏览器中打开服务地址。\n\n'"$(get_status_text)"'" buttons {"确定"} default button "确定" with title "操作完成" with icon iconPath
        '
    else
        osascript -e '
            set iconPath to (POSIX file "'"$ICON_PATH"'" as alias)
            display dialog "服务未启动，无法访问。\n\n'"$(get_status_text)"'" buttons {"确定"} default button "确定" with title "操作失败" with icon iconPath
        '
    fi
}

# 重置密码流程
handle_reset_password_flow() {
    local reset_action=$(osascript -e '
        set iconPath to (POSIX file "'"$ICON_PATH"'" as alias)
        display dialog "请选择重置密码方式：" buttons {"随机生成", "手动设置", "返回"} default button "返回" with title "重置密码" with icon iconPath
        return button returned of result
    ')
    case "$reset_action" in
        "随机生成") handle_random_password_reset ;;
        "手动设置") handle_manual_password_set ;;
        "返回") ;;
    esac
}

# ✅ 修复后的随机密码重置
handle_random_password_reset() {
    if is_running; then
        local confirm=$(osascript -e '
            set iconPath to (POSIX file "'"$ICON_PATH"'" as alias)
            display dialog "重置密码需要先停止 OpenList 服务，是否继续？" buttons {"继续", "取消"} default button "取消" with title "确认操作" with icon iconPath
            return button returned of result
        ')
        if [ "$confirm" == "取消" ]; then
            osascript -e '
                set iconPath to (POSIX file "'"$ICON_PATH"'" as alias)
                display dialog "已取消操作。" buttons {"确定"} default button "确定" with title "取消" with icon iconPath
            '
            return
        fi
        stop_service
        sleep 2
    fi

    rm -f "$DATA_DIR/openlist_server.log"
    "$BIN_PATH" admin random --data "$DATA_DIR" >> "$DATA_DIR/openlist_server.log" 2>&1

    local new_password=$(grep 'password:' "$DATA_DIR/openlist_server.log" | tail -n1 | awk -F 'password:' '{gsub(/^[ \t]+/, "", $2); print $2}')

    if [ -z "$new_password" ]; then
        new_password="（未能识别密码，请手动查看日志）"
    fi

    osascript <<EOF
set iconPathAlias to (POSIX file "$ICON_PATH" as alias)
display dialog "已生成新的随机密码：\n\n$new_password\n\n请复制并保存。您可以重新启动服务。" buttons {"确定"} default button "确定" with title "密码已重置" with icon iconPathAlias
EOF
}

# 手动设置密码
handle_manual_password_set() {
    if is_running; then
        local confirm=$(osascript -e '
            set iconPath to (POSIX file "'"$ICON_PATH"'" as alias)
            display dialog "重置密码需要先停止 OpenList 服务，是否继续？" buttons {"继续", "取消"} default button "取消" with title "确认操作" with icon iconPath
            return button returned of result
        ')
        if [ "$confirm" == "取消" ]; then
            osascript -e '
                set iconPath to (POSIX file "'"$ICON_PATH"'" as alias)
                display dialog "已取消操作。" buttons {"确定"} default button "确定" with title "取消" with icon iconPath
            '
            return
        fi
        stop_service
        sleep 2
    fi

    local user_input=$(osascript -e "
        set iconPathAlias to (POSIX file \"$ICON_PATH\" as alias)
        try
            display dialog \"请输入您想设置的新密码：\" default answer \"\" with icon iconPathAlias buttons {\"设置\", \"取消\"} default button \"设置\"
            if button returned of result is \"设置\" then
                return text returned of result
            else
                return \"CANCELLED\"
            end if
        on error
            return \"CANCELLED\"
        end try
    ")

    if [ "$user_input" == "CANCELLED" ]; then
        osascript -e '
            set iconPath to (POSIX file "'"$ICON_PATH"'" as alias)
            display dialog "已取消密码设置。" buttons {"确定"} default button "确定" with title "取消" with icon iconPath
        '
        return
    fi

    if [ -z "$user_input" ]; then
        osascript -e '
            set iconPath to (POSIX file "'"$ICON_PATH"'" as alias)
            display dialog "密码不能为空，已取消设置。" buttons {"确定"} default button "确定" with title "错误" with icon iconPath
        '
        return
    fi

    "$BIN_PATH" admin set "$user_input" --data "$DATA_DIR"

    osascript <<EOF
set iconPathAlias to (POSIX file "$ICON_PATH" as alias)
display dialog "密码已成功设置为：\n\n$user_input\n\n您可以重新启动服务。" buttons {"确定"} default button "确定" with title "密码已设置" with icon iconPathAlias
EOF
}

# 启动控制台
main_menu
