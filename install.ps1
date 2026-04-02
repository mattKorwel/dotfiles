# --- 1. Admin & Elevation Check ---
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "Please run this script as Administrator (Right-click Terminal > Run as Admin)!"
    break
}

$DOTFILES_DIR = $PSScriptRoot
Write-Host "🚀 Starting Master Setup: AI Dev Spec..." -ForegroundColor Green

# --- 2. OS Hardening (The 'Sequim Scrub') ---
Write-Host "🛡️  Hardening Windows Registry..." -ForegroundColor Yellow
$RegistryKeys = @(
    # AI Privacy & Recall
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows AI"; Name = "DisableAIDataAnalysis"; Value = 1 },
    # Edge Bloat & Copilot
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "EdgeShoppingAssistantEnabled"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "EdgeCopilotEnabled"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "HubsSidebarEnabled"; Value = 0 },
    # Consumer Junk
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"; Name = "DisableWindowsConsumerFeatures"; Value = 1 },
    # Start Menu Web Search (Bing)
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "ConnectedSearchUseWeb"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "DisableWebSearch"; Value = 1 },
    # Background Processes & Telemetry
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"; Name = "LetAppsRunInBackground"; Value = 2 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "AllowTelemetry"; Value = 0 },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "TaskbarDa"; Value = 0 }
)

foreach ($Key in $RegistryKeys) {
    if (!(Test-Path $Key.Path)) { New-Item -Path $Key.Path -Force | Out-Null }
    Set-ItemProperty -Path $Key.Path -Name $Key.Name -Value $Key.Value
}

# --- 3. Purge Bloat (Edge & Recall) ---
Write-Host "🚫 Purging Edge & Recall..." -ForegroundColor Red
DISM /Online /Disable-Feature /FeatureName:Recall /NoRestart /Quiet | Out-Null

$EdgePath = Get-ChildItem "C:\Program Files (x86)\Microsoft\Edge\Application\1*\Installer\setup.exe" | Select-Object -ExpandProperty FullName -First 1
if ($EdgePath) { Start-Process -FilePath $EdgePath -ArgumentList "--uninstall --system-level --verbose-logging --force-uninstall" -Wait }

# --- 4. Core Tool Installation ---
Write-Host "📡 Installing Developer Stack & Browsers..." -ForegroundColor Cyan
$Apps = @(
    "Microsoft.PowerShell",
    "Google.Chrome",
    "Zen-Team.Zen-Browser",
    "starship.starship",
    "jschmid1.mise",
    "ajeetdsouza.zoxide",
    "junegunn.fzf",
    "Microsoft.VisualStudioCode",
    "Docker.DockerDesktop",
    "Microsoft.GitHubCLI",
    "Microsoft.WSL"
)

foreach ($App in $Apps) {
    $Id = if ($App -eq "Microsoft.GitHubCLI") { "gh" } else { $App.Split('.')[-1] }
    if (-not (Get-Command $Id -ErrorAction SilentlyContinue)) {
        winget install --id $App --silent --accept-package-agreements --accept-source-agreements --upgrade
    }
}

# --- 5. Docker 'No-Start' Fix ---
Write-Host "🐋 Configuring Docker (Disabling Auto-Start)..." -ForegroundColor Yellow
$DockerSettings = "$env:APPDATA\Docker\settings.json"
if (Test-Path $DockerSettings) {
    $json = Get-Content $DockerSettings | ConvertFrom-Json
    $json.autoStart = $false
    $json | ConvertTo-Json | Set-Content $DockerSettings
}
# Remove the Windows startup shortcut just in case
$StartupLink = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\Docker Desktop.lnk"
if (Test-Path $StartupLink) { Remove-Item $StartupLink -Force }

# --- 6. Re-enable AI & Virtualization (Force Access) ---
Write-Host "🏗️  Ensuring NPU & WSL2 are active..." -ForegroundColor Green
dism /online /enable-feature /featurename:PlatformAI /all /NoRestart | Out-Null
dism /online /enable-feature /featurename:VirtualMachinePlatform /all /NoRestart | Out-Null
dism /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /NoRestart | Out-Null

# --- 7. Symlinks & Git Configuration ---
Write-Host "🔗 Linking Dotfiles & Shared Git Config..." -ForegroundColor Cyan
if (Test-Path $PROFILE) { Move-Item $PROFILE "$PROFILE.bak_$(Get-Date -f yyyyMMdd_HHmm)" }
New-Item -ItemType SymbolicLink -Path $PROFILE -Target "$DOTFILES_DIR\Microsoft.PowerShell_profile.ps1" -Force

# Git Include Strategy
$SHARED_PATH_GIT = "$($DOTFILES_DIR.Replace('\', '/'))/.gitconfig.shared"
git config --global --add include.path "$SHARED_PATH_GIT"

# Mise Config link
$MISE_CFG = "$HOME\.config\mise"
if (!(Test-Path $MISE_CFG)) { New-Item -ItemType Directory -Path $MISE_CFG -Force | Out-Null }
New-Item -ItemType SymbolicLink -Path "$MISE_CFG\config.toml" -Target "$DOTFILES_DIR\.config\mise\config.toml" -Force

# --- 8. Gemini CLI & Runtimes ---
Write-Host "🛠️  Initializing Mise & Gemini Nightly..." -ForegroundColor Cyan
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

if (Get-Command mise -ErrorAction SilentlyContinue) {
    & "mise" install 
    & "mise" reshim
    npm install -g @google/gemini-cli@nightly --registry=https://registry.npmjs.org/
}

Write-Host "`n✅ Setup Complete! Restart required for hardware changes." -ForegroundColor Green
