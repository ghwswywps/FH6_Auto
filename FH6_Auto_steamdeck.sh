#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║     Forza Horizon 6  自动脚本  —  Steam Deck / Linux        ║
# ║     依赖: xdotool                                            ║
# ║     安装: sudo pacman -S xdotool  (桌面模式终端执行)        ║
# ║     运行: bash fh6_xdotool.sh                               ║
# ╚══════════════════════════════════════════════════════════════╝

# ==============================================================
#  ★ 用户配置区 — 参数集中于此，改后重新运行脚本生效
# ==============================================================
START_DELAY=5           # 选完功能后倒计时（秒），期间点击游戏窗口

BC_INIT_WAIT=500        # 初始等待
BC_MENU_ENTER=1200       # Enter 后等待购买菜单
BC_CONFIRM_WAIT=4600    # 等待购买确认界面
BC_PURCHASE_CFM=1000     # Y 后等待确认弹窗
BC_AFTER_BUY=19000      # 购买完成后等待进入新车界面
BC_ESC_WAIT=1000        # ESC 后等待技能菜单
BC_SKILL_ENTER=1200     # 进入技能界面等待
BC_SKILL_SETTLE=1200    # 选中技能树等待
BC_SKILL_APPLY=800     # 技能确认等待（第 1 次）
BC_SKILL_APPLY2=800    # 技能确认等待（第 2 次）
BC_ESC_FINAL=1000       # 最后 ESC 等待（第 1 次）
BC_ESC_FINAL2=1000      # 最后 ESC 等待（第 2 次）
BC_HOLD_NAV=100        # 方向键 / Esc / Y / BackSpace 按住时长
BC_HOLD_ENTER=100       # Enter 按住时长

W_HOLD_SEC=300          # W 持续按住总时长（秒）
W_PAUSE_MS=100          # 松开 W 后短暂停顿

MA_ENTER_HOLD=100       # 确认 Enter 按住时长
MA_INIT_WAIT=3000       # Enter 后等待加载进入
MA_DRIVE_MS=26500       # W 油门开车时长
MA_DRIVE_EXTRA=2000     # 继续踩油额外时间
MA_X_HOLD=100           # X 键按住时长
MA_CONFIRM_HOLD=100     # 结算确认 Enter 按住时长
MA_SETTLE_MS=7200       # 等待结算界面
MA_LOOP_TAIL=150        # 每轮结束后缓冲
POINTS_PER_LOOP=10      # 每轮 +10 熟练点（效率计算用，勿改）

# ==============================================================
#  内部变量
# ==============================================================
STOP_FLAG="/tmp/fh6_stop_$$"
_LOOP_COUNT=0
_START_TIME=0
_BC_START=0       # 买车计时起点
_CD_ROW=""        # safe_sleep 倒计时显示行（空=不显示）

# ==============================================================
#  UI 布局常量
# ==============================================================
#  行号（draw_frame 绘制后固定）
# row 0 : ══ 顶部分隔 ══
# row 1 : 标题
# row 2 : ══ 分隔 ══
# row 3-5 : 功能说明
# row 6 : 提示
# row 7 : ── 分隔 ──
# row 8-12 : 状态行（5行）
# row 13 : ── 分隔 ──
# row 14 : [ 日志 ]
# row 15-22 : 日志内容（8行）
# row 23 : ══ 底部 ══
# row 24 : 输入提示
R_ST0=8   # 状态
R_ST1=9   # 信息 / 阶段
R_ST2=10  # 进度 / 倒计时
R_ST3=11  # 时间 / 次数
R_ST4=12  # 效率
R_L0=15   # 日志起始行
R_INP=24  # 输入行
LOG_N=8

# 值域：在 "  标签  │ " (10 列) 之后
_VC=10    # 值域起始列
_VW=52    # 值域清除宽度（ASCII 字符数）
_LC=2     # 日志文本起始列

# 颜色
RC=$(tput sgr0 2>/dev/null)
GC=$(tput setaf 2 2>/dev/null)   # 绿 - 运行中 / 功能序号
YC=$(tput setaf 3 2>/dev/null)   # 黄 - 标题 / 时间 / 计数
CC=$(tput setaf 6 2>/dev/null)   # 青 - 倒计时 / 高亮信息
WC=$(tput setaf 7 2>/dev/null)   # 白 - 普通值
DC=$(tput dim    2>/dev/null)    # 暗 - 提示文字

# 日志环形缓冲
declare -a _LB=("" "" "" "" "" "" "" "")

SEP_D="══════════════════════════════════════════════════════════════"
SEP_L="──────────────────────────────────────────────────────────────"

# ==============================================================
#  框架绘制（启动时调用一次）
# ==============================================================
draw_frame() {
    tput clear
    echo -e "${YC}${SEP_D}${RC}"
    echo    "  Forza Horizon 6  自动脚本 (Steam Deck)"
    echo -e "${YC}${SEP_D}${RC}"
    echo -e "  ${GC}1)${RC} 刷超抽 (买车+加点)   在【购买与出售】页面使用"
    echo -e "  ${GC}2)${RC} 刷 CR  (W循环)       在巨汉开跑后使用"
    echo -e "  ${GC}3)${RC} 刷熟练度             在准备进蓝图的页面使用"
    echo -e "  ${DC}Ctrl+C 随时停止  |  选完后 ${START_DELAY}s 倒计时，期间点击游戏窗口${RC}"
    echo    "${SEP_L}"
    echo    "  状态  │"
    echo    "  信息  │"
    echo    "  进度  │"
    echo    "  时间  │"
    echo    "  效率  │"
    echo    "${SEP_L}"
    echo -e "  ${YC}[ 日志 ]${RC}"
    for i in 1 2 3 4 5 6 7 8; do echo ""; done
    echo -e "${YC}${SEP_D}${RC}"
    tput cup $R_INP 2
}

# ==============================================================
#  UI 更新函数
# ==============================================================

# sv row value [color]  — 设置状态行的值
sv() {
    local row=$1 val=$2 c=${3:-"$WC"}
    tput cup "$row" $_VC
    printf "%-${_VW}s" ""       # 先清空旧值
    tput cup "$row" $_VC
    echo -ne "${c}${val}${RC}"
    tput cup $R_INP 2           # 恢复光标位置
}

# 清除一行状态值
sc() { sv "$1" ""; }

# 更新买车计时器（仅 _BC_START>0 时生效）
_tick_bc() {
    [ "$_BC_START" -eq 0 ] && return
    local e=$(( $(date +%s) - _BC_START ))
    tput cup $R_ST3 $_VC
    printf "%-${_VW}s" ""
    tput cup $R_ST3 $_VC
    echo -ne "${YC}$(printf '%02d:%02d' $((e/60)) $((e%60)))${RC}"
}

# log msg — 追加日志并刷新日志区
log() {
    local msg="[$(date +%H:%M:%S)] $*"
    _LB=("${_LB[@]:1}" "$msg")
    local i=0
    for entry in "${_LB[@]}"; do
        tput cup $((R_L0+i)) $_LC
        printf "%-60s" ""        # 清旧内容
        tput cup $((R_L0+i)) $_LC
        echo -ne "$entry"
        i=$((i+1))
    done
    _tick_bc
    tput cup $R_INP 2
}

# ==============================================================
#  基础工具
# ==============================================================
_ms2s() { LC_ALL=C awk "BEGIN{printf \"%.3f\",$1/1000}"; }

# 可中断 sleep，每 50ms 检查停止标志
# 若 _CD_ROW 非空，每秒在该行更新剩余秒数
safe_sleep() {
    local total_ms=$1 elapsed=0 last_sec=-1
    while [ $elapsed -lt $total_ms ]; do
        [ -f "$STOP_FLAG" ] && return 1
        local remain=$((total_ms - elapsed))
        local step=$((remain < 50 ? remain : 50))
        sleep "$(_ms2s $step)"
        elapsed=$((elapsed + step))
        if [ -n "$_CD_ROW" ]; then
            local secs=$(( (total_ms - elapsed + 999) / 1000 ))
            [ $secs -lt 0 ] && secs=0
            if [ "$secs" != "$last_sec" ]; then
                last_sec=$secs
                tput cup "$_CD_ROW" $_VC
                printf "%-${_VW}s" ""
                tput cup "$_CD_ROW" $_VC
                echo -ne "${CC}${secs}s${RC}"
                _tick_bc
                tput cup $R_INP 2
            fi
        fi
    done
    return 0
}

# press_key key hold_ms after_ms
press_key() {
    local key=$1 hold_ms=$2 after_ms=$3
    [ -f "$STOP_FLAG" ] && return 1
    log "  [$key] 按住${hold_ms}ms  后等${after_ms}ms"
    xdotool keydown "$key"
    if ! safe_sleep $hold_ms; then xdotool keyup "$key"; return 1; fi
    xdotool keyup "$key"
    [ "$after_ms" -gt 0 ] || return 0
    safe_sleep $after_ms || return 1
}

release_all() {
    xdotool keyup w      2>/dev/null
    xdotool keyup Return 2>/dev/null
    xdotool keyup x      2>/dev/null
}

cleanup() {
    touch "$STOP_FLAG"   # 通知所有 safe_sleep 退出
    _CD_ROW=""           # 清倒计时状态
    release_all          # 释放卡住的按键
}
# Ctrl+C: 只设标志 + 释放按键，其余由 run_ 函数自行退出后返回菜单
trap 'cleanup; log "<<< Ctrl+C 停止"' INT TERM

# ==============================================================
#  启动前倒计时（带 UI 进度条）
# ==============================================================
start_countdown() {
    sv $R_ST0 "倒计时中..." "$YC"
    sv $R_ST1 "请在 ${START_DELAY}s 内点击游戏窗口！" "$CC"
    local bar_full=20
    for i in $(seq "$START_DELAY" -1 1); do
        # 进度条：已过时间 / 总时间
        local done_n=$(( (START_DELAY - i) * bar_full / START_DELAY ))
        local todo_n=$(( bar_full - done_n ))
        local bar=""
        for x in $(seq 1 $done_n); do bar="${bar}█"; done
        for x in $(seq 1 $todo_n); do bar="${bar}░"; done
        sv $R_ST2 "${bar}  ${i}s" "$YC"
        sleep 1
    done
    sv $R_ST2 "" ""
    sv $R_ST1 "" ""
}

# ==============================================================
#  效率统计
# ==============================================================
print_efficiency() {
    local elapsed=$(( $(date +%s) - _START_TIME ))
    local pts=$(( _LOOP_COUNT * POINTS_PER_LOOP ))
    local eff=0
    [ $elapsed -gt 0 ] && eff=$(( pts * 3600 / elapsed ))
    sv $R_ST3 "${_LOOP_COUNT} 轮 / ${elapsed}s" "$YC"
    sv $R_ST4 "${pts} 点  约 ${eff} 点/小时" "$GC"
    log "  效率 ${_LOOP_COUNT}轮/${elapsed}s/${pts}点/约${eff}点·h"
}

# ==============================================================
#  功能一：买车 + 加点
# ==============================================================
run_buycar() {
    local total=${1:-1}
    rm -f "$STOP_FLAG"
    _BC_START=$(date +%s)
    sv $R_ST0 ">> 买车+加点" "$GC"
    sv $R_ST1 "共 $total 次" "$WC"
    sv $R_ST2 "0 / $total" "$WC"
    sv $R_ST3 "--:--" "$YC"
    sv $R_ST4 "" ""
    start_countdown
    log ">>> 买车循环 启动，共 $total 次"

    local i=1
    while [ $i -le $total ]; do
        [ -f "$STOP_FLAG" ] && break
        sv $R_ST2 "$i / $total" "$WC"
        log "=== 第 $i / $total 次 ==="

        log "--- 买车 ---"
        sv $R_ST1 "买车中..." "$WC"
        safe_sleep $BC_INIT_WAIT                              || break
        press_key Up        $BC_HOLD_NAV   80                 || break
        press_key Up        $BC_HOLD_NAV   80                 || break
        press_key Up        $BC_HOLD_NAV   200                || break
        press_key Return    $BC_HOLD_ENTER $BC_MENU_ENTER     || break
        press_key BackSpace $BC_HOLD_NAV   600                || break
        press_key Right     $BC_HOLD_NAV   150                || break
        press_key Up        $BC_HOLD_NAV   150                || break
        press_key Up        $BC_HOLD_NAV   150                || break
        press_key Up        $BC_HOLD_NAV   150                || break
        press_key Up        $BC_HOLD_NAV   150                || break
        press_key Up        $BC_HOLD_NAV   150                || break
        press_key Up        $BC_HOLD_NAV   150                || break
        press_key Up        $BC_HOLD_NAV   150                || break
        press_key Return    $BC_HOLD_ENTER 700                || break
        press_key Right     $BC_HOLD_NAV   150                || break
        press_key Right     $BC_HOLD_NAV   150                || break
        press_key Right     $BC_HOLD_NAV   150                || break
        press_key Return    $BC_HOLD_ENTER $BC_CONFIRM_WAIT   || break
        press_key y         $BC_HOLD_NAV   $BC_PURCHASE_CFM   || break
        press_key Return    $BC_HOLD_ENTER 700                || break
        press_key Return    $BC_HOLD_ENTER 600                || break
        press_key Return    $BC_HOLD_ENTER $BC_AFTER_BUY      || break

        log "--- 加点 ---"
        sv $R_ST1 "加点中..." "$WC"
        press_key Escape $BC_HOLD_NAV   $BC_ESC_WAIT          || break
        press_key Right  $BC_HOLD_NAV   $BC_SKILL_ENTER       || break
        press_key Down   $BC_HOLD_NAV   500                   || break
        press_key Return $BC_HOLD_ENTER $BC_SKILL_SETTLE      || break
        press_key Down   $BC_HOLD_NAV   150                   || break
        press_key Down   $BC_HOLD_NAV   150                   || break
        press_key Down   $BC_HOLD_NAV   150                   || break
        press_key Down   $BC_HOLD_NAV   150                   || break
        press_key Down   $BC_HOLD_NAV   150                   || break
        press_key Down   $BC_HOLD_NAV   150                   || break
        press_key Down   $BC_HOLD_NAV   150                   || break
        press_key Return $BC_HOLD_ENTER $BC_SKILL_APPLY       || break
        press_key Return $BC_HOLD_ENTER $BC_SKILL_APPLY2      || break
        press_key Right  $BC_HOLD_NAV   250                   || break
        press_key Return $BC_HOLD_ENTER 500                   || break
        press_key Up     $BC_HOLD_NAV   250                   || break
        press_key Return $BC_HOLD_ENTER 500                   || break
        press_key Up     $BC_HOLD_NAV   250                   || break
        press_key Return $BC_HOLD_ENTER 500                   || break
        press_key Up     $BC_HOLD_NAV   250                   || break
        press_key Return $BC_HOLD_ENTER 500                   || break
        press_key Left   $BC_HOLD_NAV   270                   || break
        press_key Return $BC_HOLD_ENTER 1005                  || break
        press_key Escape $BC_HOLD_NAV   $BC_ESC_FINAL         || break
        press_key Escape $BC_HOLD_NAV   $BC_ESC_FINAL2        || break
        press_key Left   $BC_HOLD_NAV   0                     || break

        log "=== 第 $i 次完成 ==="
        i=$((i+1))
    done

    _BC_START=0
    local done_n=$((i-1))
    if [ -f "$STOP_FLAG" ]; then
        sv $R_ST0 "-- 已停止" "$DC"
        sv $R_ST1 "完成 $done_n / $total 次" "$WC"
        log ">>> 买车循环 已停止（$done_n / $total）"
    else
        sv $R_ST0 "✓  全部完成" "$GC"
        sv $R_ST1 "共 $total 次" "$WC"
        log ">>> 买车循环 全部完成！共 $total 次"
    fi
    rm -f "$STOP_FLAG"
}

# ==============================================================
#  功能二：W 循环
# ==============================================================
run_wloop() {
    rm -f "$STOP_FLAG"
    sv $R_ST0 ">> W 循环" "$GC"
    sv $R_ST1 "每次按住 ${W_HOLD_SEC}s" "$WC"
    sv $R_ST2 "" ""; sv $R_ST3 "" ""; sv $R_ST4 "" ""
    start_countdown
    log ">>> W循环 启动"

    local cycle=0
    while [ ! -f "$STOP_FLAG" ]; do
        cycle=$((cycle+1))
        sv $R_ST2 "第 $cycle 次，按住中..." "$WC"
        log "  [W] 第 $cycle 次，按住 ${W_HOLD_SEC}s"
        xdotool keydown w
        safe_sleep $((W_HOLD_SEC * 1000)) || { xdotool keyup w; break; }
        xdotool keyup w
        log "  [W] 松开"
        sv $R_ST2 "第 $cycle 次，短暂停顿..." "$DC"
        safe_sleep $W_PAUSE_MS || break
    done

    xdotool keyup w 2>/dev/null
    sv $R_ST0 "-- 已停止" "$DC"
    log "<<< W循环 结束"
    rm -f "$STOP_FLAG"
}

# ==============================================================
#  功能三：熟练度循环
# ==============================================================
run_mastery() {
    rm -f "$STOP_FLAG"
    _LOOP_COUNT=0
    _START_TIME=$(date +%s)
    sv $R_ST0 ">> 熟练度循环" "$GC"
    sv $R_ST1 "蓝图 440288370" "$WC"
    sv $R_ST2 "倒计时..." "$CC"
    sv $R_ST3 "0 轮" "$YC"
    sv $R_ST4 "—" ""
    start_countdown
    log ">>> 熟练度循环 启动"

    while [ ! -f "$STOP_FLAG" ]; do
        _LOOP_COUNT=$((_LOOP_COUNT+1))
        sv $R_ST3 "${_LOOP_COUNT} 轮" "$YC"
        log "── 第 ${_LOOP_COUNT} 轮 ──"

        # Step 1: Enter 进入
        sv $R_ST1 "确认进入..." "$WC"
        xdotool keydown Return
        safe_sleep $MA_ENTER_HOLD || { xdotool keyup Return; break; }
        xdotool keyup Return
        log "  [Enter] 确认"

        sv $R_ST1 "等待加载..." "$WC"
        _CD_ROW=$R_ST2
        safe_sleep $MA_INIT_WAIT || { _CD_ROW=""; break; }
        _CD_ROW=""

        # Step 2: W 油门
        sv $R_ST1 "W 油门中..." "$GC"
        _CD_ROW=$R_ST2
        log "  [W] 开始，${MA_DRIVE_MS}ms"
        xdotool keydown w
        safe_sleep $MA_DRIVE_MS || {
            xdotool keyup w; xdotool keyup Return; _CD_ROW=""; break
        }
        xdotool keyup Return 2>/dev/null
        _CD_ROW=""

        sv $R_ST1 "继续踩油..." "$GC"
        _CD_ROW=$R_ST2
        safe_sleep $MA_DRIVE_EXTRA || { xdotool keyup w; _CD_ROW=""; break; }
        _CD_ROW=""
        xdotool keyup w
        log "  [W] 松油"

        # Step 3: X
        sv $R_ST1 "X 操作..." "$WC"
        xdotool keydown x
        safe_sleep $MA_X_HOLD || { xdotool keyup x; break; }
        xdotool keyup x
        safe_sleep 500 || break

        # Step 4: Enter 两次，等待结算
        sv $R_ST1 "Enter 确认结算..." "$WC"
        xdotool keydown Return
        safe_sleep $MA_CONFIRM_HOLD || { xdotool keyup Return; break; }
        xdotool keyup Return

        xdotool keydown Return
        safe_sleep $MA_CONFIRM_HOLD || { xdotool keyup Return; break; }
        xdotool keyup Return

        sv $R_ST1 "等待结算..." "$WC"
        _CD_ROW=$R_ST2
        safe_sleep $MA_SETTLE_MS || { _CD_ROW=""; break; }
        _CD_ROW=""

        safe_sleep $MA_LOOP_TAIL || break
        print_efficiency
    done

    _CD_ROW=""
    release_all
    sv $R_ST0 "-- 已停止" "$DC"
    sv $R_ST1 "" ""
    sv $R_ST2 "" ""
    print_efficiency
    log "<<< 熟练度循环 结束，按键已释放"
    rm -f "$STOP_FLAG"
}

# ==============================================================
#  主菜单
# ==============================================================
show_menu_prompt() {
    sv $R_ST0 "待机中..." "$DC"
    sc $R_ST1; sc $R_ST2; sc $R_ST3; sc $R_ST4
    tput cup $R_INP 0
    printf "  请选择 [1/2/3/q]: "
}

# 检测终端宽度
_check_term() {
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)
    if [ "$cols" -lt 63 ]; then
        echo "  ⚠  终端宽度 ${cols} 列，建议拉宽到 63 列以上以正常显示"
        sleep 2
    fi
}

case "${1:-menu}" in
    buy)
        _check_term
        draw_frame
        printf "循环次数 [1]: "; read loops; loops=${loops:-1}
        run_buycar "$loops"
        ;;
    wloop)
        _check_term
        draw_frame
        run_wloop
        ;;
    mastery)
        _check_term
        draw_frame
        run_mastery
        ;;
    menu|*)
        _check_term
        draw_frame
        while true; do
            show_menu_prompt
            read -r choice
            tput cup $R_INP 0; printf "%-40s" ""  # 清输入行
            case "$choice" in
                1)
                    tput cup $R_INP 0
                    printf "  循环次数 [1]: "; read -r loops; loops=${loops:-1}
                    tput cup $R_INP 0; printf "%-40s" ""
                    run_buycar "$loops"
                    ;;
                2) run_wloop   ;;
                3) run_mastery ;;
                q|Q)
                    tput cup $R_INP 0; echo "  已退出"
                    tput cup 26 0; exit 0
                    ;;
                *) ;;
            esac
        done
        ;;
esac
