Set-Alias -Name l -Value ls
Set-Alias -Name ll -Value ls
Set-Alias -Name k -Value kubectl
Set-Alias -Name h -Value helm
Set-Alias -Name ks -Value k9s
Set-Alias -Name v -Value nvim
Set-Alias -Name vi -Value nvim
Set-Alias -Name vim -Value nvim
Set-Alias -Name lg -Value lazygit
Set-Alias -Name ldo -Value lazydocker
Set-Alias -Name fff -Value fastfetch
Set-Alias -Name which -Value where.exe 
Set-Alias -Name cw -Value Change-WorkTree
Set-Alias -Name cpwe -Value Copy-WorkTreeEnv

Set-PsReadLineOption -EditMode Vi
Set-PSReadLineOption -ViModeIndicator Cursor

Set-PSReadLineKeyHandler -Chord "ctrl+f" -Function AcceptSuggestion
Set-PSReadLineKeyHandler -Chord "ctrl+k" -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Chord "ctrl+j" -Function HistorySearchForward
Set-PSReadLineKeyHandler -Chord "ctrl+w" -Function BackwardDeleteWord
Set-PSReadLineKeyHandler -Chord "ctrl+p" -Function PreviousHistory
Set-PSReadLineKeyHandler -Chord "ctrl+n" -Function NextHistory
Set-PSReadLineKeyHandler -Chord "ctrl+r" -ScriptBlock {
    $Command = Get-Content -Tail 10000 (Get-PSReadlineOption).HistorySavePath `
        | %{ $_.ToString().Trim() } `
        | Sort-Object `
        | Get-Unique `
        | fzf --layout=reverse
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($Command)
}
Set-PSReadLineKeyHandler -Chord "ctrl+t" -ScriptBlock {
    $File = "$(fd -d8 -H -E node_modules -E dist -E target -E bin -E obj -E .git -H | fzf --layout=reverse)"
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($File)
}

$env:EDITOR="nvim"
$env:SHELL="pwsh"

function prompt {
    $exit_code = $lastexitcode

    $segments = @()

    $is_git = "$(git rev-parse --is-inside-work-tree)" -eq "true"

    # userinfo
    $segments += "$env:USERNAME@$env:COMPUTERNAME"

    # git changes
    if ($true -eq $is_git) {
        $status = $(git status -s)
        $m = $(echo $status | ?{ $_ -like ' M*' } | measure -Line).Lines ?? 0
        $d = $(echo $status | ?{ $_ -like ' D*' } | measure -Line).Lines ?? 0
        $a = $(echo $status | ?{ $_ -like 'A *' } | measure -Line).Lines ?? 0
        $u = $(echo $status | ?{ $_ -like '`?`?*' } | measure -Line).Lines ?? 0
        $branch_name = $(git branch --show-current)

        $segments += "`e[95m $branch_name`e[39m `e[93m$u `e[92m$a `e[94m$m `e[91m$d`e[39m"
    }

    # path
    $dir_path = "$pwd"
    if ($dir_path -eq $env:userprofile) {
        $dir_path = "~"
    }
    elseif ($dir_path.startswith($env:userprofile)) {
        $dir_path = $dir_path.replace($env:userprofile, "~") -replace "\\","/"
    }
    elseif ($is_git) {
        $git_dir = "$(git rev-parse --show-toplevel)" -replace "/","\"
        $repo_path = $dir_path.replace($git_dir, "") -replace "\\","/"
        $repo_name = $(git remote get-url origin) -replace "git@github\.com\:","" -replace "\.git","" -replace "https\://github\.com/",""
        $dir_path = "[ $repo_name] $repo_path"
    }
    else {
        $dir_path = $dir_path -replace "\\","/"
    }
    $segments += $dir_path

    # join segments
    $segments_text = $segments -join ' '

    $status = "`e[92m$`e[39m"
    if ($exit_code -ne 0) {
        $status = "`e[91m$`e[39m" 
    }

    $Host.UI.RawUI.WindowTitle = $dir_path

    return "$segments_text`n$status "
}

function chez {
    param([Switch] $Watch)

    chezmoi list --include files
    | fzf --layout=reverse
    | %{
        if ($Watch -eq $True) {
            chezmoi edit --watch $_
        }
        else {
            chezmoi edit --apply $_
        }
    }
}

function forx {
    Param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [object[]]
        $paths,

        [Parameter(Mandatory,Position=2,ValueFromRemainingArguments)]
        [string]
        $cmd
    )

    Process {
        $paths | foreach-object -throttle 6 -parallel {
            pushd $_
            iex $using:cmd
        }
    }
}

function .. { cd .. }
function ... { cd ../.. }

function Get-DotnetCounters() {
    $process = $("$(dotnet counters ps | fzf --layout reverse)" -split " ")[1]
    if ("$process" -eq "") {
        return;
    }

    Write-Host "You selected $process"

    $counters = $(Read-Host -Prompt "Counters (optional)")

    if ("$counters" -eq "") {
        dotnet counters monitor -p $process --showDeltas
    }
    else {
        dotnet counters monitor -p $process --counters "System.Runtime,$counters" --showDeltas
    }
}

function Get-WmWindows {
    glazewm query windows | jq '.data.windows.[] | {className,processName,title}'
}

function Get-WmWorkspaces {
     glazewm query  workspaces | jq '.data.workspaces.[] | {name,hasFocus,tilingDirection}'
}

function Get-WmInfo {
    $jq = '.data.monitors.[]|' + `
          '{hardwareId,hasFocus,children:([.children.[]|' + `
          '{name,hasFocus,tilingDirection,children:([.children.[]|{id,title,className,processName,hasFocus}])}])}'
    glazewm query monitors | jq $jq
}

function Reset-WmWindows {
    glazewm query windows `
    | jq -c '.data.windows.[] | select(.state.type=="tiling" or .state.type=="fullscreen") | {title,processName,id}' `
    | ConvertFrom-Json `
    | %{ glazewm command --id $_.id set-tiling; write "Reset '$($_.title)'!" }
}

function View-Diff {
    param (
        $Context = 3
    )

    if ("$(git rev-parse --is-inside-work-tree)" -ne "true") {
        Write-Error "Not in a git repo"
    }
    else {
        $fst = "$(git log --oneline -n 50 --no-color | fzf | %{ ($_ -split ' ')[0] })"
        if (0 -ne $LastExitCode) { return; }
        $snd = "$(git log --oneline -n 50 --no-color | fzf | %{ ($_ -split ' ')[0] })"
        if (0 -ne $LastExitCode) { return; }

        # git difftool $fst $snd --name-only | fzf | %{ git difftool -y $fst $snd -- $_ }
        git difftool $fst $snd --name-only | fzf | %{ git diff --unified=$context $fst $snd -- $_ }
    }
}

function Copy-WorkTreeEnv {
    $IsInsideWorkTreeDir = "$(git rev-parse --is-inside-work-tree 2>$null)" -eq "true"

    If (!$IsInsideWorkTreeDir) {
        Write-Error "This script must be run inside a worktree directory."
        Return
    }

    $SelectedWorktreePath = git worktree list `
    | fzf --layout=reverse --prompt="Select a worktree: " --height=40% --border --ansi
    | ForEach-Object { $_.Split(" ")[0] }
    | ForEach-Object { $_.Trim() }
    | Where-Object { $_ -ne "" }

    $WorkTreeRootPath = "$(git rev-parse --show-toplevel)"

    If ($WorkTreeRootPath -eq $SelectedWorktreePath) {
        Write-Error "The selected worktree is the current worktree. Aborting."
        Return
    }

    Push-Location $SelectedWorktreePath

    git ls-files --others | rg '\.env$' | ForEach-Object {
        $SourcePath = Join-Path $SelectedWorktreePath $_
        $DestinationPath = Join-Path $WorkTreeRootPath $_

        $Response = Read-Host "Copy '$SourcePath' to '$DestinationPath'? (Y/n) "
        $Accepted = $Response -eq '' -Or $Response -eq 'y' -Or $Response -eq 'Y'

        If (-Not $Accepted) {
            Write-Host "Skipping '$SourcePath'"
            Return
        }

        Copy-Item -Path $SourcePath -Destination $DestinationPath -Force
    }

    Pop-Location
}

function Change-WorkTree {
    $IsInsideGitDir = "$(git rev-parse --is-inside-git-dir 2>$null)" -eq "true"
    $IsInsideWorkTreeDir = $false

    If (!$IsInsideGitDir) {
        $IsInsideWorkTreeDir = "$(git rev-parse --is-inside-work-tree 2>$null)" -eq "true"
        If (!$IsInsideWorkTreeDir) {
            Write-Error "This script must be run inside a Git directory."
            Return
        }
    }

    $SelectedWorktreePath = git worktree list `
    | fzf --layout=reverse --prompt="Select a worktree: " --height=40% --border --ansi
    | ForEach-Object { $_.Split(" ")[0] }
    | ForEach-Object { $_.Trim() }
    | Where-Object { $_ -ne "" }

    $WorkTreeRootPath = $null;

    If ($IsInsideWorkTreeDir) {
        $WorkTreeRootPath = "$(git rev-parse --show-toplevel)"
    }

    If ($WorkTreeRootPath -eq $SelectedWorktreePath) {
        Write-Host "The selected worktree is the current worktree. Aborting."
        Return
    }

    Set-Location $SelectedWorktreePath
}

function getenv {
    cat .env `
    | %{ $_.trim() } `
    | ?{ $_ -match '^(?!#)' } `
    | ?{ $_.length -gt 0 }
    | %{ $_ -replace '^(.*?=)(?!")(.*)$', '$1"$2"' } `
    | %{ iex $(write "`$env:$_") }
}

Invoke-Expression (&{ zoxide init powershell --cmd cd | Out-String })

If ("$(where.exe /Q kaf && echo 1)" -ne "") {
    Invoke-Expression (@(kaf completion powershell) -replace " ''\)$"," ' ')" -join "`n")
}

Import-Module -ErrorAction Ignore "$PSScriptRoot/PrivateFunctions.ps1"
