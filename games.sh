#!/bin/bash
#
# games.sh — Bash-Games 统一启动菜单
# 提供 Tetris、Snake、数字时钟的终端菜单选择入口
#

# ─── 脚本所在目录（兼容软链接和 source 执行） ───
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── 游戏脚本路径 ───
TETRIS_SCRIPT="$SCRIPT_DIR/tetris.sh"
SNAKE_SCRIPT="$SCRIPT_DIR/snake.sh"
CLOCK_SCRIPT="$SCRIPT_DIR/aclock.sh"

# ─── ANSI 颜色 ───
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ─── 检查脚本是否可用 ───
# 参数: $1=脚本路径, $2=脚本名称
check_script() {
    local path="$1"
    local name="$2"
    if [[ ! -f "$path" ]]; then
        return 1
    fi
    if [[ ! -x "$path" ]]; then
        return 2
    fi
    return 0
}

# ─── 获取脚本不可用的原因文本 ───
script_status_msg() {
    local path="$1"
    local name="$2"
    check_script "$path" "$name"
    local rc=$?
    if [[ $rc -eq 1 ]]; then
        echo "文件不存在"
    elif [[ $rc -eq 2 ]]; then
        echo "无执行权限 (尝试 chmod +x $name)"
    else
        echo "可用"
    fi
    return $rc
}

# ─── 保存终端状态 ───
save_terminal() {
    tput smcup 2>/dev/null   # 切换到备用屏幕缓冲区
    tput civis 2>/dev/null   # 隐藏光标
    stty -echo 2>/dev/null   # 关闭回显
    clear
}

# ─── 恢复终端状态 ───
restore_terminal() {
    tput rmcup 2>/dev/null   # 恢复主屏幕缓冲区
    tput cvvis 2>/dev/null   # 恢复光标显示
    stty echo 2>/dev/null    # 恢复回显
}

# ─── 清理并退出 ───
cleanup_exit() {
    restore_terminal
    echo -e "${GREEN}感谢游玩 Bash-Games！再见！${RESET}"
    exit 0
}

# ─── 捕获信号确保终端恢复 ───
trap cleanup_exit SIGINT SIGTERM EXIT

# ─── 居中打印文本 ───
# 参数: $1=文本, $2=终端宽度
center_print() {
    local text="$1"
    local width="$2"
    # 去除 ANSI 转义序列来计算实际显示长度
    local clean_text
    clean_text=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local text_len=${#clean_text}
    local padding=$(( (width - text_len) / 2 ))
    if (( padding < 0 )); then
        padding=0
    fi
    printf "%*s%s\n" "$padding" "" "$text"
}

# ─── 绘制分隔线 ───
draw_line() {
    local width="$1"
    local char="${2:--}"
    local line=""
    for (( i=0; i<width && i<80; i++ )); do
        line+="$char"
    done
    center_print "${DIM}${line}${RESET}" "$width"
}

# ─── 启动游戏并恢复终端 ───
# 参数: $1=脚本路径, $2=游戏名称
launch_game() {
    local script_path="$1"
    local game_name="$2"

    # 启动前恢复终端，让游戏自己管理终端状态
    restore_terminal

    # 运行游戏
    bash "$script_path"
    local exit_code=$?

    # 游戏退出后重新保存终端（回到菜单）
    save_terminal

    return $exit_code
}

# ─── 显示菜单 ───
show_menu() {
    local cols lines
    cols=$(tput cols 2>/dev/null || echo 80)
    lines=$(tput lines 2>/dev/null || echo 24)

    clear

    # 顶部留白
    local top_pad=$(( lines / 6 ))
    if (( top_pad > 6 )); then top_pad=6; fi
    for (( i=0; i<top_pad; i++ )); do echo; done

    # 标题
    center_print "${BOLD}${CYAN}╔══════════════════════════════════════╗${RESET}" "$cols"
    center_print "${BOLD}${CYAN}║       🎮  Bash-Games 启动菜单  🎮     ║${RESET}" "$cols"
    center_print "${BOLD}${CYAN}╚══════════════════════════════════════╝${RESET}" "$cols"
    echo
    draw_line "$cols" "─"
    echo

    # 游戏选项
    local tetris_msg snake_msg clock_msg
    local tetris_ok=false snake_ok=false clock_ok=false

    if check_script "$TETRIS_SCRIPT" "tetris.sh"; then
        tetris_ok=true
        tetris_msg="${GREEN}[可用]${RESET}"
    else
        tetris_msg="${RED}[$(script_status_msg "$TETRIS_SCRIPT" "tetris.sh")]${RESET}"
    fi

    if check_script "$SNAKE_SCRIPT" "snake.sh"; then
        snake_ok=true
        snake_msg="${GREEN}[可用]${RESET}"
    else
        snake_msg="${RED}[$(script_status_msg "$SNAKE_SCRIPT" "snake.sh")]${RESET}"
    fi

    if check_script "$CLOCK_SCRIPT" "aclock.sh"; then
        clock_ok=true
        clock_msg="${GREEN}[可用]${RESET}"
    else
        clock_msg="${RED}[$(script_status_msg "$CLOCK_SCRIPT" "aclock.sh")]${RESET}"
    fi

    center_print "  ${BOLD}[1]${RESET} ${YELLOW}俄罗斯方块 (Tetris)${RESET}  $tetris_msg" "$cols"
    center_print "      ${DIM}经典方块下落游戏 | H/J/K/L 移动旋转, Q 退出${RESET}" "$cols"
    echo
    center_print "  ${BOLD}[2]${RESET} ${YELLOW}贪吃蛇 (Snake)${RESET}      $snake_msg" "$cols"
    center_print "      ${DIM}经典贪吃蛇游戏   | H/J/K/L 移动, S 变速, Q 退出${RESET}" "$cols"
    echo
    center_print "  ${BOLD}[3]${RESET} ${YELLOW}数字时钟 (Clock)${RESET}    $clock_msg" "$cols"
    center_print "      ${DIM}终端数字时钟显示 | 任意键退出${RESET}" "$cols"
    echo
    draw_line "$cols" "─"
    echo
    center_print "  ${BOLD}[Q]${RESET} ${DIM}退出菜单${RESET}" "$cols"
    echo
    draw_line "$cols" "─"
    echo
    center_print "${DIM}终端尺寸: ${cols} x ${lines}${RESET}" "$cols"
    echo
    center_print "${BOLD}请选择 [1/2/3/Q]: ${RESET}" "$cols"
}

# ─── 显示错误信息（在菜单底部） ───
show_error() {
    local msg="$1"
    echo
    center_print "${RED}⚠ $msg${RESET}" "$(tput cols 2>/dev/null || echo 80)"
    sleep 2
}

# ═══════════════════════════════════════════
#  主循环
# ═══════════════════════════════════════════

save_terminal

while true; do
    show_menu

    # 读取用户输入（单字符，超时60秒自动刷新）
    read -r -n 1 -t 60 choice 2>/dev/null
    local_rc=$?

    # 超时无输入则刷新菜单
    if [[ $local_rc -gt 128 ]]; then
        continue
    fi

    # 转为大写
    choice="${choice^^}"

    case "$choice" in
        1)
            if ! check_script "$TETRIS_SCRIPT" "tetris.sh"; then
                show_error "tetris.sh $(script_status_msg "$TETRIS_SCRIPT" "tetris.sh")，无法启动俄罗斯方块"
                continue
            fi
            launch_game "$TETRIS_SCRIPT" "Tetris"
            ;;
        2)
            if ! check_script "$SNAKE_SCRIPT" "snake.sh"; then
                show_error "snake.sh $(script_status_msg "$SNAKE_SCRIPT" "snake.sh")，无法启动贪吃蛇"
                continue
            fi
            launch_game "$SNAKE_SCRIPT" "Snake"
            ;;
        3)
            if ! check_script "$CLOCK_SCRIPT" "aclock.sh"; then
                show_error "aclock.sh $(script_status_msg "$CLOCK_SCRIPT" "aclock.sh")，无法启动数字时钟"
                continue
            fi
            launch_game "$CLOCK_SCRIPT" "Clock"
            ;;
        Q)
            cleanup_exit
            ;;
        *)
            if [[ -n "$choice" ]]; then
                show_error "无效选择「$choice」— 请输入 1、2、3 或 Q"
            fi
            ;;
    esac
done
