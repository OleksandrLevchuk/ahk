;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; COMPLETE TASKS
; get the time to reset every day
; make the exit button work
; make the app save upon exiting
; make the "Rename project" button work
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; NOT TESTED
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; TO DO LIST
; make the progress color grey when inactive, lighter blue when active
; fix the project time starting from negative zero
; make the app save periodically
; fix the drag / button click bugging out sometimes
; fix menu separators when deleting all projects
; make the minimize button work
; allow user to reverse the progress bar
; add subtasks ???
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; GLOBALS
#NoTrayIcon
CoordMode "Mouse", "Screen" ; make mouse coordinates absolute on the screen, instead of relative to "window"
Array.Prototype.DefineProp('destruct', { Call: destruct }) ; allows [1,2,3].destruct(&one,&two,&three)
INI_PATH := A_WorkingDir "\settings.ini" ; it's a constant :)
WM_ON_DRAG := 0x201 ; window manager message when user starts dragging
OPT_VCENTER := 0x200 ; gui control center text vertically
TIME_SPEED := 1 ; makes time this many times faster, keep it to 1 unless testing
PROGRESS_REVERSED := true

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; LOAD SETTINGS
if (FileExist(INI_PATH) and not ( GetKeyState('shift') and GetKeyState('ctrl') and GetKeyState('alt'))) ; if settings are found on disk
    settings := strToObj(FileRead(INI_PATH)) ; load them
else { ; if settings aren't found ( or user holds SHIFT )
    settings := { ; load in these default settings:
        date: 0,
        time: 0,
        chunk: 54000,
        isRunning: false,
        project: "",
        x: A_ScreenWidth / 2,
        y: A_ScreenHeight / 2,
        projectsToday: {},
        projects: {
            test_project_1: 0
        },
        timeByDate: {},
    }
    FileAppend objToStr(settings), INI_PATH
}
date := FormatTime(, 'yyMMdd')
if not date == settings.date { ; the real date isn't the same as the stored one, which means it's a next day
    settings.timeByDate.%settings.date% := Round(settings.time / 60) ; save how much time you worked yesterday, convert from seconds to minutes
    for name, time in settings.projectsToday.OwnProps() ; dump yesterday's work on each project into storage
        settings.projects.%name% += Round(time / 60) ; convert from seconds to minutes
    settings.projectsToday := {} ; clear up the projects list
    settings.date := date
    settings.time := 0
}
time := settings.time
chunk := settings.chunk
project := settings.project
projectKey := StrReplace(project, ' ', '_')
projectToday := project and settings.projectsToday.HasOwnProp(projectKey) ? settings.projectsToday.%projectKey% : 0
projectTotal := project ? settings.projects.%projectKey% : 0


;;;;;;;;;;;;;;;;;;;;;;;;;;;; MAIN WINDOW INTERFACE
initUI() {
    global wtimer := Gui("+AlwaysOnTop +ToolWindow -Caption", "Work Timer")
    wtimer.SetFont('s8', 'Verdana')
    h := 30, w := 300
    global progress := wtimer.Add("Progress", "Smooth x0 y0 w" w - h " h" h " Range0-" chunk, chunk - Mod(time, chunk))
    progress.OnEvent("ContextMenu", (*) => (wtimer.menu.Show()))

    global textCtrl := wtimer.Add("Text", "center +BackgroundTrans x0 y0 w" w - h ' h' h)
    textCtrl.update := project ? textCtrlUpdateWithProject : textCtrlUpdateShort
    if not project
        textCtrl.Opt(OPT_VCENTER)
    textCtrl.update()

    wtimer.startBtn := wtimer.Add("Button", "x" w - h " y0 w" h " h" h, ">")
    wtimer.startBtn.OnEvent("Click", onClickStart)
    onClickStart(*) {
        settings.isRunning := not settings.isRunning
        if settings.isRunning
            timerStart()
        else
            timerPause()
    }
    wtimer.Show("w" w " h" h " x" settings.x " y" settings.y)
}
initUI()

if settings.isRunning
    timerStart()
timerStart() {
    wtimer.startBtn.Text := "||"
    SetTimer timerFunction, 1000 / TIME_SPEED
}
timerPause() {
    wtimer.startBtn.Text := ">"
    SetTimer timerFunction, 0
}
timerFunction() {
    global time += 1
    global projectToday += 1
    progress.Value := chunk - Mod(time, chunk)
    textCtrl.update()
}
textCtrlUpdateShort(*) {
    textCtrl.Text := FormatSeconds(time)
}
textCtrlUpdateWithProject(*) {
    t := projectToday / 3600
    textCtrl.Text := FormatSeconds(time) "  `n"
        . project ':  ' Round(t - 0.05, 1) "h today,  "
        . Round(t - 0.05, 1) "h total"
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
if project {
    wtimer.menu.Check(project)
} else {
    wtimer.menu.Disable('Remove project')
}

MenuHandler(item, *) {
    deselectProject() {
        global project := ""
        wtimer.menu.Disable('Remove project')
        textCtrl.Opt(OPT_VCENTER)
        textCtrl.update := textCtrlUpdateShort
        textCtrl.update()
    }
    switchProject(proj) {
        if project { ; there was another project active before now
            wtimer.menu.Uncheck(project) ; uncheck the previous project before switching
            settings.projectsToday.%projectKey% := projectToday ; save the previous project
        } else { ; there was no active project before
            wtimer.menu.Enable 'Remove project' ; so the remove button was disabled
            textCtrl.Opt('-' OPT_VCENTER)
            textCtrl.update := textCtrlUpdateWithProject
        }
        global project := proj
        global projectKey := StrReplace(project, ' ', '_') ; can't have spaces in key names
        global projectToday := settings.projectsToday.HasOwnProp(projectKey) ? settings.projectsToday.%projectKey% : 0
        wtimer.menu.Check(project)
        wtimer.menu.Enable('Remove project')
        textCtrl.update()
    }
    if (item == "Reload") {
        saveToDisk()
        Sleep(100)
        Reload()
    } else if (item == "Reset") {
        FileDelete(INI_PATH)
        Reload()
    } else if item == "Minimize" {
        MsgBox 'Fix me'
    } else if item == 'Exit' {
        ExitApp
    } else if (item == "Progress bar duration") {
        input := InputBox("Currently it's " Floor(settings.chunk / 60) " minutes", 'The time it takes for the bar to fill up')
        if not input.Result == 'OK' or not IsNumber(input.value)
            return
        global chunk := input.Value * 60
        progress.Opt('Range0-' chunk)
        progress.Value := chunk - Mod(time, chunk)
    } else if item == 'Add project' {
        input := InputBox()
        if not input.Value or not input.Result == "OK" ; user aborted creating a new project
            return ; so we stop too
        for k, v in settings.projects.OwnProps() ; check the already existing projects
            if k == input.value ; if such a project is found
                return switchProject(input.value)

        settings.projects.%StrReplace(input.Value, ' ', '_')% := 0
        wtimer.menu.Add input.value, MenuHandler
        switchProject(input.value)
    } else if item == 'Rename project' {
        input := InputBox()
        if not input.Result == 'OK' or input.value == project
            return ; user aborted renaming
        for k, v in settings.projects.OwnProps()
            if k == input.value
                return MsgBox("such project already exists")
        newProject := input.value
        newKey := strreplace(newProject, ' ', '_')
        settings.projects.%newKey% := settings.projects.%projectKey%
        settings.projects.DeleteProp(projectKey)
        settings.projectsToday.DeleteProp(projectKey)
        wtimer.menu.rename(project, newProject)
        global project := newProject
        global projectKey := newKey
        textCtrl.update()
    } else if (item == "Remove project") {
        wtimer.menu.Delete(project)
        settings.projects.DeleteProp(projectKey)
        settings.projectsToday.DeleteProp(projectKey)
        deselectProject()
    } else { ; user clicked on a project
        if item == project { ; user clicked on an already active project, so deacivate
            settings.projectsToday.%projectKey% := projectToday
            wtimer.menu.Uncheck(project)
            deselectProject()
        } else {
            switchProject(item)
        }
    }
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;; GARBAGE
saveToDisk(ExitReason := 0, ExitCode := 0) { ; OnExit functions must return non-zero to prevent exit.
    settings.time := time
    settings.chunk := chunk
    settings.project := project
    settings.projectsToday.%projectKey% := projectToday
    FileDelete(INI_PATH)
    FileAppend(objToStr(settings), INI_PATH)
}
OnExit(saveToDisk)
OnMessage(WM_ON_DRAG, onDrag) ; enable dragging
onDrag(wparam, lparam, msg, hwnd) {
    ; tip( wparam ' ' lparam ' ' msg ' ' hwnd)
    if not hwnd == progress.Hwnd
        return
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
;;;;;;;;;;;;;;;;;;;;;;;;;;;; UTILITY
FormatSeconds(NumberOfSeconds) {
    return NumberOfSeconds // 3600 ":" FormatTime(DateAdd(19990101, NumberOfSeconds, "Seconds"), "mm:ss")
}
concat(result, args*) {
    loop args.length
        result := result . "  " . args[A_Index]
    return result
}
tip(words*) {
    ToolTip(concat(words*))
    sleep 1000
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
    } ; otherwise, it was undefined, so leave it undefined
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
        else if key == '}{'
            MsgBox 'the weird key ' key ' just happened'
        else
            obj.%key% := val
        ; MsgBox 'line ' A_Index ':  ' key '  ' val
    }
}