/*
    Author          : Anastasiou Alex
    Gmail           : anastasioualex@gmail.com

    Github          : https://github.com/alexofrhodes/
    YouTube         : https://www.youtube.com/channel/UC5QH3fn1zjx0aUjRER_rOjg
    BuyMeACoffee    : https://www.buymeacoffee.com/AlexOfRhodes
*/

;---AUTO RUN-----------------------------------------------------------------------------

#Requires AutoHotkey v2
#Include include\Notify.ahk

#Include include\customTray.ahk
SetupTray()

global repos := [] 
global reposToUpdate := [] 

OnMessage(0x404, AHK_NOTIFYICON)
 

myGui := Gui("Resize")
myGui.Title := "Repository Manager"

myGui.Add("Button", "w150", "List Git Repos").OnEvent("Click", ListGitRepos)
myGui.Add("Button", "w150", "Check for Updates").OnEvent("Click", CheckForUpdates)

myGui.Add("Button", "w150", "Update All").OnEvent("Click", UpdateAll)
myGui.Add("Button", "w150", "Update Selected").OnEvent("Click", UpdateSelected)
myGui.Add("Button", "w150", "Select All").OnEvent("Click", SelectAll)
myGui.Add("Button", "w150", "Deselect All").OnEvent("Click", DeselectAll)

myGui.Add("Button", "w150", "Open Repo Folder").OnEvent("Click", OpenRepoFolder)
myGui.Add("Button", "w150", "Open on GitHub").OnEvent("Click", OpenOnGitHub)
myGui.Add("Button", "w150", "Open RepoFolders.txt").OnEvent("Click", OpenTxtFile)

mygui.Add("Text","ys section","Filter text")
myGui.Add("Edit", "vFilterText w150").OnEvent("Change", FilterListView)

mygui.Add("Text","ys","Filter by column")
myGui.Add("DropDownList", "vFilterColumn w150", ["Repository Path", "Owner", "Repo Name", "Updates Available","Any"]).OnEvent("Change", FilterListView)

myGUi["FilterColumn"].text := "Any"

myGui.Add("ListView", "xs vRepoListView r12 w600", ["Repository Path", "Owner", "Repo Name", "Updates Available"])
ogcRepoListView := myGui["RepoListView"]

SB := MyGui.Add("StatusBar",, "Alex was here")

LoadListView()

MyGui.OnEvent("Size", Gui_Size)
myGui.Show()

;---END AUTO RUN-----------------------------------------------------------------------------

AHK_NOTIFYICON(wParam, lParam,*){
    if (lParam = 0x201) ; WM_LBUTTONDOWN
    {
        mygui.show
        return 0
    }
}

OpenTxtFile(*) {
    Run(A_ScriptDir "\RepoFolders.txt")
}

ListGitRepos(*) {
    global repos, ogcRepoListView

    ogcRepoListView.Delete()
    repos := []

    txtFile := A_ScriptDir "\RepoFolders.txt"
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

    ; Get the filtered and selected rows
    selectedRows := ogcRepoListView.GetNext(0, "Selected")
    
    if (selectedRows.Length = 0) {
        ; Notify.Show('Alert', 'Please select at least one repository to check for updates.', 'icon!',,, 'TC=black MC=black BC=75AEDC style=edge show=slideWest@250 hide=slideEast@250')
        ; return
        SelectAll()
    }

    ; Loop through selected rows and find corresponding repos based on repo paths
    for rowIndex in selectedRows {
        repoPath := ogcRepoListView.GetText(rowIndex, 1)

        for repo in repos {
            if (repo.path = repoPath) {
                if HasGitUpdates(repo.path) {
                    repo.updates := true
                    reposToUpdate.Push(repo)
                } else {
                    repo.updates := false
                }
                break
            }
        }
    }

    ; Update the ListView with new status for selected rows
    for rowIndex in selectedRows {
        repoPath := ogcRepoListView.GetText(rowIndex, 1)

        for repo in repos {
            if (repo.path = repoPath) {
                updateStatus := repo.updates ? "Yes" : "No"
                ogcRepoListView.Modify(rowIndex, 4, updateStatus)
                break
            }
        }
    }

    SaveListView()  ; Save updated ListView
    Notify.Show('Info', reposToUpdate.Length ' filtered repositories found with updates.', 'iconi',,, 'TC=black MC=black BC=75AEDC style=edge show=slideWest@250 hide=slideEast@250')
}

OpenRepoFolder(*) {
    global ogcRepoListView, repos

    selectedRow := ogcRepoListView.GetNext(0, "Focused")
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

UpdateAll(*) {
    SelectAll()
    UpdateSelected()
}


UpdateSelected(*) {
    global repos, ogcRepoListView

    selectedRepos := []
    selectedRows := ogcRepoListView.GetNext(0, "Selected")

    for rowIndex in selectedRows {
        repoPath := ogcRepoListView.GetText(rowIndex, 1)

        for repo in repos {
            if (repo.path = repoPath) {
                selectedRepos.Push(repo)
                break
            }
        }
    }

    if selectedRepos.length = 0 {
        Notify.Show('Alert', 'Please select a repository first.', 'icon!',,, 'TC=black MC=black BC=75AEDC style=edge show=slideWest@250 hide=slideEast@250')
        return
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

DeselectAll(*) {
    global ogcRepoListView
    ogcRepoListView.Modify(0, "-Select")
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
        file := A_ScriptDir "\ListViewData.txt"
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

    file := A_ScriptDir "\ListViewData.txt"
    try FileDelete(file)

    ; Build the entire content in memory
    fileContent := ""
    for repo in repos {
        updateStatus := repo.updates ? "Yes" : "No"
        rowData := Join("`t", repo.path, repo.owner, repo.name, updateStatus)
        fileContent .= rowData "`n"
    }

    ; Write the full content at once
    FileAppend(fileContent, file)
}


LoadListView() {
    global ogcRepoListView
    ogcRepoListView.delete
    txtFile := A_ScriptDir "\ListViewData.txt"
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
            }
        }
    }
    ogcRepoListView.ModifyCol()
    ogcRepoListView.ModifyCol(4,"AutoHdr")
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

















