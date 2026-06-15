#!/usr/bin/env bash
# filename: tetris.sh
#
# Author: LKJ
# Date: 2013.5.14
# Email: liungkejin@gmail.com
#

EXITFLAG="/tmp/tetris_exit.flag"
WRITEFILE="/tmp/tetris_pipe.in"
READFILE="/tmp/tetris_pipe.out"

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


# const value
#======================================固定值================================#
BXLINES=3;  BXCOLNS=6;  # 小方块的高和宽
MAPX=20;    MAPY=10;
NAME=('I' 'S' 'Z' 'L' 'J' 'T' 'O');
FLAG=('2' '2' '2' '4' '4' '4' '1');

#declare -A mapflag mapname;
#mapflag=([I]=2 [S]=2 [Z]=2 [L]=4 [J]=4 [T]=4 [O]=1);
#mapname=([I]=1 [S]=2 [Z]=3 [L]=4 [J]=5 [T]=6 [O]=7);
mapflag() {
    case "$1" in
        I) echo 2;;
        S) echo 2;;
        Z) echo 2;;
        L) echo 4;;
        J) echo 4;;
        T) echo 4;;
        O) echo 1;;
        *) echo 2;;
    esac
}
mapname() {
    case "$1" in
        I) echo 1;;
        S) echo 2;;
        Z) echo 3;;
        L) echo 4;;
        J) echo 5;;
        T) echo 6;;
        O) echo 7;;
        *) echo 1;;
    esac
}

colorone=(31 32 33 34 35 36 37);
colortwo=(31 32 33 34 35 36 37);

Iax=( 0 0 0 0); Iay=(-1 0 1 2);
Ibx=(-1 0 1 2); Iby=( 0 0 0 0);

Sax=( 1 1 0 0); Say=(-1 0 0 1);
Sbx=(-1 0 0 1); Sby=( 0 0 1 1);

Zax=( 0 0 1 1); Zay=(-1 0 0 1);
Zbx=(-1 0 0 1); Zby=( 1 1 0 0);

Lax=(-1 0 1 1); Lay=( 0 0 0 -1);
Lbx=(-1 0 0 0); Lby=(-1 -1 0 1);
Lcx=(-1 -1 0 1);Lcy=( 1 0 0 0);
Ldx=( 0 0 0 1); Ldy=(-1 0 1 1);

Jax=(-1 0 1 1); Jay=( 0 0 0 1);
Jbx=( 1 0 0 0); Jby=(-1 -1 0 1);
Jcx=(-1 -1 0 1);Jcy=(-1 0 0 0);
Jdx=( 0 0 0 -1);Jdy=(-1 0 1 1);

Tax=(0 0 0 -1); Tay=(-1 0 1 0);
Tbx=(-1 0 1 0); Tby=( 0 0 0 1);
Tcx=( 0 0 0 1); Tcy=(-1 0 1 0);
Tdx=(-1 0 1 0); Tdy=(0 0 0 -1);

Oax=( 0 0 1 1); Oay=( 0 1 0 1);

good_game=(
    '                                                 '
    '                G A M E  O V E R !               '
    '                                                 '
    '                   Score:                        '
    '                                                 '
    '          press   Q   to quit                    '
    '          press   N   to start a new game        '
    '          press   S   to change the level        '
    '          press   R   to replay your game        '
    '                                                 '
);

start_game=(
    '                                                 '
    '               ~~~ T E T R I S ~~~               '
    '                                                 '
    '                  Author:  LKJ                   '
    '                                                 '
    '          press   S   to change the level        '
    '                                                 '
    '             C H O O S E  L E V E L:             '
    '                        1                        '
    '                                                 '
    '         Press <Enter> to start the game         '
    '                                                 '
);

blockarr=(); #记录name 和 flag
keyarray=(); #记录按键

# hold / next-queue state
held_name="";   held_flag=2;    # 暂存方块(为空表示还没暂存过)
can_hold=1;                     # 当前下落方块本轮是否还能 hold(每次只能一次)
prebuf_name=(); prebuf_flag=(); # next 预览队列(已弹出 nname 之后剩下的两个)
REPLAYING=0;    rep_base=0;     # 回放标记 与 当前 blockarr 基址(回放时预览/恢复用)
#------------------------------------------------------------------------#

#========================================================================#
game_init() { # game_init
    SCLINES=`tput lines`;       # 屏幕的高
    SCCOLNS=`tput cols`;        # 屏幕的宽

#主框的属性
    mainw=59;               mainh=60;                   # 主框的宽和高
    mainctx=0;              maincty=4;                  # 主框中心打印点
    upx=1;                  dnx=$((SCLINES-1));         # 界面的上下 x
    lty=$((SCCOLNS/2-50));  rty=$((lty+61));            # 界面的左右 y
    ((lty<=0)) && lty=1;

#next的属性
    nextw=40;           nexth=16;                 # next框的高和宽
    ntx=$((upx));       nty=$((rty+2));           # next框的位置
    ntctx=$((ntx+5));   ntcty=$((nty+12));        # next框的中心打印位置

#score的属性
    scorw=$nextw;       scorh=5;
    scx=$((ntx+20));    scy=$((nty));
    scctx=$((scx+4));   sccty=$((scy+19));

#level的属性
    levew=$nextw;       leveh=5;
    lvx=$((scx+9));     lvy=$((scy));
    lvctx=$((lvx+4));   lvcty=$((lvy+20));

#help的属性
    helpw=$nextw;       helph=21;
    hpx=$((lvx+10));    hpy=$((nty));
    hpctx=$((hpx+4));   hpcty=$((hpy+10));

#map
MAP=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
     0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
     0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
     0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
     0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
    ); #所有的格子

#paint_gui
    clear; paint_gui;

    local x=$((RANDOM%7));
    name=${NAME[$((x))]};  
    flag=$((RANDOM%FLAG[$x]+1)); 

    seed_queue;                              #预生成 next 预览队列
    held_name=""; held_flag=2; can_hold=1;   #hold 初始为空

    centerx=$mainctx; #每个图形的中心打印点
    centery=$maincty;

#各个方块的相对坐标
    ax="Iax"; ay="Iay";
}
#------------------------------------------------------------------------#

game_exit() {
    touch $EXITFLAG;
    wait # 等待进程退出

    tput rmcup;
    tput cvvis;
    stty echo &> /dev/null;
    
    (($#==1)) && echo "window is too small";
    exit 0;
}

#============================三个原子函数paint_block, erase_block, paint_box=================
#打印一个小方块, 四个参数， 两个位置和两个颜色
paint_block() {
    local x=$1 y=$2 crone=$3 crtwo=$4 i

    x=$((upx+x*BXLINES+1));
    y=$((lty+y*BXCOLNS+1));

    echo -ne "\033[$((x));$((y))H\033[${crone}m+---+\033[0m";
    echo -ne "\033[$((x+1));$((y))H\033[${crone}m|\033[${crtwo}m###\033[0m\033[${crone}m|\033[0m";
    echo -ne "\033[$((x+2));$((y))H\033[${crone}m+---+\033[0m";
}

#删除一个小方块, 两个参数，即位置
erase_block() {
    local x=$1 y=$2

    x=$((upx+x*BXLINES+1));
    y=$((lty+y*BXCOLNS+1));

    echo -ne "\033[$(( x ));$((y))H     ";
    echo -ne "\033[$((x+1));$((y))H     ";
    echo -ne "\033[$((x+2));$((y))H     ";
}

#画一个盒子$1 $2 $3 $4 $5
paint_box() {
    local x=$1 y=$2 w=$3 h=$4 color=$5 i

    echo -ne "\033[$x;$((y))H\033[${color}m+\033[0m";
    echo -ne "\033[$x;$((y+w+1))H\033[${color}m+\033[0m";
    for (( i = 1; i <= w; i++ )); do
        echo -ne "\033[$x;$((y+i))H\033[${color}m-\033[0m";
        echo -ne "\033[$((x+h+1));$((y+i))H\033[${color}m-\033[0m";
    done
    echo -ne "\033[$((x+h+1));$((y))H\033[${color}m+\033[0m";
    echo -ne "\033[$((x+h+1));$((y+w+1))H\033[${color}m+\033[0m";

    for (( i = 1; i <= h; i++ )); do
        echo -ne "\033[$((x+i));$((y))H\033[${color}mI\033[0m";
        echo -ne "\033[$((x+i));$((y+w+1))H\033[${color}mI\033[0m";
    done
}

#-----------------迷你方块: 用于 hold 框 和 next 预览队列------------------#
# 用空格清空一个矩形区域(避免覆盖到边框) $1 起始行 $2 起始列 $3 宽 $4 高
clear_region() {
    local r=$1 c=$2 w=$3 h=$4 i
    for (( i = 0; i < h; i++ )); do
        printf "\033[%d;%dH%*s" $((r+i)) $c $w ""
    done
}

# 画一个迷你格子(两个字符宽) $1 行 $2 列 $3 颜色下标
paint_mini_cell() {
    echo -ne "\033[$1;$2H\033[${colortwo[$3]}m##\033[0m";
}

# 画一个迷你方块图形 $1 name $2 flag $3 基准行 $4 基准列
paint_mini_piece() {
    local pn=$1 pf=$2 br=$3 bc=$4 suf i n axn ayn
    [ -z "$pn" ] && return;
    case $pf in 1) suf=a;; 2) suf=b;; 3) suf=c;; 4) suf=d;; *) suf=a;; esac
    n=$(( $(mapname "$pn") - 1 ));
    axn="${pn}${suf}x"; ayn="${pn}${suf}y";
    for (( i = 0; i < 4; i++ )); do
        paint_mini_cell $(( br + ${axn}[$i] )) $(( bc + 2*(${ayn}[$i]) )) $n;
    done
}
#---------------------------------------------------------------------------------------

#打印界面
paint_gui() {
    # ((upx<=0 || lty<=0)) && game_exit 1;

    paint_box $upx $lty $mainw $mainh 34; #画主框
    paint_box 1 $nty $nextw 4  33;        #画hold框 (1~6 行)
    paint_box 7 $nty $nextw 12 33;        #画next框 (7~20 行, 3格预览)
    paint_box $lvx $lvy $levew $leveh 32; #画level框
    paint_box $scx $scy $scorw $scorh 36; #画分数框
    paint_box $hpx $hpy $helpw $helph 31; #画帮助框

#打印score, help 等提示字符
    echo -ne "\033[1;$((nty+17))H\033[34mH O L D\033[0m";
    echo -ne "\033[7;$((nty+17))H\033[34mN E X T\033[0m";

    echo -ne "\033[$((scx+2));$((scy+16))H\033[31mS C O R E\033[0m";
    echo -ne "\033[$((scx+4));$((scy+20))H\033[31m0\033[0m";

    echo -ne "\033[$((lvx+2));$((lvy+16))H\033[31mL E V E L\033[0m";
    echo -ne "\033[$((lvctx));$((lvcty))H\033[31m1\033[0m";

    echo -ne "\033[$((hpx+2));$((hpy+17))H\033[33mH E L P\033[0m";
    echo -ne "\033[$((hpctx));$((hpcty))H\033[34mH --- Move Left\033[0m";
    echo -ne "\033[$((hpctx+2));$((hpcty))H\033[34mL --- Move Right\033[0m";
    echo -ne "\033[$((hpctx+4));$((hpcty))H\033[34mJ --- Soft Drop\033[0m";
    echo -ne "\033[$((hpctx+6));$((hpcty))H\033[34mK --- Rotate\033[0m";
    echo -ne "\033[$((hpctx+8));$((hpcty))H\033[34mSpace or Enter --- Hard Drop\033[0m";
    echo -ne "\033[$((hpctx+10));$((hpcty))H\033[34mC --- Hold Piece\033[0m";

    echo -ne "\033[$((hpctx+11));$((hpcty))H\033[34mP --- Pause Game\033[0m";
    echo -ne "\033[$((hpctx+13));$((hpcty))H\033[34mQ --- Quit Game\033[0m";
    echo -ne "\033[$((hpctx+15));$((hpcty))H\033[34mE --- Exit Replay\033[0m";
}

#---------------------------------------------------------

#在 hold 框 和 next 框中打印 hold 方块与接下来 3 个方块
paint_next() {
    (($#==0)) && advance_next;   # 实时: 弹出队首为 nname/nflag(回放传 -n, nname/nflag 已由 blockarr 设好)

    # hold 框
    clear_region 2 $((nty+1)) 18 4;
    paint_mini_piece "$held_name" "$held_flag" 3 $((nty+8));

    # next 框: 三个预览方块
    clear_region 8 $((nty+1)) 18 12;
    paint_mini_piece "$nname" "$nflag" 9 $((nty+8));

    local s2n s2f s3n s3f
    if ((REPLAYING==1)); then          # 回放: 更深的两格从 blockarr 推算(后续将出现的方块)
        s2n=${blockarr[rep_base+6]};  s2f=${blockarr[rep_base+7]};
        s3n=${blockarr[rep_base+10]}; s3f=${blockarr[rep_base+11]};
    else                                # 实时: 直接读预览队列
        s2n=${prebuf_name[0]}; s2f=${prebuf_flag[0]};
        s3n=${prebuf_name[1]}; s3f=${prebuf_flag[1]};
    fi
    paint_mini_piece "$s2n" "$s2f" 13 $((nty+8));
    paint_mini_piece "$s3n" "$s3f" 17 $((nty+8));

    centerx=$mainctx; centery=$maincty;   # 保留: 供随后的 check_first 在出生点画方块
}

# 打印分数和level
paint_score() {
    level=0;
    echo -ne "\033[$((scctx));$((sccty))H\033[31m$score\033[0m";
    ((score>2000 )) && ((level=1)); ((score>5000 )) && ((level=2));
    ((score>9000 )) && ((level=3)); ((score>14000)) && ((level=4));
    ((score>20000)) && ((level=5)); ((score>27000)) && ((level=6));
    ((score>35000)) && ((level=7)); ((score>44000)) && ((level=8));
    ((level=olevel+level)); 
    ((level>9)) && ((level=9));

    ((TIME=10-level));
    echo -ne "\033[$((lvctx));$((lvcty))H\033[31m$level\033[0m";
}

#根据name选择要打印的方块
paint_x() {
    local x=$centerx y=$centery
    local i=$(mapname $name)
    local n=$((i-1));

    find_array;
    for (( i = 0; i < 4; i++ )); do
        paint_block $((x+${ax}[$i])) $((y+${ay}[$i])) ${colorone[$n]} ${colortwo[$n]}
    done
}

#根据name选择要删除的方块
erase_x() {
    local x=$centerx y=$centery i

    find_array;
    for (( i = 0; i < 4; i++ )); do
        erase_block $((x+${ax}[$i])) $((y+${ay}[$i]));
    done
}

rotate_x() {
    ((flag+=1));
    local mflag=$(mapflag $name);
    ((flag>mflag)) && flag=1;
}
#------------------------------------------------------------------------#

#========================================================================#
update() { #update the map
    local x=$1 n=0 i j
    for (( i = 0; i < MAPY; i++ )); do
        erase_block $x $i;              #消掉一行
        MAP[$((x*MAPY+i))]=0;           #更新为0
    done

    #将上面的格子向下移动一行
    for (( i = 0; i < MAPY; i++ )); do
        for (( j = x; j > 0; j-- )); do
            ((n=MAP[$(((j-1)*MAPY+i))])); 
            if ((n!=0)); then
                erase_block $((j-1)) $i;
                paint_block $j $i ${colorone[$((n-1))]} ${colortwo[$((n-1))]};
            fi
        done
    done

    # 更新MAP的值
    for (( i = 0; i < MAPY; i++ )); do
        for (( j = x; j >0; j-- )); do
            MAP[$((j*MAPY+i))]=$((MAP[$(((j-1)*MAPY+i))]));
        done
    done
}

# 检测是否可以消掉一行
have_score() {
    local n=0 i j;
    for (( i = 0; i < MAPX; i++ )); do
        for (( j = 0; j < MAPY; j++ )); do
            ((MAP[$((10*i+j))]==0)) && break; #有空格就退出
        done
        ((j==MAPY)) && ((n+=1)) && update $i;    #可以消掉一行
    done

    case $n in
        1) ((score+=100)); ;;
        2) ((score+=200)); ;;
        3) ((score+=400)); ;;
        4) ((score+=800)); ;;
    esac
}

#根据flag 和 name找到其的坐标数组
find_array() {
    case $flag in
        1) ax="${name}ax"; ay="${name}ay";
            ;;
        2) ax="${name}bx"; ay="${name}by";
            ;;
        3) ax="${name}cx"; ay="${name}cy";
            ;;
        4) ax="${name}dx"; ay="${name}dy";
            ;;
    esac
}

# 检测方块首次出现时,是否会越界,并作出矫正或者游戏结束
check_first() { 
    local x=$centerx y=$centery minx=0 i

    find_array;
# 检测是否越界
    for (( i = 0; i < 4; i++ )); do
        (((x+${ax}[$i])<minx)) && ((minx=(x+${ax}[$i])));
    done
    ((centerx-=minx));
    paint_x;  #开始打印方块
    paint_score;

# 检测是否会结束游戏
    for (( i = 0; i < 4; i++ )); do
        ((x=centerx+${ax}[$i])); ((y=centery+${ay}[$i]))
        ((MAP[$((x*10+y))]!=0)) && return 1; #游戏结束
    done
 
    return 0;
}

#检测是否可以固定方块
check_stop() {
    local sx=$centerx sy=$centery
    local x=0 y=0 n=0 i=0
   
    find_array;
    for (( i = 0; i < 4; i++ )); do
        ((x=(sx+${ax}[$i]))); ((y=(sy+${ay}[$i])));
        ((x+1>19)) && break; #到底
        ((MAP[$((10*(x+1)+y))] != 0)) && break; #有方块挡住
    done
    
    if ((i!=4)); then #不能在动了，则记录
        for (( i = 0; i < 4; i++ )); do
            ((x=(sx+${ax}[$i]))); ((y=(sy+${ay}[$i])));
            n=$((10*x+y)); MAP[$n]=$(mapname $name);
        done
        have_score;

        return 1;
    fi
 
    return 0;
}

#检测是否可以移到$1 $2这个格子
check_next() {
    local sx=$1 sy=$2 
    local x=0 y=0 n=0 i=0
    
    find_array;
    for (( i = 0; i < 4; i++ )); do
        ((x=(sx+${ax}[$i]))); ((y=(sy+${ay}[$i])));

        ((x<0 || x>19 || y<0 || y>9)) && return 1; 
        ((MAP[$((10*x+y))] != 0)) && return 1; #不能移到这个格子
    done

    return 0;
}
#------------------------------------------------------------------------#

#========================================================================#
go_left() { #向左移一个
    check_next $centerx $((centery-1));
    (($?==1)) && return 1;

    erase_x; ((centery-=1));
    return 0;
}
    
go_right() { #向右移一格
    check_next $centerx $((centery+1));
    (($?==1)) && return 1;

    erase_x; ((centery+=1));
    return 0;
}

go_down() { #加速向下
    check_next $((centerx+1)) $centery
    (($?==1)) && return 1;

    erase_x; ((centerx+=1));
    return 0;
}

go_rotate() { #旋转
    local oflag=$flag #保存原来的flag值

    rotate_x;
    check_next $centerx $centery;
    (($?==1)) && ((flag=oflag)) && return 1;

    flag=$oflag;
    erase_x; rotate_x;

    return 0;
}

go_fast() { #快速固定
    erase_x;
    check_next $((centerx+1)) $centery
    local res=$?;

    while ((res==0)); do
        ((centerx+=1));
        check_next $((centerx+1)) $centery
        res=$?;
    done
}

game_pause() {
    echo -ne "\033[$((hpctx+17));$((hpcty+5))H\033[31mGame Paused\033[0m";
    local pkey;
    while ! [ -f $EXITFLAG ]; do
        pkey="$(readkey)"
        [[ $pkey = 'q' ]] || [[ $pkey == 'Q' ]] && game_exit;
        [[ $pkey = 'p' ]] || [[ $pkey == 'P' ]] && break;
        sleep 0.1
    done
    echo -ne "\033[$((hpctx+17));$((hpcty+5))H\033[31m           \033[0m";
}

# hold: 暂存当前方块, 每个下落方块只能 hold 一次
do_hold() {
    ((can_hold==0)) && return;        # 本轮已经 hold 过
    erase_x;                          # 先擦掉当前正在下落的方块

    if [ -z "$held_name" ]; then      # 暂存区为空: 存入当前方块, 取下一个方块顶上
        held_name=$name; held_flag=$flag;
        name=$nname;     flag=$nflag;
        if ((REPLAYING==1)); then     # 回放: 新的下一个 = 下一轮记录的当前方块
            local rn=${blockarr[rep_base+4]} rf=${blockarr[rep_base+5]};
            [ -n "$rn" ] && { nname=$rn; nflag=$rf; };
        else                          # 实时: 从队列再弹一个作为新的下一个
            advance_next;
        fi
    else                              # 暂存区非空: 与当前方块交换(不消耗队列)
        local tn=$name tf=$flag;
        name=$held_name; flag=$held_flag;
        held_name=$tn;   held_flag=$tf;
    fi

    centerx=$mainctx; centery=$maincty;   # 回到出生点
    can_hold=0;                            # 本轮不能再 hold
    paint_next -n;                         # 刷新 hold 框 与 next 队列(不要再弹队列)
    check_first; (($?==1)) && gmover=1;    # 在出生点重画并检测是否顶到顶部(游戏结束)
}

# 根据按键作出选择
keypress() {
    local result=0;
    case ${key:-space} in
        H|h) go_left;   result=$?; # 向左一个格子
            ;;
        J|j) go_down;   result=$?; # 向下, 加速向下一个格子
            ;;
        K|k) go_rotate; result=$?; # 向上, 旋转90度
            ;;
        L|l) go_right;  result=$?; # 向右一个格子
            ;;
        C|c) do_hold; # 暂存当前方块
            ;;
        Q|q) game_exit; # 退出游戏
            ;;
        P|p) game_pause;
            ;;
        space)  
            go_fast;    nextbk=1;
            ;;
    esac
    ((result==0)) && paint_x;
}
#----------------------------------------------------------------#

#================================================================#
mk_random() { # 产生下一个随机方块
    local x=$((RANDOM%7))

    nname=${NAME[$x]};
    nflag=$((RANDOM%FLAG[$x]+1));
}

# 向预览队列尾部补一个随机方块
push_random() {
    local x=$((RANDOM%7));
    prebuf_name+=("${NAME[$x]}");
    prebuf_flag+=("$((RANDOM%FLAG[$x]+1))");
}

# 初始化预览队列(开新局/回放开始时调用)
seed_queue() {
    prebuf_name=(); prebuf_flag=();
    local i;
    for (( i = 0; i < 3; i++ )); do push_random; done
}

# 弹出队首作为下一个方块(nname/nflag), 再把队列补足到 2 个(供更深的两格预览)
advance_next() {
    nname=${prebuf_name[0]}; nflag=${prebuf_flag[0]};
    prebuf_name=("${prebuf_name[@]:1}"); prebuf_flag=("${prebuf_flag[@]:1}");
    while (( ${#prebuf_name[@]} < 2 )); do push_random; done
}

#开始一个新游戏
new_game() {
    local i nextbk=0;
    REPLAYING=0; gmover=0;

    game_init; #初始化游戏
    while ! [ -f $EXITFLAG ]; do
        paint_next; #刷新 hold 与 next 预览(并弹出队首为当前的下一个)
        blockarr+=($name $flag $nname $nflag);

        check_first; (($?==1)) && return; #检查是否游戏结束
        can_hold=1;                       #新方块出生, 本轮允许 hold 一次

        while ! [ -f $EXITFLAG ]; do
            for (( i = 0; i < TIME; i++ )); do
                key="$(readkey)"
                if ! [ -z "$key" ]; then
                    keypress;
                    keyarray+=(${key:-space});
                else
                    keyarray+=("NUL");
                fi

                ((gmover==1)) && break;    #hold 顶到顶部, 游戏结束
                ((nextbk==1)) && !((nextbk=0)) && break;

                sleep 0.05
            done

            ((gmover==1)) && break;
            check_stop; (($?==1)) && break;
            erase_x; ((centerx+=1)); paint_x;
        done

        ((gmover==1)) && return;
        name=$nname; flag=$nflag;
        ((score+=10));
    done
}

replay() {
    score=0; level=$olevel;
    local nextbk=0 i=0 j=0;
    local blocklen=$((${#blockarr[@]})) keylen=${#keyarray[@]};
    REPLAYING=1; gmover=0;

    game_init;
    for ((i=0; i<blocklen; i+=4)); do
        name=${blockarr[i]}; flag=${blockarr[i+1]};
        nname=${blockarr[i+2]}; nflag=${blockarr[i+3]};
        rep_base=$i;                       #供 paint_next/do_hold 推算预览与 hold 取块

        paint_next -n;
        check_first; (($?==1)) && { REPLAYING=0; return 0; };
        can_hold=1;                        #新方块出生, 本轮允许 hold 一次

        while ! [ -f $EXITFLAG ]; do
            local k=0 anykey;
            while ! [ -f $EXITFLAG ]; do
                key=${keyarray[j++]}; [[ $key = [pP] ]] && continue;
                keypress;
                #((j+=1));
                anykey="$(readkey)"
                if ! [ -z "$anykey" ]; then
                    [[ $anykey = [pP] ]] && game_pause;
                    [[ $anykey = [qQ] ]] && game_exit;
                    [[ $anykey = [eE] ]] && { level=1; REPLAYING=0; return 0; };
                fi

                ((gmover==1)) && break;     #hold 顶到顶部, 游戏结束
                ((nextbk==1)) && !((nextbk=0)) && break;
                ((k+=1)) && ((k==TIME)) && break;

                [[ -z "$key" ]] && sleep 0.05
            done

            ((gmover==1)) && break;
            check_stop; (($?==1)) && break;
            erase_x; ((centerx+=1)); paint_x;
        done
        ((gmover==1)) && { REPLAYING=0; return 0; };
        ((score+=10));
    done

    REPLAYING=0;
    score=0; level=1;
    return 0;
}

paint_game_over() {
    local xcent=$((`tput lines`/2)) ycent=$((`tput cols`/2))
    local x=$((xcent-4)) y=$((ycent-25))
    for (( i = 0; i < 10; i++ )); do
        echo -ne "\033[$((x+i));${y}H\033[44m${good_game[$i]}\033[0m";
    done
    echo -ne "\033[$((x+3));$((ycent+1))H\033[44m${score}\033[0m";
}

game_over() {
    paint_game_over;

    level=1; local pkey;
    while ! [ -f $EXITFLAG ]; do
        pkey="$(readkey)"
        [[ $pkey = 'q' ]] || [[ $pkey = 'Q' ]] && game_exit;
        [[ $pkey = 'n' ]] || [[ $pkey = 'N' ]] && break;
        [[ $pkey = 's' ]] || [[ $pkey = 'S' ]] && ((level=level%9+1));
        [[ $pkey = 'r' ]] || [[ $pkey = 'R' ]] && replay && paint_game_over;
        echo -ne "\033[$((lvctx));$((lvcty))H\033[31m$level\033[0m";
    done
    olevel=$level;
    blockarr=();
    keyarray=();
}

game_start() {
    score=0; #总分数
    level=1; #等级
    TIME=9;

    local xcent=$(tput lines) ycent=$(tput cols)
    local n=$((xcent/BXLINES)) m=$((ycent/BXCOLNS)) i j;
    for (( i = 3; i < n-2; i++ )); do
        for (( j = 3; j < m-3; ++j)); do
            paint_block $i $j $((RANDOM%7+31)) $((RANDOM%7+31))
        done
    done

    local x=$((xcent/2-4)) y=$((ycent/2-25))
    for (( i = 0; i < 12; i++ )); do
        echo -ne "\033[$((x+i));${y}H\033[40m${start_game[$i]}\033[0m";
    done

    local pkey='x';
    while ! [ -f $EXITFLAG ]; do
        pkey="$(readkey)"
        [[ ${pkey} = 'enter' ]] && break;
        [[ $pkey = 'b' ]] || [[ $pkey = 'B' ]] && break;
        [[ $pkey = 'q' ]] || [[ $pkey = 'Q' ]] && game_exit;
        [[ $pkey = 's' ]] || [[ $pkey = 'S' ]] && ((level=level%9+1));
        echo -ne "\033[$((x+8));$((ycent/2-1))H\033[40m$level\033[0m";
        sleep 0.1
    done
    olevel=$level;
}

#----------------------------------------------------------------------#

tput civis; stty -echo &> /dev/null;
tput smcup; clear;

[ -f $EXITFLAG ] && rm $EXITFLAG
[ -f $WRITEFILE ] && rm $WRITEFILE
[ -f $READFILE ] && rm $READFILE

trap 'game_exit;' SIGINT SIGTERM

{
    game_start;
    while ! [ -f $EXITFLAG ]; do
        new_game;
        game_over;
    done
} &

IFS=""
while read -n 1 gkey; do
    [ "$gkey" = ' ' ] && gkey="space"
    echo "${gkey:-enter}" >> $WRITEFILE
    [[ "$gkey" = 'q' ]] || [[ "$gkey" = 'Q' ]] && break
done

game_exit