#Requires AutoHotkey v2

; GUI Initialization
myGui := Gui("Resize")
myGui.Title := "Repository Manager"

; Add GUI elements
myGui.Add("Button", "w150", "Open RepoFolders.txt").OnEvent("Click", OpenTxtFile)
myGui.Add("Button", "w150", "Check for Updates").OnEvent("Click", CheckForUpdates)
myGui.Add("Button", "w150", "Update All").OnEvent("Click", UpdateAll)
myGui.Add("Button", "w150", "Update Selected").OnEvent("Click", UpdateSelected)
myGui.Add("Button", "w150", "Select All").OnEvent("Click", SelectAll)
myGui.Add("Button", "w150", "Deselect All").OnEvent("Click", DeselectAll)

myGui.Add("ListView", "vRepoListView r10 w600", ["Repository Path", "Owner", "Repo Name", "Updates Available"])
ogcRepoListView := myGui["RepoListView"]

; Global variables
global repos := [] ; Array to store repository data
global reposToUpdate := [] ; Array to store repositories with updates

; Show GUI
myGui.Show()

; Function to open the txt file (RepoFolders.txt)
OpenTxtFile(*) {
    Run(A_ScriptDir "\RepoFolders.txt")
}

; Function to check for updates
CheckForUpdates(*) {
    global repos, reposToUpdate, ogcRepoListView

    ; Clear existing ListView items and repositories arrays
    ogcRepoListView.Delete()
    repos := []
    reposToUpdate := []

    txtFile := A_ScriptDir "\RepoFolders.txt"
    if !FileExist(txtFile) {
        MsgBox("RepoFolders.txt not found!")
        return
    }

    content := FileRead(txtFile, '`n')
    folders := StrSplit(content, "`n")
    
    ; Search through the folders for git repositories
    for folder in folders {
        folder := Trim(folder)
        if !DirExist(folder) {
            continue ; Skip if the folder doesn't exist
        }
        AddReposWithUpdates(folder)
    }

    ; Debug output to verify `reposToUpdate` length
    ; MsgBox("reposToUpdate Length: " reposToUpdate.length)

    ; Populate ListView with the repository details
    for repo in repos {
        updateStatus := repo.updates ? "Yes" : "No"
        ogcRepoListView.Add(,repo.path, repo.owner, repo.name, updateStatus)
    }

    MsgBox(reposToUpdate.length " repositories found with updates.")
}

; Function to update all repositories
UpdateAll(*) {
    global reposToUpdate

    if reposToUpdate.length = 0 {
        MsgBox("No repositories need updating.")
        return
    }

    g := Gui("Progress", "+AlwaysOnTop")
    g.AddProgress("vProgressBar w600", 0)
    g.Show()

    ProgressMax := reposToUpdate.length
    ProgressPos := 0

    for repo in reposToUpdate {
        ProgressPos++
        ProgressValue := (ProgressPos / ProgressMax) * 100
        ToolTip("Updating repository: " repo.path "`nProgress: " ProgressPos "/" ProgressMax)

        ; Update the progress bar
        g["ProgressBar"].Value := ProgressValue

        ; Pull updates
        RunWait('cmd.exe /c cd /d "' repo.path '" && git pull',, "Hide")
    }

    g.Destroy()
    ToolTip()
    MsgBox("All repositories updated!")
}

; Function to update selected repositories
UpdateSelected(*) {
    global repos, ogcRepoListView

    selectedRepos := []
    for rowIndex in ogcRepoListView.GetNext(0, "Selected") {
        selectedRepos.Push(repos[rowIndex - 1]) ; Get corresponding repository
    }

    if selectedRepos.length = 0 {
        MsgBox("No repositories selected.")
        return
    }

    g := Gui("Progress", "+AlwaysOnTop")
    g.AddProgress("vProgressBar w600", 0)
    g.Show()

    ProgressMax := selectedRepos.length
    ProgressPos := 0

    for repo in selectedRepos {
        ProgressPos++
        ProgressValue := (ProgressPos / ProgressMax) * 100
        ToolTip("Updating repository: " repo.path "`nProgress: " ProgressPos "/" ProgressMax)

        ; Update the progress bar
        g["ProgressBar"].Value := ProgressValue

        ; Pull updates
        RunWait('cmd.exe /c cd /d "' repo.path '" && git pull',, "Hide")
    }

    g.Destroy()
    ToolTip()
    MsgBox("Selected repositories updated!")
}

; Function to select all repositories
SelectAll(*) {
    global ogcRepoListView
    ogcRepoListView.Modify(0, "+Select")
}

; Function to deselect all repositories
DeselectAll(*) {
    global ogcRepoListView
    ogcRepoListView.Modify(0, "-Select")
}

; Function to add repositories with updates to the global arrays
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
        repos.Push(repo) ; Ensure `repos` is also populated
    } else {
        for subfolder in GetSubfolders(folder) {
            AddReposWithUpdates(subfolder)
        }
    }
}

; Function to check if a repository has updates
HasGitUpdates(folder) {
    ; Build the command to run git status
    cmd := 'cmd.exe /c cd /d "' folder '" && git status'

    ; Run the command and capture the output
    output := RunCommand(cmd)

    ; Debug output to check what was captured
    ; MsgBox("Command Output:`n" output)

    ; Regex pattern to match if the branch is behind
    pattern := "Your branch is behind 'origin/[^']+' by (\d+) commit"

    ; Perform regex match
    if RegExMatch(output, pattern, &match) {
        ; Match[1] contains the number of commits behind
        commitsBehind := match[1]
        return commitsBehind != "0" ; Return true if commitsBehind is not 0
    } else {
        return false ; No updates needed or the status is up-to-date
    }
}

; Function to run a command and capture its output
RunCommand(command) {
    ; Create a new COM object to run the command
    shell := ComObject("WScript.Shell")
    exec := shell.Exec(command)
    result := exec.StdOut.ReadAll()
    return result
}

; Function to parse git repository information
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

; Function to retrieve subfolders
GetSubfolders(folder) {
    subfolders := []
    Loop Files, folder "\*", "D" ; Loop over directories
        subfolders.Push(A_LoopFileFullPath)
    return subfolders
}
