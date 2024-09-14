;//TODO Progressbar (Notify.ahk ?)

#Requires AutoHotkey v2
txtFile := A_ScriptDir "\RepoFolders.txt" 
content := FileRead(txtFile, '`n') 
folders := StrSplit(content, "`n") 
for each, folder in folders {
    folder := Trim(folder) 
    if not DirExist(folder) { 
        ; MsgBox("Folder doesn't exist: " . folder)
        continue
    }
    CheckAndPullGit(folder)
}
MsgBox("All repositories updated!")

CheckAndPullGit(folder) {
    folder := Trim(folder)
    if DirExist(folder "\.git") {
        ToolTip("Updating repository: " . folder)
        RunWait('cmd.exe /c cd "' folder '" && git pull', , "Hide") 
        ToolTip()
    } else {
        Loop Files, folder "\*", "D" { 
            subfolder := A_LoopFileFullPath
            CheckAndPullGit(subfolder)
        }
    }
}
