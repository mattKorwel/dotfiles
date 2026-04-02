# --- 1. Admin Elevation Check ---
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "Please run this script as Administrator!"
    break
}

$DOTFILES_DIR = $PSScriptRoot
Write-Host "🚀 Starting Master Setup for AI Developer Environment..." -ForegroundColor Green

# --- 2. OS Hardening (The 'Sequim Scrub') ---
Write-Host "🛡️  Hardening Windows & Killing Bloat/AI Recall..." -ForegroundColor Yellow

$RegistryKeys = @(
    # Disable Recall & AI Snapshotting
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows AI"; Name = "DisableAIDataAnalysis"; Value = 1 },
    # Disable Edge Shopping, Cashback, and Copilot
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "EdgeShoppingAssistantEnabled"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "EdgeCopilotEnabled"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "HubsSidebarEnabled"; Value = 0 },
    # Disable Consumer Features (TikTok/Disney+ stubs)
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"; Name = "DisableWindowsConsumerFeatures"; Value = 1 },
    # Disable Start Menu Web Search (Bing)
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "ConnectedSearchUseWeb"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "DisableWebSearch"; Value = 1 },
    # Disable Background Apps (Master Kill Switch)
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"; Name = "LetAppsRunInBackground"; Value = 2 },
    # Disable Telemetry (Level 0 - Security Only)
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "AllowTelemetry"; Value = 0 },
    # Disable Widgets & Search Highlights
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "TaskbarDa"; Value = 0 },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"; Name = "IsDynamicSearchBoxEnabled"; Value = 0 }
)

foreach ($Key in $RegistryKeys) {
    if (!(Test-Path $Key.Path)) { New-Item -Path $Key.Path -Force | Out-Null }
    Set-ItemProperty -Path $Key.Path -Name $Key.Name -Value $Key.Value
}

# Explicitly Uninstall Recall via DISM
Write-Host "🧼 Removing Recall component..." -ForegroundColor Gray
DISM /Online /Disable-Feature /FeatureName:Recall /NoRestart /Quiet | Out-Null

# --- 3. Core Tool Installation ---
Write-Host "📡 Installing core tools via Winget..." -ForegroundColor Cyan
$Apps = @(
    "Microsoft.PowerShell",
    "starship.starship",
    "jschmid1.mise",
    "ajeetdsouza.zoxide",
    "junegunn.fzf",
    "Microsoft.VisualStudioCode",
    "Docker.DockerDesktop",
    "Microsoft.WSL"
)

foreach ($App in $Apps) {
    $Id = $App.Split('.')[-1]
    if (-not (Get-Command $Id -ErrorAction SilentlyContinue)) {
        Write-Host "Installing $App..." -ForegroundColor Gray
        winget install --id $App --silent --accept-package-agreements --accept-source-agreements --upgrade
    }
}

# --- 4. Directory Prep ---
$PROFILE_DIR = Split-Path -Parent $PROFILE
if (-not (Test-Path $PROFILE_DIR)) { New-Item -ItemType Directory -Path $PROFILE_DIR -Force | Out-Null }

# --- 5. Symlinks & Git Config ---
Write-Host "🔗 Setting up symlinks & Git config..." -ForegroundColor Cyan

# Link PowerShell Profile
if (Test-Path $PROFILE -PathType Leaf) {
    $date = Get-Date -Format "yyyyMMdd_HHmmss"
    Move-Item $PROFILE "$PROFILE.bak_$date"
}
New-Item -ItemType SymbolicLink -Path $PROFILE -Target "$DOTFILES_DIR\Microsoft.PowerShell_profile.ps1" -Force

# Git Configuration (Using Include strategy)
$SHARED_PATH = "$DOTFILES_DIR\.gitconfig.shared"
$SHARED_PATH_GIT = $SHARED_PATH.Replace("\", "/")
$included = git config --global --get-all include.path | Select-String -Pattern ".gitconfig.shared"
if (-not $included) {
    Write-Host "📝 Including shared git config in ~/.gitconfig..." -ForegroundColor Cyan
    git config --global --add include.path "$SHARED_PATH_GIT"
}

# Link Mise Config
$MISE_CONFIG_DIR = "$HOME\.config\mise"
if (-not (Test-Path $MISE_CONFIG_DIR)) { New-Item -ItemType Directory -Path $MISE_CONFIG_DIR -Force | Out-Null }
New-Item -ItemType SymbolicLink -Path "$MISE_CONFIG_DIR\config.toml" -Target "$DOTFILES_DIR\.config\mise\config.toml" -Force

# Link Starship Config
$CONFIG_DIR = "$HOME\.config"
if (-not (Test-Path $CONFIG_DIR)) { New-Item -ItemType Directory -Path $CONFIG_DIR -Force | Out-Null }
New-Item -ItemType SymbolicLink -Path "$CONFIG_DIR\starship.toml" -Target "$DOTFILES_DIR\config.toml" -Force

# --- 6. Runtimes & Gemini CLI ---
Write-Host "🛠️  Initializing Mise runtimes & Gemini CLI..." -ForegroundColor Cyan

# Refresh Path
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

if (Get-Command mise -ErrorAction SilentlyContinue) {
    # Install runtimes from your config.toml
    & "mise" install 
    & "mise" reshim

    # Install Gemini CLI nightly
    Write-Host "🚀 Installing Gemini CLI from Nightly feed..." -ForegroundColor Yellow
    npm install -g @google/gemini-cli@nightly --registry=https://registry.npmjs.org/
}

Write-Host "`n✅ Master Setup complete! Restart PowerShell or run: . `$PROFILE" -ForegroundColor Green
