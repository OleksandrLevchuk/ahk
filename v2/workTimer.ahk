;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; COMPLETE TASKS
; get the time to reset every day
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; TO DO LIST
; fix the app not saving upon exit
; make the "Rename project" button work
; make the app save upon exiting
; use A_TickCount to determine how accurate the time measurement is
; make the app save periodically
; allow user to reverse the progress bar
; fix the drag / button click bugging out sometimes
; fix menu separators when deleting all projects
; make the exit button work
; make the minimize button work
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; GLOBALS
#NoTrayIcon
CoordMode "Mouse", "Screen" ; make mouse coordinates absolute on the screen, instead of relative to "window"
Array.Prototype.DefineProp('destruct', { Call: destruct }) ; allows [1,2,3].destruct(&one,&two,&three)
INI_PATH := A_WorkingDir "\settings.ini" ; it's a constant :)
WM_ON_DRAG := 0x201 ; window manager message when user starts dragging
PROJECT_UPDATE_RATE := 60 ; how often project time gets updated. preferably 60 seconds
TIME_SPEED := 1 ; makes time this many times faster, keep it to 1 unless testing
PROGRESS_REVERSED := true

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; LOAD SETTINGS
if (FileExist(INI_PATH) and not GetKeyState('shift')) ; settings are found on disk
    settings := strToObj(FileRead(INI_PATH)) ; load settings
else { ; settings aren't found
    settings := { ; so load in these default settings
        date: 0,
        time: 0,
        chunk: 540,
        isRunning: false,
        project: "",
        projectToday: 0,
        projectTotal: 0,
        x: A_ScreenWidth / 2,
        y: A_ScreenHeight / 2,
        w: 250,
        h: 30,
        projects: {
            test_project_1: {
                timeTotal: 0,
                timeToday: 0
            }
        },
        pastDays: {}
    }
    FileAppend objToStr(settings), INI_PATH
}
date := FormatTime(,'yyMMdd')
if not date == settings.date { ; the real date isn't the same as the stored one, which means it's a next day
    settings.pastDays.%settings.date% := Round( settings.time / 60 ) ; in minutes
    for name, project in settings.projects.OwnProps()
        project.timeToday := 0
    settings.date := date
    settings.time := 0
}


;;;;;;;;;;;;;;;;;;;;;;;;;;;; MAIN WINDOW INTERFACE
wtimer := Gui("+AlwaysOnTop +ToolWindow -Caption", "Work Timer")
wtimer.SetFont('s9', 'Verdana')

wtimer.progressWidth := settings.w - settings.h
wtimer.progress := wtimer.Add("Progress", "Smooth x0 y0 w" wtimer.progressWidth " h" settings.h " Range0-" settings.chunk, 0)
wtimer.progress.OnEvent("ContextMenu", (*) => (wtimer.menu.Show()))

wtimer.textCtrl := wtimer.Add("Text", "center +BackgroundTrans x0 y7 w" wtimer.progressWidth " h" settings.h)
wtimer.startBtn := wtimer.Add("Button", "x" wtimer.progressWidth " y0 w" settings.h " h" settings.h, ">")
wtimer.startBtn.OnEvent("Click", onClickStart)
updateUI()
wtimer.Show("w" settings.w " h" settings.h " x" settings.x " y" settings.y)

onClickStart(*) {
    settings.isRunning := not settings.isRunning
    if settings.isRunning
        timerStart()
    else
        timerPause()
}
if settings.isRunning
    timerStart()
timerStart() {
    wtimer.startBtn.Text := "||"
    SetTimer timerFunc, 1000 / TIME_SPEED
}
timerPause() {
    wtimer.startBtn.Text := ">"
    SetTimer timerFunc, 0
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; CONTEXT MENU
wtimer.menu := Menu()
menuItems := ["Reload", "Reset", "Progress bar duration", "Minimize", "Exit", false, "Add project", "Rename project", "Remove project"]
if ObjOwnPropCount(settings.projects) ; if there are projects to load
    menuItems.Push(false) ; add a separator to the menu before loading the projects
for k, v in settings.projects.OwnProps()
    menuItems.Push(StrReplace(k, '_', ' '))
for v in menuItems
    if (v)
        wtimer.menu.Add(v, MenuHandler)
    else
        wtimer.menu.Add()
if settings.project
    wtimer.menu.Check(settings.project)
else
    wtimer.menu.Disable('Remove project')

MenuHandler(item, *) {
    switchProject(project) {
        saveProject()
        wtimer.menu.Check(project)
        settings.project := project
        project := StrReplace(project, ' ', '_') ; can't have spaces in key names
        settings.projectToday := settings.projects.%project%.timeToday
        settings.projectTotal := settings.projects.%project%.timeTotal
        wtimer.menu.Enable('Remove project')
        updateUI()
    }
    saveProject(project := settings.project) {
        if not project
            return
        wtimer.menu.Uncheck(project)
        settings.project := ""
        project := StrReplace(project, ' ', '_') ; can't have spaces in key names
        settings.projects.%project% := {
            timeToday: Round(settings.projectToday), ; round, in case the project time updates more often than every minute
            timeTotal: Round(settings.projectTotal)
        }
        wtimer.menu.Disable('Remove project')
    }

    if (item == "Reload") {
        FileDelete(INI_PATH)
        FileAppend(objToStr(settings), INI_PATH)
        Sleep(100)
        Reload()
    } else if (item == "Reset") {
        FileDelete(INI_PATH)
        Reload()
    } else if (item == "Progress bar duration") {
        input := InputBox("Currently it's " Floor(settings.chunk / 60) " minutes", 'The time it takes for the bar to fill up')
        if not input.Result == 'OK' or not IsNumber(input.value)
            return
        settings.chunk := input.Value * 60
        wtimer.progress.Opt('Range0-' settings.chunk)
        updateUI()
    } else if (item == "Add project") {
        obj := InputBox()
        if ( not obj.Result == "OK") ; user aborted creating a new project
            return ; so we stop too
        project := Trim(obj.Value, ' ')
        if not project
            return
        found := false
        for k, v in settings.projects.OwnProps() ; check the already existing projects
            if (k == project) ; if such a project is found
                found := true
        if not found {
            wtimer.menu.Add(project, MenuHandler)
            settings.projects.%StrReplace(project, ' ', '_')% := { timeTotal: 0, timeToday: 0 }
        }
        switchProject(project)
    } else if (item == "Rename project") {
        MsgBox "FIX ME"
    } else if (item == "Remove project") {
        wtimer.menu.Disable('Remove project')
        wtimer.menu.Delete(settings.project)
        project := StrReplace(settings.project, ' ', '_')
        settings.projects.DeleteProp(project)
        settings.project := ""
        updateUI()
    } else { ; user clicked on a project
        if item == settings.project {
            saveProject()
            updateUI()
        } else {
            switchProject(item)
        }
    }
}

OnMessage(WM_ON_DRAG, onDrag) ; enable dragging
onDrag(*) {
    drag := false
    MouseGetPos(&mx, &my)
    while GetKeyState('lbutton') {
        sleep 40
        MouseGetPos(&mx2, &my2)
        if distance(mx, my, mx2, my2) > 5 {
            PostMessage(0xA1, 2)
            drag := true
            break
        }
    }
    if not drag
        return
    KeyWait("LButton")
    ; MsgBox mx2 " " my2 ,,'T3'
    wtimer.GetPos(&x, &y)
    settings.x := x
    settings.y := y
}
timerFunc() {
    settings.time++
    if not Mod(settings.time, PROJECT_UPDATE_RATE) {
        settings.projectToday += PROJECT_UPDATE_RATE / 60
        settings.projectTotal += PROJECT_UPDATE_RATE / 60
    }
    updateUI()
}
updateUI() {
    if PROGRESS_REVERSED
        wtimer.progress.Value := settings.chunk - Mod(settings.time, settings.chunk)
    else
        wtimer.progress.Value := Mod(settings.time, settings.chunk)
    if not settings.project
        wtimer.textCtrl.Text := FormatSeconds(settings.time)
    else
        wtimer.textCtrl.Text := FormatSeconds(settings.time) "  "
            . Format("{1:0.1f}", settings.projectToday / 60) "h today  "
            . Format("{1:0.1f}", settings.projectTotal / 60) "h total"
}
FormatSeconds(NumberOfSeconds) {
    return NumberOfSeconds // 3600 ":" FormatTime(DateAdd(19990101, NumberOfSeconds, "Seconds"), "mm:ss")
}
concat(result, args*) {
    loop args.Length {
        result := result . "  " . args[A_Index]
    }
    return result
}
tip(words*) {
    ToolTip(concat(words*))
    sleep 3000
    ToolTip()
}
distance(x, y, x2, y2) {
    dist := Sqrt((x - x2) ** 2 + (y - y2) ** 2)
    return dist
}
destruct(thisArray, VarRefs*) {
    itemCount := thisArray.Length
    varCount := VarRefs.Length
    Loop Min(itemCount, varCount) {
        i := A_Index ; only assign if
        if (VarRefs.Has(i) && thisArray.Has(i)) ; a variable was provided, and a value exists(ie its not 'undefined')
            %VarRefs[i]% := thisArray[i]
    }

    Rest := []
    if (varCount >= itemCount) ; u asked for as much or more variables than there were array
        return Rest ; elements, so the is no Rest. return an empty array instead
    restCount := itemCount - varCount  ; setting the Length pre-fills the Rest array with undefineds, which
    Rest.Length := restCount ; is needed in case the Original array also contained undefineds

    Loop restCount {
        ++i
        if thisArray.Has(i) ; only assign if a value exists
            Rest[A_Index] := thisArray[i]
        ; otherwise, it was undefined, so leave it undefined
    }
    return Rest
}
StrRepeat(Str, Count) {
    Return StrReplace(Format("{:0" Count "}", ""), 0, Str)
}
objToStr(obj, nestLevel := 1, indent := "    ") {
    result := "{`n"
    for k, v in obj.OwnProps() {
        if IsObject(v) {
            if ObjOwnPropCount(v)
                v := objToStr(v, nestLevel + 1)
            else
                v := "{}"
        } else if not IsNumber(v)
            v := '"' v '"'
        result := result StrRepeat(indent, nestLevel) k ": " v ",`n"
    }
    return SubStr(result, 1, StrLen(result) - 2) "`n" StrRepeat(indent, nestLevel - 1) "}"
}
strToObj(str, &out := 0) {
    obj := {}
    str := Trim(str, "{`n")
    nLinesToSkip := 0
    loop parse, str, "`n" {
        if nLinesToSkip {
            nLinesToSkip--
            continue
        }
        StrSplit(A_LoopField, ":", '", ').destruct(&key, &val)
        if key == "}" {
            out := A_Index
            return obj
        } else if val == "{"
            obj.%key% := strToObj(SubStr(str, InStr(str, '`n', , , A_Index)), &nLinesToSkip)
        else if val == "{}"
            obj.%key% := {}
        else
            obj.%key% := val
        ; MsgBox 'line ' A_Index ':  ' key '  ' val
    }
}