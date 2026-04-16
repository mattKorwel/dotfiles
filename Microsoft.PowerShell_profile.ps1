Set-Location "C:\dev"

# --- Environment & Tools ---

# 1. Mise (Fixed for PS 7.6 string handling)
if (Get-Command mise -ErrorAction SilentlyContinue) {
    Invoke-Expression (& mise activate pwsh | Out-String)
}

# 2. Starship (Fixed: Always use 'powershell' to avoid the 'pwsh not supported' error)
if (Get-Command starship -ErrorAction SilentlyContinue) {
    # Starship's 'pwsh' init is currently broken in some versions; 'powershell' works for both.
    Invoke-Expression (& starship init powershell | Out-String)
}

# 3. Zoxide
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& zoxide init powershell | Out-String)
}

# --- Komorebi (Tiling WM) ---
$env:KOMOREBI_CONFIG_HOME = "C:\dev\dotfiles\.config\komorebi"

function start-wm {
    komorebic start
    Start-Process "$env:KOMOREBI_CONFIG_HOME\komorebi.ahk"
}

function stop-wm {
    komorebic stop
    Stop-Process -Name AutoHotkey64 -Force -ErrorAction SilentlyContinue
}

function restart-wm {
    stop-wm
    Start-Sleep -Seconds 1
    start-wm
}

# --- Shell Enhancements (Predictive IntelliSense) ---
if (Get-Module -ListAvailable PSReadLine) {
    Import-Module PSReadLine
    $hasInteractiveConsole = $false
    $supportsPrediction = $false

    try {
        $hasInteractiveConsole = -not [Console]::IsInputRedirected
        $supportsPrediction = $hasInteractiveConsole -and
            -not [Console]::IsOutputRedirected -and
            $null -ne $Host.UI -and
            [bool]($Host.UI | Get-Member -Name SupportsVirtualTerminal -MemberType Property -ErrorAction SilentlyContinue) -and
            $Host.UI.SupportsVirtualTerminal
    } catch {
        $hasInteractiveConsole = $false
        $supportsPrediction = $false
    }

    if ($hasInteractiveConsole) {
        Set-PSReadLineOption -EditMode Emacs

        # Prediction support requires a VT-capable interactive terminal.
        if ($supportsPrediction) {
            Set-PSReadLineOption -PredictionSource History
            Set-PSReadLineOption -PredictionView InlineView

            # Toggle between InlineView and ListView in supported hosts.
            Set-PSReadLineKeyHandler -Key F2 -Function SwitchPredictionView
        }
    }
}

# --- General Aliases ---
function gadd([string]$msg) {
    if (-not $msg) { $msg = "chore: update" }
    git add -A
    git commit -m "$msg"
    git push -u origin HEAD
}

# Safe wrappers for common commands
function grep { Select-String @args }

# --- Unix Compatibility ---
Set-Alias -Name which -Value Get-Command

# Shortcuts for the 'll' you are used to
function la { Get-ChildItem -Args $args -Force } 
function l { Get-ChildItem -Args $args }

# --- Navigation ---
function .. { Set-Location .. }
function ... { Set-Location ..\.. }
function .... { Set-Location ..\..\.. }
Set-Alias -Name which -Value Get-Command

# --- File Manipulation (Unix-style) ---
# The 'rm -rf' equivalent
function rmrf {
    param([Parameter(ValueFromRemainingArguments=$true)]$Path)
    Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
}

# The 'mkdir -p' equivalent
function mkp {
    param([Parameter(ValueFromRemainingArguments=$true)]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

# The 'touch' equivalent
function touch {
    param([Parameter(ValueFromRemainingArguments=$true)]$Path)
    New-Item -ItemType File -Path $Path -Force | Out-Null
}

# --- Search & View ---
# PowerShell's 'ls' is okay, but 'grep' needs a real alias
if (Get-Command Select-String -ErrorAction SilentlyContinue) {
    Set-Alias -Name grep -Value Select-String
}

# --- Process Management ---
# Equivalent to 'pkill -f'
function pkill {
    param([string]$name)
    Get-Process -Name $name -ErrorAction SilentlyContinue | Stop-Process -Force
}

# --- Environment ---
# Allows 'export VAR=value' syntax
function export {
    param([string]$assignment)
    if ($assignment -like "*=*") {
        $name, $value = $assignment -split '=', 2
        Set-Variable -Name $name -Value $value -Scope Global
    }
}

# Port Checking (Crucial for Dev)
# Usage: 'lport 3000' to see what's hanging on a port
function lport([int]$port) {
    Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue | 
    Select-Object LocalPort, OwningProcess, State
}

# The "Clear" Shortcut
function cls { Clear-Host }

# --- Gemini CLI Version Manager (High Performance) ---

# Note: Using Join-Path for cleaner Windows path handling
function gnightly { & (Join-Path $HOME ".gcli\nightly\node_modules\.bin\gemini.ps1") @args }
function gstable   { & (Join-Path $HOME ".gcli\stable\node_modules\.bin\gemini.ps1") @args }
function gpreview  { & (Join-Path $HOME ".gcli\preview\node_modules\.bin\gemini.ps1") @args }

function gupdate-all {
    Write-Host "📡 Updating Gemini CLI versions..." -ForegroundColor Cyan
    
    $baseDir = Join-Path $HOME ".gcli"
    $channels = "main", "nightly", "stable", "preview"
    
    foreach ($ch in $channels) {
        $path = Join-Path $baseDir $ch
        if (-not (Test-Path $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
    }

    Write-Host "📡 Refreshing 'gemini' (GitHub main branch)..."
    npm install --prefix (Join-Path $baseDir "main") https://github.com/google-gemini/gemini-cli#main
    
    Write-Host "📡 Refreshing 'gnightly' (npm @nightly)..."
    npm install --prefix (Join-Path $baseDir "nightly") @google/gemini-cli@nightly
    
    Write-Host "📡 Refreshing 'gstable' (npm @latest)..."
    npm install --prefix (Join-Path $baseDir "stable") @google/gemini-cli@latest
    
    Write-Host "📡 Refreshing 'gpreview' (npm @preview)..."
    npm install --prefix (Join-Path $baseDir "preview") @google/gemini-cli@preview
    
    if (Get-Command mise -ErrorAction SilentlyContinue) { mise reshim }
    
    Write-Host "`n✅ All versions updated! Use 'gemini', 'gnightly', 'gstable', or 'gpreview'." -ForegroundColor Green
}

# --- Git Workspace Switcher ---
function _get_wt_path([string]$branch) {
    $wt = git worktree list --porcelain | Select-String -Pattern "branch refs/heads/$branch" -Context 2,0
    if ($wt) {
        return ($wt.Context.PreContext[0] -replace "worktree ", "").Trim()
    }
    return $null
}

function gswitch([string]$branch) {
    if (-not $branch) { Write-Host "Usage: gswitch <branch>"; return }
    
    if ((git rev-parse --abbrev-ref HEAD) -eq $branch) {
        git pull
        return
    }

    $worktree_path = _get_wt_path $branch
    if ($worktree_path) {
        Write-Host "📍 Branch '$branch' is already active in worktree: $worktree_path" -ForegroundColor Yellow
        Set-Location $worktree_path
        return
    }

    if (git show-ref --quiet $branch -or (git ls-remote --exit-code --heads origin $branch)) {
        git checkout $branch
    } else {
        Write-Host "🌱 Creating new branch '$branch' from HEAD..." -ForegroundColor Green
        git checkout -b $branch
    }
}

# --- Remote & Persistence ---
# SSH into 'cli' and attach to (or create) a tmux session
# Usage: gw [session_name]
function gw {
    param(
        [Parameter(Mandatory=$false, Position=0)]
        [string]$SessionName = "main"
    )
    ssh -t cli "tmux attach -t $SessionName || tmux new -s $SessionName"
}
