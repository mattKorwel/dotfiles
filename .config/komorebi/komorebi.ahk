#Requires AutoHotkey v2.0
#SingleInstance Force

; --- Configuration ---
Komorebic(args) {
    try {
        Run("komorebic.exe " . args, , "Hide")
    } catch Error as e {
        ToolTip("Komorebic Error: " . e.Message)
        SetTimer(() => ToolTip(), -3000)
    }
}

; --- Center Stage Toggle ---
; Alt+F toggles layout. Always promotes focused window when entering.
global CenterStageActive := false
global MonocleActive := false

ToggleCenterStage() {
    global CenterStageActive
    if CenterStageActive {
        RunWait("komorebic.exe change-layout grid", , "Hide")
        RunWait("komorebic.exe layout-ratios -c 0.25 0.50 0.9", , "Hide")
        RunWait("komorebic.exe retile", , "Hide")
        CenterStageActive := false
        ToolTip("Grid Layout")
    } else {
        RunWait("komorebic.exe change-layout ultrawide-vertical-stack", , "Hide")
        RunWait("komorebic.exe layout-ratios -c 0.50 0.25 0.9", , "Hide")
        RunWait("komorebic.exe retile", , "Hide")
        Sleep(200)
        RunWait("komorebic.exe move left", , "Hide")
        RunWait("komorebic.exe move left", , "Hide")
        RunWait("komorebic.exe move right", , "Hide")
        CenterStageActive := true
        ToolTip("Center Stage")
    }
    SetTimer(() => ToolTip(), -2000)
}

; --- Navigation (I-K-J-L) ---
SmartNav(direction) {
    if WinActive("ahk_exe WindowsTerminal.exe") {
        if (direction == "up")
            Send("!{Up}")
        else if (direction == "down")
            Send("!{Down}")
        else if (direction == "left")
            Send("!{Left}")
        else if (direction == "right")
            Send("!{Right}")
    }
    Komorebic("focus " . direction)
}

; --- General ---
!+r:: {
    Komorebic("reload-configuration")
    ToolTip("Config Reloaded")
    SetTimer(() => ToolTip(), -2000)
}
!+q::Komorebic("stop")

; --- Focus ---
!i::SmartNav("up")
!k::SmartNav("down")
!j::SmartNav("left")
!l::SmartNav("right")

; --- Move ---
!+i::Komorebic("move up")
!+k::Komorebic("move down")
!+j::Komorebic("move left")
!+l::Komorebic("move right")

; --- Layout Control ---
!f::ToggleCenterStage()
!m:: {
    global MonocleActive
    if MonocleActive {
        RunWait("komorebic.exe monitor-work-area-offset 0 0 0 0 0", , "Hide")
        RunWait("komorebic.exe toggle-monocle", , "Hide")
        RunWait("komorebic.exe retile", , "Hide")
        MonocleActive := false
        ToolTip("Grid Layout")
    } else {
        RunWait("komorebic.exe toggle-monocle", , "Hide")
        RunWait("komorebic.exe monitor-work-area-offset 0 768 0 768 648", , "Hide")
        RunWait("komorebic.exe retile", , "Hide")
        MonocleActive := true
        ToolTip("Monocle")
    }
    SetTimer(() => ToolTip(), -2000)
}
!t::Komorebic("toggle-float")
!s::Komorebic("toggle-stack")
![::Komorebic("cycle-stack previous")
!]::Komorebic("cycle-stack next")

; --- Workspaces (Alt+6/7/8/9) ---
!6::Komorebic("focus-workspace 0")
!7::Komorebic("focus-workspace 1")
!8::Komorebic("focus-workspace 2")
!9::Komorebic("focus-workspace 3")
!+6::Komorebic("move-to-workspace 0")
!+7::Komorebic("move-to-workspace 1")
!+8::Komorebic("move-to-workspace 2")
!+9::Komorebic("move-to-workspace 3")

; --- Close ---
!y::Komorebic("close")

; --- Launchers ---
!Enter::Run("pwsh.exe")
!b::Run("zen.exe")

; --- Startup: ensure clean state ---
RunWait("komorebic.exe monitor-work-area-offset 0 0 0 0 0", , "Hide")
; If komorebi was left in monocle, exit it
RunWait(A_ComSpec . ' /c komorebic.exe state | findstr /C:"monocle_container" > "' . A_Temp . '\komo_mono.txt"', , "Hide")
try {
    mono := FileRead(A_Temp . "\komo_mono.txt")
    if !InStr(mono, "null")
        RunWait("komorebic.exe toggle-monocle", , "Hide")
}
RunWait("komorebic.exe retile", , "Hide")
ToolTip("Komorebi Grid Active (Alt+F = Center Stage)", 0, 0)
SetTimer(() => ToolTip(), -3000)
