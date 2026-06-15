Bash-Games
===========
Linux终端下的小游戏，和小东西，包括 俄罗斯方块，贪吃蛇，屏保时钟，翻译脚本。。。


所有的方向按键都是按照 vim ‘hjkl’ 来的！


> 代码可以随意用~


启动菜单 (games.sh)
===================
运行 `bash games.sh` 进入一个终端菜单, 可选择启动 俄罗斯方块(Tetris)、贪吃蛇(Snake)、数字时钟(aclock.sh) 或退出。
菜单会读取当前终端尺寸自动居中, 显示游戏说明和按键提示, 并在启动 tetris.sh / snake.sh 后正确恢复终端状态。
games.sh 不依赖任何外部 GUI 工具, 仅使用 bash 与终端转义 (tput / ANSI)。
选择不存在或不可执行的脚本时, 会给出清晰的错误提示。

    bash games.sh                 # 进入启动菜单
    # 或赋予执行权限后直接运行:
    chmod +x games.sh && ./games.sh

当然, 你仍然可以像以前一样直接运行各个脚本 (这些方式保持不变):

    ./tetris.sh                   # 直接玩俄罗斯方块
    ./snake.sh                    # 直接玩贪吃蛇
    ./aclock.sh                   # 直接显示数字时钟


俄罗斯方块 (Tetris)
===================
看起来是不是很棒 :D, 有 0 - 9 级， 最后结束了，还能支持游戏回放功能哦。。。


<img src="https://raw.githubusercontent.com/liungkejin/Bash-Games/master/images/tetris1.png" width="600">
<img src="https://raw.githubusercontent.com/liungkejin/Bash-Games/master/images/tetris2.png" width="600">
<img src="https://raw.githubusercontent.com/liungkejin/Bash-Games/master/images/tetris3.png" width="600">
<img src="https://raw.githubusercontent.com/liungkejin/Bash-Games/master/images/tetris4.png" width="600">


数字时钟 (Clock)
================
ClockSaver.sh 利用了 logkeys这个工具(需要root权限), 所以可以达到屏保的目的，无操作时显示数字时钟

aclock.sh 则不需要root 权限, 因为他就仅仅用来显示数字时钟


<img src="https://raw.githubusercontent.com/liungkejin/Bash-Games/master/images/clock1.png" width="600">
<img src="https://raw.githubusercontent.com/liungkejin/Bash-Games/master/images/clock2.png" width="600">


贪吃蛇 (Snake)
=================
这个贪吃蛇不怎么好看。。。


<img src="https://raw.githubusercontent.com/liungkejin/Bash-Games/master/images/snake1.png" width="600">
<img src="https://raw.githubusercontent.com/liungkejin/Bash-Games/master/images/snake2.png" width="600">


终端翻译 (Translate)
====================
这个脚本不知道还能不能用。。。如果那个网站接口没有换，应该还能用。。。。


<img src="https://raw.githubusercontent.com/liungkejin/Bash-Games/master/images/translate.png" width="600">
