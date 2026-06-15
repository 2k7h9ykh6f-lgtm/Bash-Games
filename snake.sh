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
    '          press   s   to change the speed        '
    '                                                 '
);

game_start=(
    '                                                 '
    '                ~~~ S N A K E ~~~                '
    '                                                 '
    '                  Author:  LKJ                   '
    '         space or enter   pause/play             '
    '         q                quit at any time       '
    '         s                change the speed       '
    '                                                 '
    '         Press <Enter> to start the game         '
    '                                                 '
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

    ch_speed 0;
    echo -ne "\033[$Lines;$((yscore-10))H\033[36mScores: 0\033[0m";
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
    speed=(0.05 0.1 0.15);  spk=${spk:-1};    #速度 默认速度

    obs_num=$(((Lines+Cols)/8)); ((obs_num<5)) && obs_num=5;  #障碍数量
    obs_x=(); obs_y=();                        #障碍坐标(行/列)
    hflag=0; hx=0; hy=0; hscore=0; htimer=0;   #限时高分食物: 是否存在/坐标/分值/倒计时
    sflag=0; sx=0; sy=0;                        #减速食物: 是否存在/坐标

    draw_gui $((Lines-1)) $Cols
    gen_obstacles                             #在棋盘上生成障碍
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

ch_speed() {                                  #更新速度
     [[ $# -eq 0 ]] && spk=$(((spk+1)%3));
     case $spk in
         0) temp="Fast  ";;
         1) temp="Medium";;
         2) temp="Slow  ";;
     esac
     echo -ne "\033[$Lines;3H\033[33mSpeed: $temp\033[0m";
}

Gooooo() {                                   #更新方向
    case ${key:-enter} in
        j|J) [[ ${pos[0]} != "up"    ]] && pos[0]="down";;
        k|K) [[ ${pos[0]} != "down"  ]] && pos[0]="up";;
        h|H) [[ ${pos[0]} != "right" ]] && pos[0]="left";;
        l|L) [[ ${pos[0]} != "left"  ]] && pos[0]="right";;
        s|S) ch_speed;;
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

    local x=${xpt[0]} y=${ypt[0]}
    (( ((x>=$((Lines-1)))) || ((x<=1)) || ((y>=Cols)) || ((y<=1)) )) && return 1; #撞墙

    for (( i = $((${#snake}-1)); i > 0; i-- )); do
        (( ${xpt[0]} == ${xpt[$i]} && ${ypt[0]} == ${ypt[$i]} )) && return 1; #crashed
    done

    hit_obstacle ${xpt[0]} ${ypt[0]} && return 1; #撞障碍

    echo -ne "\033[${xpt[0]};${ypt[0]}H\033[32m${snake[@]:0:1}\033[0m";
    return 0;
}

# 颜色图例(与现有 UI 区分):
#   边框 蓝 *   蛇 绿 0   普通食物 白色数字
#   障碍 红 #   限时高分食物 亮品红 $   减速食物 亮青 %
is_free() {                                 #坐标(x行 y列)是否空闲
    local x=$1 y=$2 i
    (( x<2 || x>Lines-2 || y<2 || y>Cols-1 )) && return 1   #在边框上/外
    for (( i = 0; i < ${#xpt[@]}; i++ )); do                #蛇身
        (( x==${xpt[$i]} && y==${ypt[$i]} )) && return 1
    done
    for (( i = 0; i < ${#obs_x[@]}; i++ )); do              #障碍
        (( x==${obs_x[$i]} && y==${obs_y[$i]} )) && return 1
    done
    (( liveflag==0 && x==xrand && y==yrand )) && return 1   #普通食物
    (( hflag==1 && x==hx && y==hy )) && return 1            #高分食物
    (( sflag==1 && x==sx && y==sy )) && return 1            #减速食物
    return 0
}

rand_pos() {                                #取一个空闲随机点 -> rx ry
    local try=0
    while (( try < 200 )); do
        rx=$((RANDOM%(Lines-3)+2));
        ry=$((RANDOM%(Cols-2)+2));
        is_free $rx $ry && return 0
        ((try++))
    done
    return 1
}

gen_obstacles() {                           #生成不可穿越的障碍
    obs_x=(); obs_y=();
    local i
    for (( i = 0; i < obs_num; i++ )); do
        if rand_pos; then
            obs_x+=($rx); obs_y+=($ry);
            echo -ne "\033[$rx;${ry}H\033[1;31m#\033[0m";
        fi
    done
}

hit_obstacle() {                            #撞到障碍返回0(命中) 否则1
    local x=$1 y=$2 i
    for (( i = 0; i < ${#obs_x[@]}; i++ )); do
        (( x==${obs_x[$i]} && y==${obs_y[$i]} )) && return 0
    done
    return 1
}

upd_special() {                             #限时高分食物倒计时 + 概率生成特殊食物
    if (( hflag==1 )); then                 #高分食物到期则消失
        ((htimer--));
        (( htimer<=0 )) && { echo -ne "\033[$hx;${hy}H "; hflag=0; }
    fi
    if (( hflag==0 && RANDOM%100<3 )); then  #3% 生成限时高分食物
        if rand_pos; then
            hx=$rx; hy=$ry; hflag=1;
            hscore=$((RANDOM%11+15));        #高分 15-25
            htimer=$((RANDOM%20+30));        #存活 30-49 帧
            echo -ne "\033[$hx;${hy}H\033[1;35m\$\033[0m";
        fi
    fi
    if (( sflag==0 && RANDOM%100<2 )); then  #2% 生成减速食物
        if rand_pos; then
            sx=$rx; sy=$ry; sflag=1;
            echo -ne "\033[$sx;${sy}H\033[1;36m%\033[0m";
        fi
    fi
}

mk_random() {                               #产生随机点和随机数(避开蛇身/边框/障碍/其它食物)
    if rand_pos; then
        xrand=$rx; yrand=$ry;
        foodscore=$((RANDOM%9+1));
        echo -ne "\033[$xrand;${yrand}H\033[37m$foodscore\033[0m";
    fi
    liveflag=0;
}

new_game() {                                #重新开始新游戏
    snake_init;
    while ! [ -f $EXITFLAG ]; do
        #read -t ${speed[$spk]} -n 1 key;
        key="$(readkey)"
        if [[ -z "$key" ]]; then
            sleep ${speed[$spk]};
        else
            Gooooo;
        fi

        ((liveflag==0)) || mk_random;
        upd_special;
        if (( sumnode > 0 )); then
            ((sumnode--));
            add_node; (($?==0)) || return 1;
        else
            update 0; 
            echo -ne "\033[${xpt[0]};${ypt[0]}H\033[32m${snake[@]:0:1}\033[0m";

            for (( i = $((${#snake}-1)); i > 0; i-- )); do
                update $i;
                echo -ne "\033[${xpt[$i]};${ypt[$i]}H\033[32m${snake[@]:$i:1}\033[0m";

                (( ${xpt[0]} == ${xpt[$i]} && ${ypt[0]} == ${ypt[$i]} )) && return 1; #crashed
                [[ ${pos[$((i-1))]} = ${pos[$i]} ]] || pos[$i]=${pos[$((i-1))]};
            done
        fi

        local x=${xpt[0]} y=${ypt[0]}
        (( ((x>=$((Lines-1)))) || ((x<=1)) || ((y>=Cols)) || ((y<=1)) )) && return 1; #撞墙
        hit_obstacle $x $y && return 1; #撞障碍

        (( x==xrand && y==yrand )) && ((liveflag=1)) && ((sumnode+=foodscore)) && ((sumscore+=foodscore));

        if (( hflag==1 && x==hx && y==hy )); then     #吃到限时高分食物: 加高分
            ((sumscore+=hscore)); ((sumnode+=3)); hflag=0; ch_speed 0;
        fi
        if (( sflag==1 && x==sx && y==sy )); then      #吃到减速食物: 降速并刷新速度提示
            (( spk<2 )) && ((spk++)); ((sumscore+=2)); ((sumnode+=1)); sflag=0; ch_speed 0;
        fi

        echo -ne "\033[$xscore;$((yscore-2))H$sumscore";
    done
}

print_good_game() {
    local x=$((xcent-4)) y=$((ycent-25))
    for (( i = 0; i < 8; i++ )); do
        echo -ne "\033[$((x+i));${y}H\033[45m${good_game[$i]}\033[0m";
    done
    echo -ne "\033[$((x+3));$((ycent+1))H\033[45m${sumscore}\033[0m";
}

print_game_start() {
    snake_init;

    local x=$((xcent-5)) y=$((ycent-25))
    for (( i = 0; i < 10; i++ )); do
        echo -ne "\033[$((x+i));${y}H\033[45m${game_start[$i]}\033[0m";
    done

    while ! [ -f $EXITFLAG ]; do
        anykey="$(readkey)"
        [[ ${anykey:-enter} = enter ]] && break;
        [[ ${anykey:-enter} = q ]] && snake_exit;
        [[ ${anykey:-enter} = s ]] && ch_speed;
        sleep 0.05;
    done
    
    while ! [ -f $EXITFLAG ]; do
        new_game;
        print_good_game;
        while ! [ -f $EXITFLAG ]; do
            anykey="$(readkey)"
            [[ $anykey = n ]] && break;
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
