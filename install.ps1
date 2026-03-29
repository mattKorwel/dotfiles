# PowerShell script to install dotfiles on Windows

Write-Host "📡 Installing core tools via Winget..." -ForegroundColor Cyan
winget install Microsoft.PowerShell --source winget
winget install starship.starship --source winget
winget install jschmid1.mise --source winget
winget install ajeetdsouza.zoxide --source winget
winget install junegunn.fzf --source winget

$DOTFILES_DIR = $PSScriptRoot
$PROFILE_DIR = Split-Path -Parent $PROFILE
if (-not (Test-Path $PROFILE_DIR)) { New-Item -ItemType Directory -Path $PROFILE_DIR -Force }

Write-Host "🔗 Setting up symlinks..." -ForegroundColor Cyan

# Link PowerShell Profile
if (Test-Path $PROFILE -PathType Leaf) {
    $date = Get-Date -Format "yyyyMMdd_HHmmss"
    Move-Item $PROFILE "$PROFILE.bak_$date"
}
New-Item -ItemType SymbolicLink -Path $PROFILE -Target "$DOTFILES_DIR\Microsoft.PowerShell_profile.ps1" -Force

# Link Mise Config
$MISE_CONFIG_DIR = "$HOME\.config\mise"
if (-not (Test-Path $MISE_CONFIG_DIR)) { New-Item -ItemType Directory -Path $MISE_CONFIG_DIR -Force }
New-Item -ItemType SymbolicLink -Path "$MISE_CONFIG_DIR\config.toml" -Target "$DOTFILES_DIR\.config\mise\config.toml" -Force

# Link Starship Config
$CONFIG_DIR = "$HOME\.config"
if (-not (Test-Path $CONFIG_DIR)) { New-Item -ItemType Directory -Path $CONFIG_DIR -Force }
New-Item -ItemType SymbolicLink -Path "$CONFIG_DIR\starship.toml" -Target "$DOTFILES_DIR\config.toml" -Force

Write-Host "`n✅ Windows installation complete! Restart PowerShell or run: . `$PROFILE" -ForegroundColor Green
