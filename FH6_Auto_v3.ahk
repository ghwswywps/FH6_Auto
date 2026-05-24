#Requires AutoHotkey v2.0
#SingleInstance Force

; ╔══════════════════════════════════════════════════════════════╗
; ║        Forza Horizon 6  全自动脚本  【后台版】               ║
; ║  F1  买车+加点（手动，再按停止）                            ║
; ║  F5  自动大循环（熟练度101轮→导航车库→买车30次→导航蓝图）  ║
; ║  F6  调试: 蓝图→车库 导航                                   ║
; ║  F7  调试: 车库→蓝图 导航                                   ║
; ║  F8  熟练度循环（手动无限，再按停止）                       ║
; ║  F9  W循环（再按停止）                                      ║
; ╚══════════════════════════════════════════════════════════════╝

; ══════════════════════════════════════════════════════════════
;  ★ 用户配置区
; ══════════════════════════════════════════════════════════════

; ── 热键 ──
HOT_BUYCAR  := "F1"
HOT_AUTO    := "F5"
HOT_NAV_MTG := "F6"   ; 蓝图→车库（调试）
HOT_NAV_GTM := "F7"   ; 车库→蓝图（调试）
HOT_MASTERY := "F8"
HOT_WLOOP   := "F9"

; ── 买车+加点 参数 ──
BC_INIT_WAIT    := 500
BC_MENU_ENTER   := 1000
BC_CONFIRM_WAIT := 3800
BC_PURCHASE_CFM := 1000
BC_AFTER_BUY    := 13000
BC_ESC_WAIT     := 1000
BC_SKILL_ENTER  := 1000
BC_SKILL_SETTLE := 1000
BC_SKILL_APPLY  := 1100
BC_SKILL_APPLY2 := 1100
BC_ESC_FINAL    := 800
BC_ESC_FINAL2   := 1000

; ── W 循环 ──
W_HOLD_MS  := 5 * 60 * 1000
W_PAUSE_MS := 50

; ── 熟练度循环 参数 ──
MA_INIT_WAIT    := 3000
MA_DRIVE_MS     := 26000
MA_DRIVE_EXTRA  := 2000
MA_SETTLE_MS    := 4000
POINTS_PER_LOOP := 10

; ── 自动大循环配置 ──
AUTO_MASTERY_LOOPS := 109   ; 每周期刷熟练度圈数
AUTO_BUYCAR_TIMES  := 33    ; 每周期买车次数

; ══════════════════════════════════════════════════════════════
;  全局状态变量
; ══════════════════════════════════════════════════════════════
bcRunning       := false
bcLoopCount     := 0
bcTotal         := 0
bcStartTime     := 0

wRunning        := false

bRunning        := false
bCurrentHeldKey := ""
bLoopCount      := 0
bStartTime      := 0

navRunning      := false
autoRunning     := false
autoCycle       := 0
autoPhase       := "—"

GameHwnd        := 0

; ══════════════════════════════════════════════════════════════
;  GUI
; ══════════════════════════════════════════════════════════════
GW := 320

G := Gui("+AlwaysOnTop +ToolWindow -Caption", "FH6 自动脚本")
G.BackColor := "0D0D1A"

G.SetFont("s11 Bold cFFFFFF", "Microsoft YaHei")
G.Add("Text", "x10 y10 w" (GW-50) " h20", "Forza Horizon 6  全自动脚本【后台版】")
minBtn := G.Add("Button", "x" (GW-36) " y7 w28 h18", "─")
minBtn.OnEvent("Click", (*) => WinMinimize(G.Hwnd))
G.Add("Text", "x0 y34 w" GW " h1 Background2A2A4A")

G.SetFont("s8 Bold cFFD700", "Consolas")
G.Add("Text", "x10 y40 w" (GW-20) " h14", "[ 按键说明 ]")
G.SetFont("s8 c888888", "Consolas")
G.Add("Text", "x10 y56 w" (GW-20) " h14", "F1   买车+加点    在【购买与出售】页面使用")
G.Add("Text", "x10 y70 w" (GW-20) " h14", "F5   自动大循环   请在蓝图加载完的页面启动")
G.Add("Text", "x10 y84 w" (GW-20) " h14", "F6   蓝图→车库   调试导航")
G.Add("Text", "x10 y98 w" (GW-20) " h14", "F7   车库→蓝图   调试导航")
G.Add("Text", "x10 y112 w" (GW-20) " h14", "F8   熟练度循环   请在蓝图加载完的页面启动")
G.Add("Text", "x10 y126 w" (GW-20) " h14", "F9   W循环       在巨汉开跑后使用")
G.SetFont("s8 c444455", "Consolas")
G.Add("Text", "x10 y142 w" (GW-20) " h14", "※ 严格使用：蓝图 705399298  调教 772778773")
G.Add("Text", "x0 y158 w" GW " h1 Background2A2A4A")

; ── 自动大循环 ──
G.SetFont("s8 Bold cFF8800", "Consolas")
G.Add("Text", "x10 y164 w" (GW-20) " h14", "[ 自动大循环  F5 ]")
G.SetFont("s8 c666677", "Consolas")
G.Add("Text", "x10 y180 w46 h14", "状态:")
G.Add("Text", "x10 y196 w46 h14", "阶段:")
G.Add("Text", "x10 y212 w46 h14", "周期:")
G.SetFont("s8 c888888", "Consolas")
autoStatusLbl := G.Add("Text", "x60 y180 w" (GW-70) " h14", "■ 待机")
G.SetFont("s8 cFFD700", "Consolas")
autoPhaseLbl  := G.Add("Text", "x60 y196 w" (GW-70) " h14", "—")
G.SetFont("s8 cFF8800", "Consolas")
autoCycleLbl  := G.Add("Text", "x60 y212 w" (GW-70) " h14", "0")
G.Add("Text", "x0 y228 w" GW " h1 Background2A2A4A")

; ── 导航 ──
G.SetFont("s8 Bold c00CFFF", "Consolas")
G.Add("Text", "x10 y234 w" (GW-20) " h14", "[ 导航  F6蓝图→车库  F7车库→蓝图 ]")
G.SetFont("s8 c666677", "Consolas")
G.Add("Text", "x10 y250 w46 h14", "状态:")
G.Add("Text", "x10 y266 w46 h14", "步骤:")
G.SetFont("s8 c888888", "Consolas")
navStatusLbl := G.Add("Text", "x60 y250 w" (GW-70) " h14", "■ 待机")
G.SetFont("s8 cFFD700", "Consolas")
navStepLbl   := G.Add("Text", "x60 y266 w" (GW-70) " h14", "—")
G.Add("Text", "x0 y282 w" GW " h1 Background2A2A4A")

; ── 买车+加点 ──
G.SetFont("s8 Bold cFFD700", "Consolas")
G.Add("Text", "x10 y288 w" (GW-20) " h14", "[ 买车 + 加点  F1 ]")
G.SetFont("s8 c666677", "Consolas")
G.Add("Text", "x10 y304 w46 h14", "状态:")
G.Add("Text", "x10 y320 w46 h14", "进度:")
G.Add("Text", "x10 y336 w46 h14", "运行:")
G.Add("Text", "x10 y352 w56 h14", "手动次数:")
G.SetFont("s8 c888888", "Consolas")
bcStatusLbl   := G.Add("Text", "x60 y304 w" (GW-70) " h14", "■ 待机")
G.SetFont("s8 cFFFFFF", "Consolas")
bcProgressLbl := G.Add("Text", "x60 y320 w90 h14", "0 / 0")
G.SetFont("s8 cF9E2AF", "Consolas")
bcTimerLbl    := G.Add("Text", "x60 y336 w90 h14", "--:--")
G.SetFont("s9 c000000", "Consolas")
loopEdit      := G.Add("Edit", "x72 y349 w50 h18 Number", "1")
G.Add("Text", "x0 y372 w" GW " h1 Background2A2A4A")

; ── W循环 ──
G.SetFont("s8 Bold cFFD700", "Consolas")
G.Add("Text", "x10 y378 w" (GW-20) " h14", "[ W 循环  F9 ]")
G.SetFont("s8 c666677", "Consolas")
G.Add("Text", "x10 y394 w46 h14", "状态:")
G.SetFont("s8 c888888", "Consolas")
wStatusLbl := G.Add("Text", "x60 y394 w" (GW-70) " h14", "■ 待机")
G.Add("Text", "x0 y410 w" GW " h1 Background2A2A4A")

; ── 熟练度循环 ──
G.SetFont("s8 Bold cFFD700", "Consolas")
G.Add("Text", "x10 y416 w" (GW-20) " h14", "[ 熟练度循环  F8 ]")
G.SetFont("s8 c666677", "Consolas")
G.Add("Text", "x10 y432 w46 h14", "状态:")
G.Add("Text", "x10 y448 w46 h14", "阶段:")
G.Add("Text", "x10 y464 w46 h14", "次数:")
G.SetFont("s8 c888888", "Consolas")
bStatusLbl   := G.Add("Text", "x60 y432 w" (GW-70) " h14", "■ 待机")
G.SetFont("s8 cFFD700", "Consolas")
PhaseLbl     := G.Add("Text", "x60 y448 w100 h14", "—")
G.SetFont("s8 c666677", "Consolas")
G.Add("Text", "x168 y448 w30 h14", "剩余:")
G.SetFont("s8 c00CFFF", "Consolas")
CountdownLbl := G.Add("Text", "x202 y448 w" (GW-212) " h14", "—")
G.SetFont("s8 cFF8800", "Consolas")
LoopCountLbl := G.Add("Text", "x60 y464 w" (GW-70) " h14", "0")
G.Add("Text", "x0 y480 w" GW " h1 Background1A1A2A")

; ── 效率监控 ──
G.SetFont("s8 Bold c444455", "Consolas")
G.Add("Text", "x10 y486 w" (GW-20) " h14", "[ 效率监控 ]")
G.SetFont("s8 c666677", "Consolas")
G.Add("Text", "x10 y502 w60 h14", "运行时长:")
G.Add("Text", "x10 y518 w60 h14", "预期效率:")
G.SetFont("s8 cFFFFFF", "Consolas")
ElapsedLbl := G.Add("Text", "x74 y502 w60 h14", "—")
G.SetFont("s8 c00FF88", "Consolas")
G.Add("Text", "x150 y502 w46 h14", "总点数:")
PointsLbl  := G.Add("Text", "x200 y502 w" (GW-210) " h14", "—")
G.SetFont("s8 Bold cFFD700", "Consolas")
EffLbl     := G.Add("Text", "x74 y518 w" (GW-84) " h14", "—")
G.Add("Text", "x0 y534 w" GW " h1 Background2A2A4A")

; ── 后台状态 ──
G.SetFont("s8 Bold c00CFFF", "Consolas")
G.Add("Text", "x10 y540 w" (GW-20) " h14", "[ 后台发键状态 ]")
G.SetFont("s8 c666677", "Consolas")
G.Add("Text", "x10 y556 w60 h14", "游戏进程:")
G.SetFont("s8 cFFFFFF", "Consolas")
hwndLbl    := G.Add("Text", "x74 y556 w" (GW-84) " h14", "未找到")
G.SetFont("s8 c444455", "Consolas")
refreshBtn := G.Add("Button", "x" (GW-68) " y552 w60 h18", "刷新窗口")
refreshBtn.OnEvent("Click", (*) => (FindGame(), UpdateHwndLabel()))
G.Add("Text", "x0 y572 w" GW " h1 Background2A2A4A")

; ── 按键记录 ──
G.SetFont("s8 Bold cFFD700", "Consolas")
G.Add("Text", "x10 y578 w100 h14", "[ 按键记录 ]")
G.SetFont("s8 c444455", "Consolas")
clearBtn := G.Add("Button", "x" (GW-68) " y574 w60 h18", "清空日志")
clearBtn.OnEvent("Click", (*) => (logBox.Value := ""))
G.SetFont("s8 c00FF99", "Consolas")
logBox := G.Add("Edit", "x10 y595 w" (GW-20) " h140 ReadOnly -E0x200 Background0A0A18")

G.Show("x10 y10 w" GW " h745 NoActivate")

FindGame()
UpdateHwndLabel()

; ══════════════════════════════════════════════════════════════
;  导航序列定义
; ══════════════════════════════════════════════════════════════

; 蓝图 → 车库
SEQ_MTG := [
    ["Down",  100,  150],
    ["Down",  100,  150],
    ["Down",  100,  150],
    ["Down",  100,  600],
    ["Enter", 100, 1000],
    ["Enter", 100, 18000],
    ["Esc",   100, 1500],
    ["PgDn",  100,  400],
    ["PgDn",  100, 1000],
    ["Enter", 100,  800],
    ["Enter", 100, 13000],
    ["Right", 100, 2000],
]

; 车库 → 蓝图
SEQ_GTM := [
    ["Esc",   100, 11000],
    ["Esc",   100, 1100],
    ["PgDn",  100,  150],
    ["PgDn",  100,  150],
    ["PgDn",  100,  150],
    ["PgDn",  100,  500],
    ["Enter", 100,  900],
    ["Enter", 100, 1000],
    ["PgDn",  100,  150],
    ["PgDn",  100,  150],
    ["PgDn",  100,  150],
    ["PgDn",  100,  150],
    ["PgDn",  100,  150],
    ["PgDn",  100,  150],
    ["PgDn",  100, 5000],
    ["Enter", 100, 5000],
    ["Enter", 100, 3000],
    ["Y",     100, 1000],
    ["Enter", 100, 1000],
    ["Esc",   100, 1000],
    ["Enter", 100, 14000],
]

; ══════════════════════════════════════════════════════════════
;  注册热键
; ══════════════════════════════════════════════════════════════
Hotkey HOT_BUYCAR,  ToggleBuyCar
Hotkey HOT_AUTO,    ToggleAuto
Hotkey HOT_NAV_MTG, ToggleNavMTG
Hotkey HOT_NAV_GTM, ToggleNavGTM
Hotkey HOT_MASTERY, ToggleB
Hotkey HOT_WLOOP,   ToggleW

; ══════════════════════════════════════════════════════════════
;  工具函数（原有，不变）
; ══════════════════════════════════════════════════════════════

GSend(keys) {
    global GameHwnd
    if !GameHwnd {
        FindGame()
        UpdateHwndLabel()
    }
    if GameHwnd
        ControlSend keys, , "ahk_id " GameHwnd
    else
        Log("  !! 未找到游戏窗口，跳过发键")
}

Log(msg) {
    global logBox
    cur  := logBox.Value
    line := "[" FormatTime(, "HH:mm:ss") "] " msg
    logBox.Value := (cur = "" ? line : cur "`n" line)
    SendMessage 0x115, 7, 0, logBox
}

AnyRunning() {
    global bcRunning, wRunning, bRunning, navRunning, autoRunning
    return bcRunning || wRunning || bRunning || navRunning || autoRunning
}

FindGame() {
    global GameHwnd
    GameHwnd := 0
    try GameHwnd := WinGetID("ahk_exe forzahorizon6.exe")
    if !GameHwnd
        try GameHwnd := WinGetID("Forza Horizon 6")
    return GameHwnd
}

UpdateHwndLabel() {
    global GameHwnd, hwndLbl
    if GameHwnd
        hwndLbl.Value := "已找到 (hwnd=" GameHwnd ")"
    else
        hwndLbl.Value := "未找到 ← 先启动游戏"
    hwndLbl.SetFont(GameHwnd ? "s8 c00FF88" : "s8 cFF4444", "Consolas")
}

SetBcStatus(txt, color) {
    global bcStatusLbl
    bcStatusLbl.SetFont("s8 c" color, "Consolas")
    bcStatusLbl.Value := txt
}
SetWStatus(txt, color) {
    global wStatusLbl
    wStatusLbl.SetFont("s8 c" color, "Consolas")
    wStatusLbl.Value := txt
}
SetBStatus(txt, color) {
    global bStatusLbl
    bStatusLbl.SetFont("s8 c" color, "Consolas")
    bStatusLbl.Value := txt
}
SetAutoStatus(txt, color) {
    global autoStatusLbl
    autoStatusLbl.SetFont("s8 c" color, "Consolas")
    autoStatusLbl.Value := txt
}
SetNavStatus(txt, color) {
    global navStatusLbl
    navStatusLbl.SetFont("s8 c" color, "Consolas")
    navStatusLbl.Value := txt
}
SetPhase(txt) {
    global PhaseLbl
    PhaseLbl.Value := txt
}
SetCountdown(txt) {
    global CountdownLbl
    CountdownLbl.Value := txt
}

UpdateEfficiency() {
    global bStartTime, bLoopCount, POINTS_PER_LOOP, ElapsedLbl, PointsLbl, EffLbl
    if bStartTime = 0 {
        ElapsedLbl.Value := "—"
        PointsLbl.Value  := "—"
        EffLbl.Value     := "—"
        return
    }
    sec   := (A_TickCount - bStartTime) / 1000
    total := bLoopCount * POINTS_PER_LOOP
    eff   := sec > 0 ? Round(total / sec * 3600) : 0
    ElapsedLbl.Value := Round(sec) " s"
    PointsLbl.Value  := total " 个"
    EffLbl.Value     := eff " 个/小时"
}

UpdateBcTimer() {
    global bcRunning, bcStartTime, bcTimerLbl
    if !bcRunning
        return
    e := A_TickCount - bcStartTime
    bcTimerLbl.Value := Format("{:02d}:{:02d}", e // 60000, Mod(e // 1000, 60))
}

; ── PrintWindow 取像素（不受遮挡） ───────────────────────────
GetWindowPixelColor(hwnd, x, y) {
    hDC  := DllCall("GetDC", "Ptr", hwnd, "Ptr")
    hMDC := DllCall("CreateCompatibleDC", "Ptr", hDC, "Ptr")
    rc   := Buffer(16, 0)
    DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rc)
    w := NumGet(rc, 8, "Int")
    h := NumGet(rc, 12, "Int")
    hBmp := DllCall("CreateCompatibleBitmap", "Ptr", hDC, "Int", w, "Int", h, "Ptr")
    DllCall("SelectObject", "Ptr", hMDC, "Ptr", hBmp)
    DllCall("PrintWindow", "Ptr", hwnd, "Ptr", hMDC, "UInt", 2)
    col := DllCall("GetPixel", "Ptr", hMDC, "Int", x, "Int", y, "UInt")
    DllCall("DeleteObject", "Ptr", hBmp)
    DllCall("DeleteDC",     "Ptr", hMDC)
    DllCall("ReleaseDC",    "Ptr", hwnd, "Ptr", hDC)
    return col
}

WaitBottomLeftNotBlack() {
    global bcRunning, GameHwnd
    loop {
        if !bcRunning
            return false
        try {
            WinGetClientPos(&cx_orig, &cy_orig, &cw, &ch, "ahk_id " GameHwnd)
        } catch {
            return true
        }
        ; 底部黑条水平居中，y距底边1px，5点横向散开
        allBlack := true
        loop 5 {
            sx  := (cw // 2) - 40 + (A_Index - 1) * 20   ; 围绕中心 x-40~x+40
            sy  := ch - 1                                   ; 距底边1px
            col := GetWindowPixelColor(GameHwnd, sx, sy)
            if (col & 0xFFFFFF) > 0x0A0A0A {
                allBlack := false
                break
            }
        }
        if !allBlack {
            Log("  ✓ 购车完成，继续流程")
            Sleep 200
            return true
        }
        Log("  × 尚未购车完成，等待 500ms")
        Sleep 500
    }
}

; ── 买车循环的可中断 Sleep ────────────────────────────────────
SafeSleep(ms) {
    global bcRunning
    elapsed := 0
    while elapsed < ms {
        if !bcRunning
            return false
        chunk := Min(30, ms - elapsed)
        Sleep chunk
        elapsed += chunk
    }
    return true
}

Press(key, holdMs, afterMs) {
    global bcRunning
    if !bcRunning
        return false
    Log("  " key "  按住 " holdMs "ms  后等 " afterMs "ms")
    GSend "{" key " down}"
    if !SafeSleep(holdMs)
        return false
    GSend "{" key " up}"
    if afterMs > 0
        return SafeSleep(afterMs)
    return true
}

; ── 熟练度的可中断 Sleep ─────────────────────────────────────
InterruptSleep(ms) {
    global bRunning
    deadline := A_TickCount + ms
    Loop {
        if !bRunning
            return false
        if A_TickCount >= deadline
            break
        remaining := Max(0, (deadline - A_TickCount) // 1000)
        SetCountdown(remaining "s")
        Sleep 100
    }
    return bRunning
}

; ══════════════════════════════════════════════════════════════
;  F1  买车 + 加点（手动，再按停止）
; ══════════════════════════════════════════════════════════════
ToggleBuyCar(*) {
    global bcRunning, bcLoopCount, bcTotal, bcStartTime, bcProgressLbl, bcTimerLbl, loopEdit
    if bcRunning {
        bcRunning := false
        SetTimer UpdateBcTimer, 0
        SetBcStatus("■ 待机", "888888")
        Log("<<< 买车循环 手动停止")
        return
    }
    if AnyRunning() {
        Log("!!! 有其他循环运行中，请先停止")
        return
    }
    if !GameHwnd {
        FindGame()
        UpdateHwndLabel()
        if !GameHwnd {
            Log("!!! 未找到游戏窗口，无法启动")
            return
        }
    }
    bcTotal     := Integer(loopEdit.Value)
    if bcTotal < 1
        bcTotal := 1
    bcRunning   := true
    bcLoopCount := 0
    bcStartTime := A_TickCount
    bcTimerLbl.Value    := "00:00"
    bcProgressLbl.Value := "0 / " bcTotal
    SetBcStatus("▶ 后台运行", "00FF88")
    SetTimer UpdateBcTimer, 1000
    Log(">>> 买车循环 启动（手动），共 " bcTotal " 次")
    SetTimer BuyCarLoop, -1
}

BuyCarLoop() {
    global bcRunning, bcLoopCount, bcTotal, bcProgressLbl
    global BC_INIT_WAIT, BC_MENU_ENTER, BC_CONFIRM_WAIT, BC_PURCHASE_CFM
    global BC_AFTER_BUY, BC_ESC_WAIT, BC_SKILL_ENTER, BC_SKILL_SETTLE
    global BC_SKILL_APPLY, BC_SKILL_APPLY2, BC_ESC_FINAL, BC_ESC_FINAL2

    loop bcTotal {
        if !bcRunning
            break
        bcLoopCount         := A_Index
        bcProgressLbl.Value := bcLoopCount " / " bcTotal
        Log("=== 第 " bcLoopCount " / " bcTotal " 次循环开始 ===")
        if !RunBuyCarBody()
            break
        Log("=== 第 " bcLoopCount " 次完成 ===")
    }

    SetTimer UpdateBcTimer, 0
    bcRunning := false
    done := bcLoopCount >= bcTotal
    SetBcStatus("■ 待机", "888888")
    bcProgressLbl.Value := bcLoopCount " / " bcTotal
    Log(done ? ">>> 买车循环 全部完成！" : ">>> 买车循环 已停止")
    if done
        MsgBox "全部完成！`n共执行 " bcTotal " 次循环。", "完成", "Iconi T3"
}

; 买车单次循环体（供手动和自动共用）
RunBuyCarBody() {
    global BC_INIT_WAIT, BC_MENU_ENTER, BC_CONFIRM_WAIT, BC_PURCHASE_CFM
    global BC_AFTER_BUY, BC_ESC_WAIT, BC_SKILL_ENTER, BC_SKILL_SETTLE
    global BC_SKILL_APPLY, BC_SKILL_APPLY2, BC_ESC_FINAL, BC_ESC_FINAL2

    Log("--- 买车 ---")
    if !SafeSleep(BC_INIT_WAIT)
        return false
    if !Press("Up", 80, 80)
        return false
    if !Press("Up", 80, 80)
        return false
    if !Press("Up", 80, 80)
        return false
    if !Press("Enter", 100, BC_MENU_ENTER) 
        return false
    if !Press("BackSpace", 100, 800)
        return false
    if !Press("Right", 80, 150)
        return false
    if !Press("Right", 80, 150)
        return false
    if !Press("Right", 80, 150)
        return false
    if !Press("Up", 80, 150)
        return false
    if !Press("Up", 80, 150)
        return false
    if !Press("Enter", 80, 1000)
        return false
    if !Press("Right", 80, 150)
        return false
    if !Press("Right", 80, 150)
        return false
    if !Press("Right", 80, 150)
        return false
    if !Press("Enter", 80, BC_CONFIRM_WAIT) 
        return false
    if !Press("y", 80, BC_PURCHASE_CFM)
        return false
    if !Press("Enter", 80, 700)
        return false
    if !Press("Enter", 80, 700)
        return false
    if !Press("Enter", 80, BC_AFTER_BUY)
        return false

    Log("--- 等待购车完成 ---")
    if !WaitBottomLeftNotBlack()
        return false

    Log("--- 加点 ---")
    if !Press("Esc", 100, BC_ESC_WAIT)
        return false
    if !Press("Right", 100, BC_SKILL_ENTER) 
        return false
    if !Press("Down", 100, 700)
        return false
    if !Press("Enter", 100, BC_SKILL_SETTLE) 
        return false
    if !Press("Down", 80, 150)
        return false
    if !Press("Down", 80, 150)
        return false
    if !Press("Down", 80, 150)
        return false
    if !Press("Down", 80, 150)
        return false
    if !Press("Down", 80, 150)
        return false
    if !Press("Down", 80, 150)
        return false
    if !Press("Down", 80, 150)
        return false
    if !Press("Enter", 80, BC_SKILL_APPLY)
        return false
    if !Press("Enter", 80, BC_SKILL_APPLY2) 
        return false
    if !Press("Right", 80, 250)
        return false
    if !Press("Enter", 80, 600)
        return false
    if !Press("Up", 80, 250)
        return false
    if !Press("Enter", 80, 600)
        return false
    if !Press("Up", 80, 250)
        return false
    if !Press("Enter", 80, 600)
        return false
    if !Press("Up", 80, 250)
        return false
    if !Press("Enter", 80, 600)
        return false
    if !Press("Left", 80, 250)
        return false
    if !Press("Enter", 80, 600)
        return false
    if !Press("Esc", 80, BC_ESC_FINAL)
        return false
    if !Press("Esc", 80, BC_ESC_FINAL2) 
         return false
    if !Press("Left", 80, 0)
        return false
    return true
}

; ══════════════════════════════════════════════════════════════
;  F9  W 循环（再按停止）
; ══════════════════════════════════════════════════════════════
ToggleW(*) {
    global wRunning, GameHwnd
    if wRunning {
        wRunning := false
        GSend "{w up}"
        SetWStatus("■ 待机", "888888")
        Log("<<< W循环 停止")
        return
    }
    if AnyRunning() {
        Log("!!! 有其他循环运行中，请先停止")
        return
    }
    if !GameHwnd {
        FindGame()
        UpdateHwndLabel()
    }
    wRunning := true
    SetWStatus("▶ 后台运行", "00FF88")
    Log(">>> W循环 启动（后台，每次 " W_HOLD_MS // 1000 "s）")
    SetTimer WDoLoop, -1
}

WDoLoop() {
    global wRunning, W_HOLD_MS, W_PAUSE_MS
    while wRunning {
        GSend "{w down}"
        startTick := A_TickCount
        while wRunning && (A_TickCount - startTick < W_HOLD_MS)
            Sleep 50
        if !wRunning
            break
        GSend "{w up}"
        Sleep W_PAUSE_MS
    }
    GSend "{w up}"
    SetWStatus("■ 待机", "888888")
    Log("<<< W循环 结束")
}

; ══════════════════════════════════════════════════════════════
;  F8  熟练度循环（手动无限，再按停止）
; ══════════════════════════════════════════════════════════════
ToggleB(*) {
    global bRunning, bCurrentHeldKey, bLoopCount, bStartTime, GameHwnd, LoopCountLbl
    if bRunning {
        bRunning        := false
        bCurrentHeldKey := ""
        bStartTime      := 0
        GSend "{w up}"
        GSend "{Enter up}"
        GSend "{x up}"
        SetBStatus("■ 待机", "888888")
        SetPhase("—")
        SetCountdown("—")
        UpdateEfficiency()
        Log("<<< 熟练度循环 手动停止")
        return
    }
    if AnyRunning() {
        Log("!!! 有其他循环运行中，请先停止")
        return
    }
    if !GameHwnd {
        FindGame()
        UpdateHwndLabel()
        if !GameHwnd {
            Log("!!! 未找到游戏窗口，无法启动")
            return
        }
    }
    bLoopCount      := 0
    bCurrentHeldKey := ""
    bStartTime      := A_TickCount
    bRunning        := true
    LoopCountLbl.Value := "0"
    UpdateEfficiency()
    SetBStatus("▶ 后台运行", "00FF88")
    Log(">>> 熟练度循环 启动（手动无限）")
    SetTimer BDoLoop, -1
}

BDoLoop() {
    global bRunning, bCurrentHeldKey, bLoopCount, LoopCountLbl, ElapsedLbl
    global MA_INIT_WAIT, MA_DRIVE_MS, MA_DRIVE_EXTRA, MA_SETTLE_MS
    while bRunning {
        bLoopCount++
        LoopCountLbl.Value := bLoopCount
        Log("── 第 " bLoopCount " 轮 ──")
        if !RunMasteryBody()
            break
        UpdateEfficiency()
        Log("  效率 → " bLoopCount " 轮 / " ElapsedLbl.Value)
    }
    bCurrentHeldKey := ""
    GSend "{w up}"
    GSend "{Enter up}"
    GSend "{x up}"
    SetPhase("—")
    SetCountdown("—")
    UpdateEfficiency()
    bRunning := false
    SetBStatus("■ 待机", "888888")
    Log("<<< 熟练度循环 结束，按键已释放")
}

; 熟练度单轮循环体（供手动和自动共用）
RunMasteryBody() {
    global bRunning, bCurrentHeldKey
    global MA_INIT_WAIT, MA_DRIVE_MS, MA_DRIVE_EXTRA, MA_SETTLE_MS

    SetPhase("确认")
    bCurrentHeldKey := "Enter"
    GSend "{Enter down}"
    if !InterruptSleep(100) {
        GSend "{Enter up}"
        bCurrentHeldKey := ""
        return false
    }
    GSend "{Enter up}"
    bCurrentHeldKey := ""

    SetPhase("等待进入 " MA_INIT_WAIT // 1000 "s")
    if !InterruptSleep(MA_INIT_WAIT)
        return false

    SetPhase("W 油门 " MA_DRIVE_MS // 1000 "s")
    bCurrentHeldKey := "w"
    GSend "{w down}"
    if !InterruptSleep(MA_DRIVE_MS) {
        GSend "{w up}"
        GSend "{Enter up}"
        bCurrentHeldKey := ""
        return false
    }
    GSend "{Enter up}"

    SetPhase("继续开 " MA_DRIVE_EXTRA // 1000 "s")
    bCurrentHeldKey := "w"
    if !InterruptSleep(MA_DRIVE_EXTRA) {
        GSend "{w up}"
        bCurrentHeldKey := ""
        return false
    }
    GSend "{w up}"
    bCurrentHeldKey := ""

    ; ── 等待结算画面出现（检测底部中央像素变为暗灰色）────────
    ; 目标色：暗灰 avg亮度 0x18~0x50，RGB接近（灰色调）
    ; 超过20秒则跳过X操作直接进结算
    SetPhase("等待结算画面")
    waitStart := A_TickCount
    gotResult := false
    loop {
        if !bRunning
            return false
        try WinGetClientPos(&_cx, &_cy, &_cw, &_ch, "ahk_id " GameHwnd)
        catch {
            gotResult := true
            break
        }
        col := GetWindowPixelColor(GameHwnd, _cw // 2, _ch - 1)
        r   := (col >> 16) & 0xFF
        g   := (col >>  8) & 0xFF
        b   :=  col        & 0xFF
        avg := (r + g + b) // 3
        if avg > 0x18 && avg < 0x50 && Abs(r - g) < 20 && Abs(g - b) < 20 {
            Log("  ✓ 检测到结算画面 RGB=(" r "," g "," b ")")
            gotResult := true
            Sleep 200
            break
        }
        elapsed := A_TickCount - waitStart
        SetCountdown(Round((15000 - elapsed) / 1000) "s")
        if elapsed > 15000 {
            Log("  ⚠ 结算画面等待超时(20s)，跳过X操作直接结算")
            break
        }
        Sleep 100
    }
    if !bRunning
        return false

    if gotResult {
        ; 正常流程：X 操作 + 前两次 Enter
        SetPhase("X 操作")
        bCurrentHeldKey := "x"
        GSend "{x down}"
        if !InterruptSleep(100) {
            GSend "{x up}"
            bCurrentHeldKey := ""
            return false
        }
        GSend "{x up}"
        bCurrentHeldKey := ""
        if !InterruptSleep(100)
            return false

        SetPhase("连按确认")
        GSend "{Enter down}"
        Sleep 100
        GSend "{Enter up}"
        Sleep 100
        GSend "{Enter down}"
        Sleep 100
        GSend "{Enter up}"
        Sleep 100
    }

    ; 超时或正常流程都执行：ESC → Left → Enter×2 → 等待结算
    GSend "{ESC down}"
    Sleep 100
    GSend "{ESC up}"
    Sleep 800
    GSend "{Left down}"
    Sleep 100
    GSend "{Left up}"
    Sleep 400
    GSend "{Enter down}"
    Sleep 100
    GSend "{Enter up}"
    Sleep 400
    GSend "{Enter down}"
    Sleep 100
    GSend "{Enter up}"

    SetPhase("等待结算 " MA_SETTLE_MS // 1000 "s")
    bCurrentHeldKey := "Enter"
    if !InterruptSleep(MA_SETTLE_MS) {
        GSend "{Enter up}"
        bCurrentHeldKey := ""
        return false
    }
    GSend "{Enter up}"
    bCurrentHeldKey := ""
    Sleep 150

    ; ── 等待 Horizon Festival 加载画面消失 ───────────────────
    ; 采样屏幕正中央5个点，检测青绿/粉红加载画面
    ; 青绿(teal): R<100 && G>130 && B>100
    ; 粉红(pink): R>160 && G<100 && B>60
    ; 任意一点命中则继续等待，直到画面消失
    SetPhase("等待加载画面消失")
    loop {
        if !bRunning
            return false
        try WinGetClientPos(&_lx, &_ly, &_lw, &_lh, "ahk_id " GameHwnd)
        catch
            break

        px := _lw // 2
        py := _lh // 2
        onLoadScreen := false
        loop 5 {
            sx  := px - 40 + (A_Index - 1) * 20   ; x: center-40~center+40
            col := GetWindowPixelColor(GameHwnd, sx, py)
            r   := (col >> 16) & 0xFF
            g   := (col >>  8) & 0xFF
            b   :=  col        & 0xFF
            isTeal := r < 100 && g > 130 && b > 100
            isPink := r > 160 && g < 100 && b > 60
            if isTeal || isPink {
                onLoadScreen := true
                Log("  … 加载画面中 [" A_Index "] RGB=(" r "," g "," b ")")
                break
            }
        }
        if !onLoadScreen {
            Log("  ✓ 加载画面已消失，进入下一轮")
            Sleep 200
            break
        }
        Sleep 100
    }
    return true
}

; ══════════════════════════════════════════════════════════════
;  导航引擎（NavK / RunNavSeq）
; ══════════════════════════════════════════════════════════════
NavWait(ms) {
    global navRunning
    deadline := A_TickCount + ms
    while A_TickCount < deadline {
        if !navRunning
            return false
        Sleep Min(30, deadline - A_TickCount)
    }
    return true
}

NavK(key, holdMs, delayMs) {
    global navRunning
    if !navRunning
        return false
    GSend "{" key " down}"
    if !NavWait(holdMs) {
        GSend "{" key " up}"
        return false
    }
    GSend "{" key " up}"
    return NavWait(delayMs)
}

RunNavSeq(seq) {
    global navRunning, navStepLbl
    for i, step in seq {
        navStepLbl.Value := i "/" seq.Length " → " step[1]
        Log("  导航步骤 " i "/" seq.Length " → [" step[1] "]")
        if !NavK(step[1], step[2], step[3]) {
            Log("  !!! 导航步骤 " i " 中断")
            navStepLbl.Value := "中断"
            return false
        }
    }
    navStepLbl.Value := "完成"
    return true
}

; ══════════════════════════════════════════════════════════════
;  F6  调试: 蓝图→车库 导航
; ══════════════════════════════════════════════════════════════
ToggleNavMTG(*) {
    global navRunning, SEQ_MTG
    if navRunning {
        navRunning := false
        SetNavStatus("■ 已停止", "888888")
        Log("<<< 蓝图→车库 手动停止")
        return
    }
    if AnyRunning() {
        Log("!!! 有其他循环运行中，请先停止")
        return
    }
    if !GameHwnd {
        FindGame()
        UpdateHwndLabel()
        if !GameHwnd {
            Log("!!! 未找到游戏窗口")
            return
        }
    }
    navRunning := true
    SetNavStatus("▶ 蓝图→车库", "00FF88")
    Log(">>> 导航启动: 蓝图→车库")
    SetTimer NavMTGRun, -1
}

NavMTGRun() {
    global navRunning, SEQ_MTG
    RunNavSeq(SEQ_MTG)
    navRunning := false
    SetNavStatus("■ 待机", "888888")
    Log("--- 蓝图→车库 完成 ---")
}

; ══════════════════════════════════════════════════════════════
;  F7  调试: 车库→蓝图 导航
; ══════════════════════════════════════════════════════════════
ToggleNavGTM(*) {
    global navRunning, SEQ_GTM
    if navRunning {
        navRunning := false
        SetNavStatus("■ 已停止", "888888")
        Log("<<< 车库→蓝图 手动停止")
        return
    }
    if AnyRunning() {
        Log("!!! 有其他循环运行中，请先停止")
        return
    }
    if !GameHwnd {
        FindGame()
        UpdateHwndLabel()
        if !GameHwnd {
            Log("!!! 未找到游戏窗口")
            return
        }
    }
    navRunning := true
    SetNavStatus("▶ 车库→蓝图", "00FF88")
    Log(">>> 导航启动: 车库→蓝图")
    SetTimer NavGTMRun, -1
}

NavGTMRun() {
    global navRunning, SEQ_GTM
    RunNavSeq(SEQ_GTM)
    navRunning := false
    SetNavStatus("■ 待机", "888888")
    Log("--- 车库→蓝图 完成 ---")
}

; ══════════════════════════════════════════════════════════════
;  F5  自动大循环（再按停止）
; ══════════════════════════════════════════════════════════════
ToggleAuto(*) {
    global autoRunning, bRunning, bcRunning, navRunning
    global autoCycleLbl, autoPhaseLbl, GameHwnd
    if autoRunning {
        ; 停止：把所有子循环的 running 旗标也关掉
        autoRunning := false
        bRunning    := false
        bcRunning   := false
        navRunning  := false
        GSend "{w up}"
        GSend "{Enter up}"
        GSend "{x up}"
        SetAutoStatus("■ 已停止", "888888")
        autoPhaseLbl.Value := "—"
        SetNavStatus("■ 待机", "888888")
        SetBStatus("■ 待机", "888888")
        SetBcStatus("■ 待机", "888888")
        Log("<<< 自动大循环 手动停止")
        return
    }
    if AnyRunning() {
        Log("!!! 有其他循环运行中，请先停止")
        return
    }
    if !GameHwnd {
        FindGame()
        UpdateHwndLabel()
        if !GameHwnd {
            Log("!!! 未找到游戏窗口，无法启动")
            return
        }
    }
    autoRunning := true
    autoCycleLbl.Value := "0"
    autoPhaseLbl.Value := "启动中..."
    SetAutoStatus("▶ 运行中", "00FF88")
    Log(">>> 自动大循环 启动")
    Log("    熟练度 " AUTO_MASTERY_LOOPS " 轮 → 蓝图→车库 → 买车 " AUTO_BUYCAR_TIMES " 次 → 车库→蓝图 → 循环")
    SetTimer AutoBigLoop, -1
}

AutoBigLoop() {
    global autoRunning, autoCycle, autoPhaseLbl, autoCycleLbl
    global bRunning, bCurrentHeldKey, bLoopCount, bStartTime, LoopCountLbl, ElapsedLbl
    global bcRunning, bcLoopCount, bcTotal, bcStartTime, bcProgressLbl, bcTimerLbl
    global navRunning
    global SEQ_MTG, SEQ_GTM
    global AUTO_MASTERY_LOOPS, AUTO_BUYCAR_TIMES
    global MA_INIT_WAIT, MA_DRIVE_MS, MA_DRIVE_EXTRA, MA_SETTLE_MS

    autoCycle := 0

    while autoRunning {
        autoCycle++
        autoCycleLbl.Value := autoCycle
        Log("╔══ 自动大循环 第 " autoCycle " 周期开始 ══╗")
        if autoCycle > 1 {
            autoPhaseLbl.Value := "等待蓝图页面稳定..."
            Log("  等待蓝图页面稳定 5s（防止首圈打空）")
            Sleep 5000
            if !autoRunning
            break
        }
        ; ────────────────────────────────────────────────────
        ;  Phase 1: 刷熟练度 AUTO_MASTERY_LOOPS 轮
        ; ────────────────────────────────────────────────────
        Log(">>> Phase 1: 刷熟练度 " AUTO_MASTERY_LOOPS " 轮")
        bLoopCount      := 0
        bCurrentHeldKey := ""
        bStartTime      := A_TickCount
        bRunning        := true
        LoopCountLbl.Value := "0"
        UpdateEfficiency()
        SetBStatus("▶ 后台运行", "00FF88")

        while bRunning && autoRunning && bLoopCount < AUTO_MASTERY_LOOPS {
            bLoopCount++
            LoopCountLbl.Value := bLoopCount
            autoPhaseLbl.Value := "刷熟练度 " bLoopCount "/" AUTO_MASTERY_LOOPS
            Log("── [自动] 熟练度第 " bLoopCount "/" AUTO_MASTERY_LOOPS " 轮 ──")
            if !RunMasteryBody() {
                Log("  !!! 熟练度中断")
                break
            }
            UpdateEfficiency()
        }

        bCurrentHeldKey := ""
        GSend "{w up}"
        GSend "{Enter up}"
        GSend "{x up}"
        SetPhase("—")
        SetCountdown("—")
        UpdateEfficiency()
        bRunning := false
        SetBStatus("■ 待机", "888888")

        if !autoRunning
            break
        if bLoopCount < AUTO_MASTERY_LOOPS {
            Log("!!! 熟练度未完成，自动大循环中止")
            break
        }
        Log("✓ 熟练度完成 " AUTO_MASTERY_LOOPS " 轮")

        ; ────────────────────────────────────────────────────
        ;  Phase 2: 蓝图 → 车库
        ; ────────────────────────────────────────────────────
        Log(">>> Phase 2: 导航 蓝图→车库")
        autoPhaseLbl.Value := "导航: 蓝图→车库"
        navRunning := true
        SetNavStatus("▶ 蓝图→车库", "00FF88")
        ok := RunNavSeq(SEQ_MTG)
        navRunning := false
        SetNavStatus("■ 待机", "888888")
        if !ok || !autoRunning
            break
        Log("✓ 导航完成 蓝图→车库")

        ; ────────────────────────────────────────────────────
        ;  Phase 3: 买车 + 加点 AUTO_BUYCAR_TIMES 次
        ; ────────────────────────────────────────────────────
        Log(">>> Phase 3: 买车加点 " AUTO_BUYCAR_TIMES " 次")
        bcLoopCount := 0
        bcTotal     := AUTO_BUYCAR_TIMES
        bcRunning   := true
        bcStartTime := A_TickCount
        bcTimerLbl.Value    := "00:00"
        bcProgressLbl.Value := "0 / " AUTO_BUYCAR_TIMES
        SetBcStatus("▶ 后台运行", "00FF88")
        SetTimer UpdateBcTimer, 1000

        loop AUTO_BUYCAR_TIMES {
            if !bcRunning || !autoRunning
                break
            bcLoopCount         := A_Index
            bcProgressLbl.Value := bcLoopCount " / " AUTO_BUYCAR_TIMES
            autoPhaseLbl.Value  := "买车加点 " bcLoopCount "/" AUTO_BUYCAR_TIMES
            Log("=== [自动] 买车第 " bcLoopCount "/" AUTO_BUYCAR_TIMES " 次 ===")
            if !RunBuyCarBody() {
                Log("!!! 买车中断")
                break
            }
            Log("=== [自动] 买车第 " bcLoopCount " 次完成 ===")
        }

        SetTimer UpdateBcTimer, 0
        done := bcLoopCount >= AUTO_BUYCAR_TIMES
        bcRunning := false
        SetBcStatus("■ 待机", "888888")
        bcProgressLbl.Value := bcLoopCount " / " AUTO_BUYCAR_TIMES

        if !autoRunning
            break
        if !done {
            Log("!!! 买车未完成，自动大循环中止")
            break
        }
        Log("✓ 买车加点完成 " AUTO_BUYCAR_TIMES " 次")

        ; ────────────────────────────────────────────────────
        ;  Phase 4: 车库 → 蓝图
        ; ────────────────────────────────────────────────────
        Log(">>> Phase 4: 导航 车库→蓝图")
        autoPhaseLbl.Value := "导航: 车库→蓝图"
        navRunning := true
        SetNavStatus("▶ 车库→蓝图", "00FF88")
        ok := RunNavSeq(SEQ_GTM)
        navRunning := false
        SetNavStatus("■ 待机", "888888")
        if !ok || !autoRunning
            break
        Log("✓ 导航完成 车库→蓝图")

        Log("╚══ 第 " autoCycle " 周期完成 ══╝")
    }

    ; 全局清理
    autoRunning := false
    bRunning    := false
    bcRunning   := false
    navRunning  := false
    GSend "{w up}"
    GSend "{Enter up}"
    GSend "{x up}"
    SetPhase("—")
    SetCountdown("—")
    UpdateEfficiency()
    SetTimer UpdateBcTimer, 0
    SetBStatus("■ 待机", "888888")
    SetBcStatus("■ 待机", "888888")
    SetNavStatus("■ 待机", "888888")
    autoPhaseLbl.Value := "—"
    SetAutoStatus("■ 待机", "888888")
    Log("<<< 自动大循环 结束，共完成 " autoCycle " 个周期")
}
