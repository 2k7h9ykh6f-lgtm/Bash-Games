#!/usr/bin/env bash

# filename: snake.sh
# snake game
# Author: LKJ 2013.5.17

EXITFLAG="/tmp/snake_exit.flag"
WRITEFILE="/tmp/snake_pipe.in"
READFILE="/tmp/snake_pipe.out"

INPUT_PIPES=()
readkey() {
    local txt;
    [ -f $WRITEFILE ] && mv $WRITEFILE $READFILE &> /dev/null
    if [ -f $READFILE ]; then
        txt="$(cat $READFILE 2> /dev/null)"
        if ! [ -z "$txt" ]; then
            INPUT_PIPES+=(${txt})
        fi
        rm $READFILE &> /dev/null
    fi

    if ((${#INPUT_PIPES[@]} > 0)); then
        echo -n "${INPUT_PIPES[0]}";
        unset INPUT_PIPES[0];
        # INPUT_PIPES=(${INPUT_PIPES[@]:1})
    fi
}

good_game=(
    '                                                 '
    '                G A M E  O V E R !               '
    '                                                 '
    '                   Score:                        '
    '          press   q   to quit                    '
    '          press   n   to start a new game        '
    '          press   m   to change the mode         '
    '                                                 '
);

game_start=(
    '                                                 '
    '                ~~~ S N A K E ~~~                '
    '                                                 '
    '                  Author:  LKJ                   '
    '         space or enter   pause/play             '
    '         q                quit at any time       '
    '         m (at game over) change difficulty      '
    '                                                 '
    '         Press <Enter> to start the game         '
    '                                                 '
);

mode_menu=(
    '            ~~~  SELECT  DIFFICULTY  ~~~          '
    '                                                 '
    '   1) Easy    slow start | gentle ramp           '
    '              walls OFF (wrap) | food x1          '
    '   2) Normal  balanced speed | normal ramp        '
    '              walls ON | food x2                  '
    '   3) Hard    fast start | steep ramp             '
    '              walls ON | food x3                  '
    '                                                 '
    '     Press 1 / 2 / 3 to choose   ( q = quit )    '
);

snake_exit() {  #退出游戏
    touch $EXITFLAG;
    wait # 等待进程退出
    stty echo;  #恢复回显
    tput rmcup; #恢复屏幕
    tput cvvis; #恢复光标
    exit 0;
}

draw_gui() {                                  # 画边框 
    clear;
    color="\033[34m*\033[0m";
    for (( i = 0; i < $1; i++ )); do
        echo -ne "\033[$i;0H${color}";
        echo -ne "\033[$i;$2H${color}";
    done

    for (( i = 0; i <= $2; i++ )); do
        echo -ne "\033[0;${i}H${color}";
        echo -ne "\033[$1;${i}H${color}";
    done

    draw_status;
    echo -en "\033[$Lines;$((Cols-50))H\033[33mPress <space> or enter to pause game\033[0m";
}

snake_init() {
    Lines=`tput lines`; Cols=`tput cols`;     #得到屏幕的长宽
    xline=$((Lines/2)); ycols=4;              #开始的位置
    xscore=$Lines;      yscore=$((Cols/2));   #打印分数的位置
    xcent=$xline;       ycent=$yscore;        #中心点位置
    xrand=0;            yrand=0;              #随机点 
    sumscore=0;         liveflag=1;           #总分和点存在标记
    sumnode=0;          foodscore=0;          #总共要加长的节点和点的分数
    
    snake="0000 ";                            #初始化贪吃蛇
    pos=(right right right right right);      #开始节点的方向
    xpt=($xline $xline $xline $xline $xline); #开始的各个节点的x坐标
    ypt=(5 4 3 2 1);                          #开始的各个节点的y坐标
    apply_mode;                               #按难度模式设置速度/分值/墙体(每局重置)

    draw_gui $((Lines-1)) $Cols
}

game_pause() {                                #暂停游戏
    echo -en "\033[$Lines;$((Cols-50))H\033[33mGame paused, Use space or enter key to continue\033[0m";
    while ! [ -f $EXITFLAG ]; do
        space="$(readkey)"
        [[ ${space:-enter} = enter ]] && \
            echo -en "\033[$Lines;$((Cols-50))H\033[33mPress <space> or enter to pause game           \033[0m" && return;
        [[ ${space:-enter} = q ]] && snake_exit;
        sleep 0.05;
    done
}

# $1 节点位置 
update() {                                    #更新各个节点坐标
    case ${pos[$1]} in
        right) ((ypt[$1]++));;
         left) ((ypt[$1]--));;
         down) ((xpt[$1]++));;
           up) ((xpt[$1]--));;
    esac
}

ms_to_sec() {                                 #毫秒整数转 sleep 用的小数秒
    printf '0.%03d' "$1";
}

apply_mode() {                                #按难度模式设定初始速度/分值/加速/墙体
    case "$mode" in
        easy)
            init_ms=160; accel_ms=8;  min_ms=70; food_value=1; wall=0; mode_name="Easy  ";;
        hard)
            init_ms=70;  accel_ms=12; min_ms=28; food_value=3; wall=1; mode_name="Hard  ";;
        *)
            mode="normal";
            init_ms=110; accel_ms=10; min_ms=45; food_value=2; wall=1; mode_name="Normal";;
    esac
    cur_ms=$init_ms;                          #当前帧间隔(毫秒)
    speed_level=1;                            #速度等级(从1开始)
    cur_delay=$(ms_to_sec $cur_ms);           #sleep 用的小数秒
}

update_speed() {                              #依分数推进动态速度曲线
    local lvl=$(( sumscore / 10 + 1 ));
    if (( lvl != speed_level )); then
        speed_level=$lvl;
        cur_ms=$(( init_ms - (speed_level-1)*accel_ms ));
        (( cur_ms < min_ms )) && cur_ms=$min_ms;
        cur_delay=$(ms_to_sec $cur_ms);
    fi
}

wrap_node() {                                 #墙体关闭时,将节点 $1 环绕到对侧
    (( xpt[$1] >= Lines-1 )) && xpt[$1]=2;
    (( xpt[$1] <= 1 ))       && xpt[$1]=$((Lines-2));
    (( ypt[$1] >= Cols ))    && ypt[$1]=2;
    (( ypt[$1] <= 1 ))       && ypt[$1]=$((Cols-1));
}

boundary_check() {                            #蛇头边界:墙体开则判定撞墙(返回1),墙体关则穿墙
    local x=${xpt[0]} y=${ypt[0]}
    if (( x>=Lines-1 || x<=1 || y>=Cols || y<=1 )); then
        (( wall == 1 )) && return 1;
        wrap_node 0;
    fi
    return 0;
}

draw_status() {                               #底部状态栏:模式 / 速度等级 / 分数
    echo -ne "\033[$Lines;3H\033[33mMode: ${mode_name}\033[0m";
    echo -ne "\033[$Lines;20H\033[36mSpeed Lv: ${speed_level}  \033[0m";
    echo -ne "\033[$Lines;38H\033[35mScore: ${sumscore}   \033[0m";
}

Gooooo() {                                   #更新方向
    case ${key:-enter} in
        j|J) [[ ${pos[0]} != "up"    ]] && pos[0]="down";;
        k|K) [[ ${pos[0]} != "down"  ]] && pos[0]="up";;
        h|H) [[ ${pos[0]} != "right" ]] && pos[0]="left";;
        l|L) [[ ${pos[0]} != "left"  ]] && pos[0]="right";;
        q|Q) snake_exit;;
      enter) game_pause;;
    esac
}

add_node() {                                 #增加节点
    snake="0$snake";
    pos=(${pos[0]} ${pos[@]});
    xpt=(${xpt[0]} ${xpt[@]});
    ypt=(${ypt[0]} ${ypt[@]});
    update 0;

    boundary_check || return 1;                #撞墙(墙体开)或穿墙(墙体关)

    for (( i = $((${#snake}-1)); i > 0; i-- )); do
        (( ${xpt[0]} == ${xpt[$i]} && ${ypt[0]} == ${ypt[$i]} )) && return 1; #crashed
    done

    echo -ne "\033[${xpt[0]};${ypt[0]}H\033[32m${snake[@]:0:1}\033[0m";
    return 0;
}

mk_random() {                               #产生随机点和随机数
    xrand=$((RANDOM%(Lines-3)+2));
    yrand=$((RANDOM%(Cols-2)+2));
    foodscore=$((RANDOM%9+1));

    echo -ne "\033[$xrand;${yrand}H$foodscore";
    liveflag=0;
}

new_game() {                                #重新开始新游戏
    snake_init;
    while ! [ -f $EXITFLAG ]; do
        key="$(readkey)"
        if [[ -z "$key" ]]; then
            sleep $cur_delay;                                 #帧间隔由动态速度曲线决定
        else
            Gooooo;
        fi

        ((liveflag==0)) || mk_random;
        if (( sumnode > 0 )); then
            ((sumnode--));
            add_node; (($?==0)) || return 1;                  #增长时:add_node 内含边界处理
        else
            update 0;
            boundary_check || return 1;                       #撞墙(墙体开)或穿墙(墙体关)
            echo -ne "\033[${xpt[0]};${ypt[0]}H\033[32m${snake[@]:0:1}\033[0m";

            for (( i = $((${#snake}-1)); i > 0; i-- )); do
                update $i;
                (( wall == 0 )) && wrap_node $i;              #墙体关闭时身体也穿墙
                echo -ne "\033[${xpt[$i]};${ypt[$i]}H\033[32m${snake[@]:$i:1}\033[0m";

                (( ${xpt[0]} == ${xpt[$i]} && ${ypt[0]} == ${ypt[$i]} )) && return 1; #crashed
                [[ ${pos[$((i-1))]} = ${pos[$i]} ]] || pos[$i]=${pos[$((i-1))]};
            done
        fi

        local x=${xpt[0]} y=${ypt[0]}
        if (( x==xrand && y==yrand )); then                   #吃到食物
            liveflag=1;
            (( sumnode  += foodscore ));                      #按基础食物值增长蛇身
            (( sumscore += foodscore * food_value ));         #分数按模式倍率累加
            update_speed;                                     #依分数推进速度曲线
        fi

        draw_status;                                          #刷新状态栏(模式/速度等级/分数)
    done
}

print_good_game() {
    local x=$((xcent-4)) y=$((ycent-25))
    for (( i = 0; i < 8; i++ )); do
        echo -ne "\033[$((x+i));${y}H\033[45m${good_game[$i]}\033[0m";
    done
    echo -ne "\033[$((x+3));$((ycent+1))H\033[45m${sumscore}\033[0m";
}

select_mode() {                               #开局/重开时选择难度模式(仅设置 mode,不污染其它状态)
    Lines=`tput lines`; Cols=`tput cols`;
    clear;
    local x=$((Lines/2-5)) y=$((Cols/2-25))
    for (( i = 0; i < ${#mode_menu[@]}; i++ )); do
        echo -ne "\033[$((x+i));${y}H\033[45m${mode_menu[$i]}\033[0m";
    done

    while ! [ -f $EXITFLAG ]; do
        anykey="$(readkey)"
        case "${anykey}" in
            1|e|E) mode="easy";   return;;
            2|n|N) mode="normal"; return;;
            3|h|H) mode="hard";   return;;
            q|Q)   snake_exit;;
        esac
        sleep 0.05;
    done
}

print_game_start() {
    select_mode;                              #先选难度,再据此初始化本局
    snake_init;

    local x=$((xcent-5)) y=$((ycent-25))
    for (( i = 0; i < 10; i++ )); do
        echo -ne "\033[$((x+i));${y}H\033[45m${game_start[$i]}\033[0m";
    done

    while ! [ -f $EXITFLAG ]; do
        anykey="$(readkey)"
        [[ ${anykey:-enter} = enter ]] && break;
        [[ ${anykey:-enter} = q ]] && snake_exit;
        sleep 0.05;
    done
    
    while ! [ -f $EXITFLAG ]; do
        new_game;
        print_good_game;
        while ! [ -f $EXITFLAG ]; do
            anykey="$(readkey)"
            [[ $anykey = n ]] && break;
            [[ $anykey = m ]] && { select_mode; break; };   #m:更换难度后重开(下一局据新模式初始化)
            [[ $anykey = q ]] && snake_exit;
            sleep 0.05;
        done
    done
}

stty -echo &> /dev/null;                  #取消回显
tput civis;                               #隐藏光标
tput smcup; clear;                        #保存屏幕并清屏

[ -f $EXITFLAG ] && rm $EXITFLAG
[ -f $WRITEFILE ] && rm $WRITEFILE
[ -f $READFILE ] && rm $READFILE
trap 'snake_exit;' SIGTERM SIGINT; 

{
    print_game_start;                         #开始游戏 
} &

IFS=""
while read -n 1 gkey; do
    [ "$gkey" = ' ' ] && gkey="space"
    echo "${gkey:-enter}" >> $WRITEFILE
    [[ "$gkey" = 'q' ]] || [[ "$gkey" = 'Q' ]] && break
done

snake_exit
