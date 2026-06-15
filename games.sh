#!/usr/bin/env bash
#
# filename: games.sh
# Bash-Games 统一启动菜单 (unified terminal launcher)
#
# 进入一个终端菜单后, 可选择启动 俄罗斯方块(Tetris)、贪吃蛇(Snake)、
# 数字时钟(aclock.sh) 或退出。
# 本脚本不依赖任何外部 GUI 工具, 只使用 bash 与终端转义 (tput / ANSI)。
#

# 必须在交互式终端中运行, 否则 read 会立即返回造成空转。
if [ ! -t 0 ] || [ ! -t 1 ]; then
    echo "games.sh 需要在交互式终端中运行。" >&2
    exit 1
fi

# 脚本所在目录, 保证从任意位置运行都能找到同级的游戏脚本。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 颜色 (ANSI 转义)
C_TITLE='\033[1;36m'   # 标题: 亮青
C_NAME='\033[1;32m'    # 游戏名: 亮绿
C_KEY='\033[1;33m'     # 按键: 亮黄
C_WARN='\033[1;31m'    # 警告: 亮红
C_DIM='\033[2m'        # 次要说明: 暗色
C_RESET='\033[0m'

# 退出 / 中断时恢复终端状态 (光标与回显)。
cleanup() {
    tput cnorm 2>/dev/null   # 恢复光标
    stty echo  2>/dev/null   # 恢复回显
}
trap cleanup EXIT INT TERM

# 在固定左边距处输出一行 (块整体居中, 块内左对齐)。
# $1: 左边距字符串   $2: 行内容 (可含 ANSI 转义)
row() {
    printf '%s' "$1"
    printf '%b\n' "$2"
}

# 绘制菜单。每次都重新读取终端尺寸, 以适应窗口缩放。
draw_menu() {
    local cols lines
    cols=$(tput cols 2>/dev/null);  [ -z "$cols" ]  && cols=80
    lines=$(tput lines 2>/dev/null); [ -z "$lines" ] && lines=24

    # 内容块宽度, 据此计算左边距使其在屏幕中水平居中。
    local cw=56
    local margin=$(( (cols - cw) / 2 ))
    (( margin < 0 )) && margin=0
    local mp
    mp=$(printf '%*s' "$margin" '')

    # 垂直方向大致居中 (内容约 15 行)。
    local content_height=15
    local top=$(( (lines - content_height) / 2 ))
    (( top < 0 )) && top=0

    tput civis 2>/dev/null   # 隐藏光标, 让菜单更整洁
    clear

    local i
    for (( i = 0; i < top; i++ )); do echo; done

    row "$mp" "${C_TITLE}==============================================${C_RESET}"
    row "$mp" "${C_TITLE}      Bash-Games  终端游戏合集  启动菜单${C_RESET}"
    row "$mp" "${C_TITLE}==============================================${C_RESET}"
    echo

    row "$mp" "  ${C_KEY}1${C_RESET})  ${C_NAME}Tetris${C_RESET}   俄罗斯方块, 0~9 级, 支持回放"
    row "$mp" "        ${C_DIM}移动 h j k l    退出 q${C_RESET}"
    row "$mp" "  ${C_KEY}2${C_RESET})  ${C_NAME}Snake${C_RESET}    贪吃蛇"
    row "$mp" "        ${C_DIM}移动 h j k l    暂停 空格/回车    退出 q${C_RESET}"
    row "$mp" "  ${C_KEY}3${C_RESET})  ${C_NAME}Clock${C_RESET}    数字时钟 (aclock.sh, 无需 root)"
    row "$mp" "        ${C_DIM}按任意键返回菜单${C_RESET}"
    row "$mp" "  ${C_KEY}4${C_RESET})  ${C_NAME}退出${C_RESET}     离开启动菜单"
    echo

    row "$mp" "${C_KEY}请按 1 / 2 / 3 选择, 按 4 或 q 退出${C_RESET}"
    echo
    row "$mp" "${C_DIM}当前终端尺寸: ${cols} x ${lines}${C_RESET}"
}

# 显示一条提示信息并等待按键 (用于错误提示)。
# $1: 颜色   $2: 信息
notify() {
    clear
    echo
    printf '  %b%s%b\n' "$1" "$2" "$C_RESET"
    echo
    printf '  %b按任意键返回菜单...%b' "$C_DIM" "$C_RESET"
    read -rsn1 _
}

# 启动一个游戏脚本, 并在其退出后恢复终端。
# $1: 显示名   $2: 脚本文件名
launch() {
    local name="$1" script="$2"
    local path="$SCRIPT_DIR/$script"

    if [ ! -e "$path" ]; then
        notify "$C_WARN" "找不到 $script (期望路径: $path)"
        return
    fi
    if [ ! -x "$path" ]; then
        notify "$C_WARN" "$script 不可执行, 请先运行:  chmod +x \"$path\""
        return
    fi

    # 运行前恢复正常终端, 让游戏脚本自行管理终端状态。
    tput cnorm 2>/dev/null
    stty echo  2>/dev/null

    "$path"

    # 游戏退出后防御性恢复终端, 以防脚本异常退出未能还原。
    stty sane  2>/dev/null
    tput cnorm 2>/dev/null
}

main() {
    local choice
    while true; do
        draw_menu
        read -rsn1 choice
        case "$choice" in
            1)     launch "Tetris"   "tetris.sh" ;;
            2)     launch "Snake"    "snake.sh"  ;;
            3)     launch "数字时钟" "aclock.sh" ;;
            4|q|Q) break ;;
            *)     : ;;   # 其它按键忽略, 重新绘制菜单
        esac
    done

    clear
    printf 'Bye~\n'
}

main
