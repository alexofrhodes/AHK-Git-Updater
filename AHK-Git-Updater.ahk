/*
    Project         : AHK-Git-Updater
    Description     : LIST git repositories, CHECK and PULL updates for selected items.
    Changelog       : 1.0.0 Initial release
-----------------------------------------------------------------------------------------
    Author          : Anastasiou Alex
    Gmail           : anastasioualex@gmail.com
    Github          : https://github.com/alexofrhodes/
    YouTube         : https://www.youtube.com/channel/@anastasioualex
*/

;---AUTO RUN-----------------------------------------------------------------------------

#SingleInstance Force
#Requires AutoHotkey v2
#Include include\Notify.ahk
#Include include\Class_LV_Colors.ahk
#Include include\StyleButton.ahk

#Include include\customTray.ahk
SetupTray()

global repos := []  
global reposToUpdate := [] 

OnMessage(0x404, AHK_NOTIFYICON)    
 

myGui := Gui("Resize")
MyGui.SetFont("q5 s11  ", "Consolas")
SB := MyGui.Add("StatusBar")

myGui.Title := "Github Repository Manager"

btnListRepos := myGui.Add("Button", "w150 y+70", "List Git Repos")
btnListRepos.OnEvent("Click", ListGitRepos)
StyleButton(btnListRepos, 0, "warning-round")

btnCheckForUpdates := myGui.Add("Button", "w150", "Check for Updates")
btnCheckForUpdates.OnEvent("Click", CheckForUpdates)
StyleButton(btnCheckForUpdates, 0, "info-round")

btnUpdateSelected:=myGui.Add("Button", "w150", "Update Selected")
btnUpdateSelected.OnEvent("Click", UpdateSelected)
StyleButton(btnUpdateSelected, 0, "success-round")

btnSelectAll := myGui.Add("Button", "w150", "Select All")
btnSelectAll.OnEvent("Click", SelectAll)
StyleButton(btnSelectAll, 0, "info-outline-round")

btnOpenGithub:=myGui.Add("Button", "w150 y+50", "Open on GitHub")
btnOpenGithub.OnEvent("Click", OpenOnGitHub)
StyleButton(btnOpenGithub, 0, "info-outline-round")

btnRepoFolder:=myGui.Add("Button", "w150", "Open Repo Folder")
btnRepoFolder.OnEvent("Click", OpenRepoFolder)
StyleButton(btnRepoFolder, 0, "warning-outline-round")

btnRepoFoldersTXT:=myGui.Add("Button", "w150", "Edit RepoFolders.txt")
btnRepoFoldersTXT.OnEvent("Click", OpenTxtFile)
StyleButton(btnRepoFoldersTXT, 0, "warning-outline-round")

btnScriptDir:=myGui.Add("Button", "w150", "Open A_ScriptDir")
btnScriptDir.OnEvent("Click", OpenScriptDir)
StyleButton(btnScriptDir, 0, "warning-outline-round")

btnDeleteLVtxt:=myGui.Add("Button", "w150 y+50", "Reset LV data")
btnDeleteLVtxt.OnEvent("Click", DeleteLVtxt)
StyleButton(btnDeleteLVtxt, 0, "critical-round")

btnClearFilter:=myGui.Add("Button", "y30 h5 section", "x")
btnClearFilter.OnEvent("Click", ClearFilter)
StyleButton(btnClearFilter, 0, "critical-round")

mygui.Add("Text","y10","Filter text")
myGui.Add("Edit", "vFilterText w150").OnEvent("Change", FilterListView)

mygui.Add("Text","y10","Filter by column")
myGui.Add("DropDownList", "vFilterColumn w150", ["Repository Path", "Owner", "Repo Name", "Updates","Any"]).OnEvent("Change", FilterListView)

myGUi["FilterColumn"].text := "Any"

myGui.Add("ListView", "xs vRepoListView r12 w1000", ["Repository Path", "Owner", "Repo Name", "Updates"])
ogcRepoListView := myGui["RepoListView"]


CLV := LV_Colors(ogcRepoListView)
If !IsObject(CLV) {
   MsgBox("Couldn't create a new LV_Colors object!", "ERROR", 16)
   ExitApp
}

clv.SetRowColorScheme(1)               ; alex
CLV.SelectionColors(selRowB,selRowT)   ; Set the colors for selected rows

CLV.AlternateRows(evenRowB, evenRowT)
ogcRepoListView.Opt("+Redraw")
ogcRepoListView.Focus()

LoadListView()

MyGui.OnEvent("Size", Gui_Size)
myGui.Show("AutoSize hide")
mygui.Show("Maximize")

;---END AUTO RUN-----------------------------------------------------------------------------


AHK_NOTIFYICON(wParam, lParam,*){
    if (lParam = 0x201) ; WM_LBUTTONDOWN
    {
        mygui.show
        return 0
    }
}

OpenTxtFile(*) {
    Run(A_ScriptDir "\settings\RepoFolders.txt")
}

OpenScriptDir(*) {
    Run(A_ScriptDir)
}

ListGitRepos(*) {
    global repos, ogcRepoListView
    ogcRepoListView.Delete()
    repos := []

    txtFile := A_ScriptDir "\settings\RepoFolders.txt"
    if !FileExist(txtFile) {
        Notify.Show('Error', 'RepoFolders.txt not found!', 'iconx',,, 'TC=black MC=black BC=75AEDC style=edge show=slideWest@250 hide=slideEast@250')        
        return
    }
    content := FileRead(txtFile, '`n')
    if (Trim(content) = "<Delete this comment and list a folder or folders, one in each line, containing repos at any depth>"){
        run txtFile
        return
    }

    folders := StrSplit(content, "`n")
    for folder in folders {
        folder := Trim(folder)
        if !DirExist(folder) {
            continue 
        }
        AddRepos(folder)
    }

    ogcRepoListView.opt("-redraw")
    for repo in repos {
        updateStatus := "N/A" 
        ogcRepoListView.Add(, repo.path, repo.owner, repo.name, updateStatus)
    }
    ogcRepoListView.ModifyCol()
    ogcRepoListView.ModifyCol(4,"AutoHdr")
    ogcRepoListView.opt("+redraw")
    mygui.move()
    SaveListView()
    sb.SetText(repos.length " of " repos.length " repos displayed.")
}

AddRepos(folder) {
    global repos

    if DirExist(folder "\.git") {
        repo := ParseGitInfo(folder)
        repos.Push(repo)
    } else {
        for subfolder in GetSubfolders(folder) {
            AddRepos(subfolder)
        }
    }
}

CheckForUpdates(*) {
    global repos, reposToUpdate, ogcRepoListView

    reposToUpdate := []
    Count := ogcRepoListView.GetCount("S")
    if (Count = 0) {
        Notify.Show('Alert', 'Please select at least one repository to check for updates.', 'icon!',,, 'TC=black MC=black BC=75AEDC style=edge show=slideWest@250 hide=slideEast@250')
        return
        ; SelectAll()
    }

    mNotifyGUI_Prog := Notify.Show('Checking ' count ' repos for Updates',,,,, 'dur=0 prog=w325 dgc=0')

    ProgressMax := count
    ProgressPos := 0


    RowNumber := 0  ; This causes the first loop iteration to start the search at the top of the list.
    Loop
    {
        RowNumber := ogcRepoListView.GetNext(RowNumber)  ; Resume the search at the row after that found by the previous iteration.
        if not RowNumber  
            break

        ProgressPos++
        ProgressValue := (ProgressPos / ProgressMax) * 100
        mNotifyGUI_Prog['prog'].Value := ProgressValue

        repoPath := ogcRepoListView.GetText(RowNumber, 1)
        for repo in repos {
            if (repo.path = repoPath) {
                if HasGitUpdates(repo.path) {
                    repo.updates := true
                    reposToUpdate.Push(repo)
                }else{
                    repo.updates := false
                }
                updateStatus := repo.updates ? "Yes" : "No"
                ogcRepoListView.Modify(RowNumber, "col4", updateStatus)
                break
            }
        }
    }    
    SaveListView() 

    Notify.Destroy(mNotifyGUI_Prog['hwnd'])
    Sleep(500)
    Notify.Show('Info', reposToUpdate.Length ' repositories found with updates.', 'iconi',,, 'TC=black MC=black BC=75AEDC style=edge show=slideWest@250 hide=slideEast@250')

}

OpenRepoFolder(*) {
    global ogcRepoListView, repos
    Count := ogcRepoListView.GetCount("S")
    if count > 1 || count = 0
    {
        Notify.Show('Info', 'Select one repo to open its folder.', 'iconi',,, 'TC=black MC=black BC=75AEDC style=edge show=slideWest@250 hide=slideEast@250')
        return
    }
    selectedRow := ogcRepoListView.GetNext(0)
    path := ogcRepoListView.GetText(selectedRow,1)
    Run(path)
}

OpenOnGitHub(*) {
    global ogcRepoListView, repos

    try
        selectedRow := ogcRepoListView.GetNext(0, "Focused")
    RowNumber := 0  ; This causes the first loop iteration to start the search at the top of the list.
    RowNumber := ogcRepoListView.GetNext(RowNumber)  ; Resume the search at the row after that found by the previous iteration.
    if not RowNumber  
    {
        Notify.Show('Alert', 'Please select a repository first.', 'icon!',,, 'TC=black MC=black BC=75AEDC style=edge show=slideWest@250 hide=slideEast@250')        
        return
    }
    url := "https://github.com/" ogcRepoListView.GetText(RowNumber,2) "/" ogcRepoListView.GetText(RowNumber,3)
    Run(url)
}

UpdateSelected(*) {
    global repos, ogcRepoListView

    selectedRepos := []
    Count := ogcRepoListView.GetCount("S")
    
    if Count = 0 {
        Notify.Show('Alert', 'Please select a repository first.', 'icon!',,, 'TC=black MC=black BC=75AEDC style=edge show=slideWest@250 hide=slideEast@250')
        return
    }
    ogcRepoListView.opt("-redraw")
    RowNumber := 0
    Loop
        {
            RowNumber := ogcRepoListView.GetNext(RowNumber)  ; Resume the search at the row after that found by the previous iteration.
            if not RowNumber  ; The above returned zero, so there are no more selected rows.
                break
            repoPath := ogcRepoListView.GetText(RowNumber, 1)
            ogcRepoListView.Modify(RowNumber, "col4", "No")
            for repo in repos {
                if (repo.path = repoPath) {
                    selectedRepos.Push(repo)
                    break
                }
            }    
        }    

    mNotifyGUI_Prog := Notify.Show('Updating ' selectedRepos.Length,,,,, 'dur=0 prog=w325 dgc=0')

    ProgressMax := selectedRepos.length
    ProgressPos := 0

    for repo in selectedRepos {
        ProgressPos++
        ProgressValue := (ProgressPos / ProgressMax) * 100
        mNotifyGUI_Prog['prog'].Value := ProgressValue
        RunWait('cmd.exe /c cd /d "' repo.path '" && git pull',, "Hide")
        repo.updates := false
    }
    ogcRepoListView.opt("+redraw")

    SaveListView()
    Notify.Destroy(mNotifyGUI_Prog['hwnd'])
    Sleep(500)
    Notify.Show('Info', 'Selected repositories updated.', 'iconi',,, 'TC=black MC=black BC=75AEDC style=edge show=slideWest@250 hide=slideEast@250')
}


SelectAll(*) {
    global ogcRepoListView
    ogcRepoListView.Modify(0, "+Select")
}


AddReposWithUpdates(folder) {
    global repos, reposToUpdate

    if DirExist(folder "\.git") {
        repo := ParseGitInfo(folder)
        if HasGitUpdates(folder) {
            repo.updates := true
            reposToUpdate.Push(repo)
        } else {
            repo.updates := false
        }
        repos.Push(repo)
    } else {
        for subfolder in GetSubfolders(folder) {
            AddReposWithUpdates(subfolder)
        }
    }
}
HasGitUpdates(folder) {
    cmd := 'cd /d "' folder '" && git status'
    output := RunCommand(cmd)
    pattern := "Your branch is behind 'origin/[^']+' by (\d+) commit"
    if RegExMatch(output, pattern, &match) {
        commitsBehind := match[1]
        return commitsBehind != "0"
    } else {
        return false
    }
}

RunCommand(command) {
    tempFile := A_Temp "\git_output.txt"
    try 
        FileDelete tempFile
    RunWait('cmd.exe /c ' command ' > "' tempFile '"', , 'Hide')
    output := FileRead(tempFile)
    return output
}


ParseGitInfo(folder) {
    repo := {}
    repo.path := folder
    repo.owner := "Unknown"
    repo.name := "Unknown"

    configPath := folder "\.git\config"
    content := FileRead(configPath)
    pattern := "url\s*=\s*(git@github.com:|https://github.com/)([^/]+)/([^/]+)\.git"

    if RegExMatch(content, pattern, &match) {
        repo.owner := match[2]
        repo.name := match[3]
    }
    return repo
}

GetSubfolders(folder) {
    subfolders := []
    Loop Files, folder "\*", "D" 
        subfolders.Push(A_LoopFileFullPath)
    return subfolders
}

FilterListView(*) {
    global ogcRepoListView, myGui, repos
    
    if (repos.Length = ogcRepoListView.GetCount()) AND (myGui["FilterText"].text = "")
        return

    ogcRepoListView.Delete()
    filterText := myGui["FilterText"].Value
    if filterText = ""
    {
        LoadListView
        return
    }
    comboboxIndex := myGui["FilterColumn"].Value
    file := A_ScriptDir "\Settings\ListViewData.txt"
    if !FileExist(file) {
        myGui["FilterText"].Value := ""  
        return
    }
    try {
        originalData := FileRead(file)
    } catch {
        MsgBox "Error reading the file: " file
        return
    }
    if (originalData = "") 
        return

    ogcRepoListView.opt("-Redraw")
    rows := StrSplit(originalData, "`n")  
    for rowIndex, row in rows {
        if (StrLen(Trim(row)) = 0) 
            continue

        columns := StrSplit(row, "`t") 
        matches := false

        if (myGui["FilterColumn"].text = "Any") {  
            if (InStr(row, filterText)) {
                matches := true
            }
        } else {
            selectedColumnIndex := comboboxIndex         
            if InStr(columns[selectedColumnIndex], filterText) {
                matches := true
            }
        }
        if (matches) {
            ogcRepoListView.Add("", columns*)
        }
    }
    ogcRepoListView.opt("+Redraw")

    ItemCount := ogcRepoListView.GetCount()
    sb.SetText(ItemCount " of " repos.length " repos displayed.")
}


SaveListView() {
    global ogcRepoListView, repos

    file := A_ScriptDir "\Settings\ListViewData.txt"
    try FileDelete(file)

    ; Build the entire content in memory
    fileContent := ""
    first := true  ; To track the first row

    for repo in repos {
        updateStatus := "N/A"
        try
            updateStatus := repo.updates ? "Yes" : "No"
        
        rowData := Join("`t", repo.path, repo.owner, repo.name, updateStatus)

        if !first  ; Add a newline before all rows except the first one
            fileContent .= "`n"
        else
            first := false  ; Mark that we've added the first row

        fileContent .= rowData
    }

    ; Write the full content at once
    FileAppend(fileContent, file)
}



LoadListView() {
    global ogcRepoListView, repos
    Repos := []
    ogcRepoListView.delete
    txtFile := A_ScriptDir "\settings\ListViewData.txt"
    if !FileExist(txtFile) {
        return
    }

    content := FileRead(txtFile, '`n')
    rows := StrSplit(content, "`n")

    for row in rows {
        columns := StrSplit(row, "`t")
        if (columns.length = 4) {
            repoPath := columns[1]  
            if DirExist(repoPath) {  
                ogcRepoListView.Add(, columns*)
                AddRepos(repoPath)
            }
        }
    }
    ogcRepoListView.ModifyCol()
    ogcRepoListView.ModifyCol(4,"AutoHdr")
    sb.SetText(repos.length " of " repos.length " repos displayed.")
}

Join(s, h, t*) {
    for _,x in t
        h .= s . x
    return h
}

Gui_Size(thisGui, MinMax, Width, Height)  
{
    if MinMax = -1  ; The window has been minimized. No action needed.
        return
    mygui["RepoListView"].GetPos(&X, &Y, &lvWidth, &lvHeight)
    mygui["RepoListView"].Move(,,  Width - 20 -x , Height - 40 -y)
}

DeleteLVtxt(*){
    if MsgBox('Will delete stored ListView data.`n Just run "List Repos" again to populate.',,"0x4") = "No"
        return
    file := A_ScriptDir "\Settings\ListViewData.txt"
    try FileDelete file
    ogcRepoListView.delete
}
ClearFilter(*){
    myGui["FilterText"].text := ""
    FilterListView()
}

Escape::ExitApp

















