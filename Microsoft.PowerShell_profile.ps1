# --- Environment & Tools ---
if (Get-Command mise -ErrorAction SilentlyContinue) {
    Invoke-Expression (& mise activate pwsh | Out-String)
}

if (Get-Command starship -ErrorAction SilentlyContinue) {
    # Check if we are running in pwsh (PowerShell 6+) or powershell (5.1)
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        Invoke-Expression (&starship init pwsh)
    } else {
        Invoke-Expression (&starship init powershell)
    }
}

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (&zoxide init powershell)
}

# --- Shell Enhancements (Predictive IntelliSense) ---
if (Get-Module -ListAvailable PSReadLine) {
    # Enable Predictive IntelliSense (Ghost Text) from history
    Set-PSReadLineOption -PredictionSource History

    # Optional: Set view to 'InlineView' (ghost text) - default
    Set-PSReadLineOption -PredictionView InlineView

    # Set F2 to toggle between InlineView and ListView
    Set-PSReadLineKeyHandler -Key F2 -Function NextViMode
}

# --- General Aliases ---
function gadd([string]$msg) {
    git add -A
    git commit -m "$msg"
    git push -u origin HEAD
}

function ls { Get-ChildItem @args }
function ll { Get-ChildItem -Force @args }
function grep { Select-String @args }

# --- Gemini CLI Version Manager (High Performance) ---

# Mise handles the main 'gemini' path in ~/.config/mise/config.toml
# These functions provide isolated access to other channels.
function gnightly { & "$HOME\.gcli\nightly\node_modules\.bin\gemini.ps1" @args }
function gstable  { & "$HOME\.gcli\stable\node_modules\.bin\gemini.ps1" @args }
function gpreview { & "$HOME\.gcli\preview\node_modules\.bin\gemini.ps1" @args }

function gupdate-all {
    Write-Host "📡 Updating Gemini CLI versions..." -ForegroundColor Cyan
    
    $dirs = "$HOME\.gcli\main", "$HOME\.gcli\nightly", "$HOME\.gcli\stable", "$HOME\.gcli\preview"
    foreach ($dir in $dirs) {
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force }
    }

    Write-Host "📡 Refreshing 'gemini' (GitHub main branch)..."
    npm install --prefix "$HOME\.gcli\main" https://github.com/google-gemini/gemini-cli#main
    
    Write-Host "📡 Refreshing 'gnightly' (npm @nightly)..."
    npm install --prefix "$HOME\.gcli\nightly" @google/gemini-cli@nightly
    
    Write-Host "📡 Refreshing 'gstable' (npm @latest)..."
    npm install --prefix "$HOME\.gcli\stable" @google/gemini-cli@latest
    
    Write-Host "📡 Refreshing 'gpreview' (npm @preview)..."
    npm install --prefix "$HOME\.gcli\preview" @google/gemini-cli@preview
    
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
