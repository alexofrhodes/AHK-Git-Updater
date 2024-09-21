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
MyGui.SetFont("q5 s11 ", "Consolas")
SB := MyGui.Add("StatusBar")

myGui.Title := "Github Repository Manager"

btnListRepos := myGui.Add("Button", "w150 y+70", "List Git Repos")
btnListRepos.OnEvent("Click", ListGitRepos)
StyleButton(btnListRepos, 0, "info-round")

btnCheckForUpdates := myGui.Add("Button", "w150", "Check for Updates")
btnCheckForUpdates.OnEvent("Click", CheckForUpdates)
StyleButton(btnCheckForUpdates, 0, "info-round")

btnUpdateSelected:=myGui.Add("Button", "w150", "Update Selected")
btnUpdateSelected.OnEvent("Click", UpdateSelected)
StyleButton(btnUpdateSelected, 0, "info-round")

btnSelectAll := myGui.Add("Button", "w150 y+50", "Select All")
btnSelectAll.OnEvent("Click", SelectAll)
StyleButton(btnSelectAll, 0, "info-round")

btnRepoFolder:=myGui.Add("Button", "w150 y+50", "Open Repo Folder")
btnRepoFolder.OnEvent("Click", OpenRepoFolder)
StyleButton(btnRepoFolder, 0, "info-round")

btnOpenGithub:=myGui.Add("Button", "w150", "Open on GitHub")
btnOpenGithub.OnEvent("Click", OpenOnGitHub)
StyleButton(btnOpenGithub, 0, "info-round")

btnRepoFoldersTXT:=myGui.Add("Button", "w150 y+50", "Open RepoFolders.txt")
btnRepoFoldersTXT.OnEvent("Click", OpenTxtFile)
StyleButton(btnRepoFoldersTXT, 0, "info-round")

btnScriptDir:=myGui.Add("Button", "w150", "Open A_ScriptDir")
btnScriptDir.OnEvent("Click", OpenScriptDir)
StyleButton(btnScriptDir, 0, "info-round")


mygui.Add("Text","y10 section","Filter text")
myGui.Add("Edit", "vFilterText w150").OnEvent("Change", FilterListView)

mygui.Add("Text","ys","Filter by column")
myGui.Add("DropDownList", "vFilterColumn w150", ["Repository Path", "Owner", "Repo Name", "Updates","Any"]).OnEvent("Change", FilterListView)

myGUi["FilterColumn"].text := "Any"

myGui.Add("ListView", "xs vRepoListView r12 w1000", ["Repository Path", "Owner", "Repo Name", "Updates"])
ogcRepoListView := myGui["RepoListView"]


CLV := LV_Colors(ogcRepoListView)
If !IsObject(CLV) {
   MsgBox("Couldn't create a new LV_Colors object!", "ERROR", 16)
   ExitApp
}

clv.SetRowColorScheme(1)
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
    folders := StrSplit(content, "`n")
    for folder in folders {
        folder := Trim(folder)
        if !DirExist(folder) {
            continue 
        }
        AddRepos(folder)
    }

    for repo in repos {
        updateStatus := "N/A" 
        ogcRepoListView.Add(, repo.path, repo.owner, repo.name, updateStatus)
    }
    ogcRepoListView.ModifyCol()
    ogcRepoListView.ModifyCol(4,"AutoHdr")
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
    RowNumber := 0  ; This causes the first loop iteration to start the search at the top of the list.
    Loop
    {
        RowNumber := ogcRepoListView.GetNext(RowNumber)  ; Resume the search at the row after that found by the previous iteration.
        if not RowNumber  ; The above returned zero, so there are no more selected rows.
            break
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
    Notify.Show('Info', reposToUpdate.Length ' filtered repositories found with updates.', 'iconi',,, 'TC=black MC=black BC=75AEDC style=edge show=slideWest@250 hide=slideEast@250')
}

OpenRepoFolder(*) {
    global ogcRepoListView, repos
    Count := ogcRepoListView.GetCount("S")
    if count > 1
    {
        Notify.Show('Info', 'Select only one repo to open its folder.', 'iconi',,, 'TC=black MC=black BC=75AEDC style=edge show=slideWest@250 hide=slideEast@250')
        return
    }
    selectedRow := ogcRepoListView.GetNext(0)
    if selectedRow {
        repo := repos[selectedRow]
        Run(repo.path)
    } else {
        Notify.Show('Alert', 'Please select a repository first.', 'icon!',,, 'TC=black MC=black BC=75AEDC style=edge show=slideWest@250 hide=slideEast@250')        
    }
}

OpenOnGitHub(*) {
    global ogcRepoListView, repos

    selectedRow := ogcRepoListView.GetNext(0, "Focused")
    if selectedRow {
        repo := repos[selectedRow]
        if repo.owner != "Unknown" && repo.name != "Unknown" {
            url := "https://github.com/" repo.owner "/" repo.name
            Run(url)
        } else {
            MsgBox("Unable to determine GitHub URL for this repository.")
        }
    } else {
        Notify.Show('Alert', 'Please select a repository first.', 'icon!',,, 'TC=black MC=black BC=75AEDC style=edge show=slideWest@250 hide=slideEast@250')        
    }
}

UpdateSelected(*) {
    global repos, ogcRepoListView

    selectedRepos := []
    Count := ogcRepoListView.GetCount("S")
    
    if Count = 0 {
        Notify.Show('Alert', 'Please select a repository first.', 'icon!',,, 'TC=black MC=black BC=75AEDC style=edge show=slideWest@250 hide=slideEast@250')
        return
    }

    Loop
        {
            RowNumber := ogcRepoListView.GetNext(RowNumber)  ; Resume the search at the row after that found by the previous iteration.
            if not RowNumber  ; The above returned zero, so there are no more selected rows.
                break
            repoPath := ogcRepoListView.GetText(RowNumber, 1)
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
        UpdateListViewStatus(repo.path, "No")
    }

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
    cmd := 'cmd.exe /c cd /d "' folder '" && git status'
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
    shell := ComObject("WScript.Shell")
    exec := shell.Exec(command)
    result := exec.StdOut.ReadAll()
    return result
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

UpdateListViewStatus(path, status) {
    global ogcRepoListView
    rowIndex := ogcRepoListView.Find(1, path, 1)
    if rowIndex {
        ogcRepoListView.Modify(rowIndex, 3, status)
    }
}

FilterListView(*) {
    global ogcRepoListView, myGui
    columnIndex := myGui["FilterColumn"].Value
    filterText := myGui["FilterText"].Value
    ogcRepoListView.Delete()

    if (filterText = "Any") {
        LoadListView()
    } else {
        file := A_ScriptDir "\Settings\ListViewData.txt"
        originalData := FileRead(file)
        if (originalData = "") 
            return

        rows := StrSplit(originalData, "`n")
        for rowIndex, row in rows {
            columns := StrSplit(row, "`t")
            matches := false
            if (filterText=""){
                matches := true
            }else{
                for colIndex, column in columns {
                    if (InStr(column, filterText)) {
                        matches := true
                        break
                    }
                }
            }
            if (matches) {
                ogcRepoListView.Add("", columns*)
            }
        }
    }

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

Escape::ExitApp

















