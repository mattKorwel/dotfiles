# --- 1. Admin & Account Prep ---
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "Please run as Administrator in PowerShell 7 (pwsh)!" ; break
}

$UserName = "levi"
$DOTFILES_ROOT = Split-Path $PSScriptRoot -Parent
$PRIVATE_ROOT = "$HOME\dev\dotfiles-private"
$LEVI_HOME = "C:\Users\$UserName"

Write-Host "--- Starting Setup: Levi Gaming & Art Spec (v1.3) ---" -ForegroundColor Green

# Create Local User if missing
if (!(Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue)) {
    Write-Host "Creating Local Admin: $UserName..." -ForegroundColor Cyan
    $Password = Read-Host -Prompt "Set password for $UserName" -AsSecureString
    New-LocalUser -Name $UserName -Password $Password -FullName "Levi Korwel" -Description "Gaming, Art, Comms"
    Add-LocalGroupMember -Group "Administrators" -Member $UserName
}

# --- 2. Kill OneDrive & Edge (The Nuclear Option) ---
Write-Host "--- Removing Microsoft Bloat ---" -ForegroundColor Red
# Kill OneDrive
Stop-Process -Name "OneDrive" -ErrorAction SilentlyContinue
$OD_Uninstaller = "$env:SystemRoot\System32\OneDriveSetup.exe"
if (Test-Path $OD_Uninstaller) { Start-Process $OD_Uninstaller "/uninstall" -Wait }
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" -Name "PreventUsageOfOneDrive" -Value 1 -ErrorAction SilentlyContinue

# Force Uninstall Edge (2026 Method)
$EdgeInstaller = Get-ChildItem "C:\Program Files (x86)\Microsoft\Edge\Application\*\Installer\setup.exe" | Sort-Object LastWriteTime -Descending | Select-Object -ExpandProperty FullName -First 1
if ($EdgeInstaller) {
    Write-Host "Uninstalling Edge..." -ForegroundColor Gray
    Start-Process -FilePath $EdgeInstaller -ArgumentList "--uninstall --system-level --verbose-logging --force-uninstall" -Wait
}

# --- 3. Performance Registry Fixes ---
Write-Host "--- Optimizing Hardware (5070Ti + Ryzen) ---" -ForegroundColor Yellow
$RegistryKeys = @(
    # Enable HAGS (Vital for Frame Gen)
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; Name = "HwSchMode"; Value = 2 },
    # Disable AI/Consumer Bloat
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows AI"; Name = "DisableAIDataAnalysis"; Value = 1 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"; Name = "DisableWindowsConsumerFeatures"; Value = 1 }
)
foreach ($Key in $RegistryKeys) {
    if (!(Test-Path $Key.Path)) { New-Item -Path $Key.Path -Force | Out-Null }
    Set-ItemProperty -Path $Key.Path -Name $Key.Name -Value $Key.Value
}

# --- 4. Install Levi's App Stack ---
Write-Host "--- Syncing Apps via Winget ---" -ForegroundColor Cyan
$Apps = @(
    "Brave.Brave", "Opera.OperaGX", "KO.Krita", 
    "SlackTechnologies.Slack", "Zoom.Zoom", 
    "Valve.Steam", "Discord.Discord", 
    "starship.starship", "ajeetdsouza.zoxide", "Nvidia.NVIDIAApp"
)
foreach ($App in $Apps) {
    winget install --id $App --silent --accept-package-agreements --accept-source-agreements
}

# --- 5. Copy Profile (No Symlinks) ---
Write-Host "--- Deploying Local Profile ---" -ForegroundColor Yellow
$DestProfile = "$LEVI_HOME\Documents\PowerShell"
if (!(Test-Path $DestProfile)) { New-Item -ItemType Directory -Path $DestProfile -Force | Out-Null }

# Check private repo first, then fallback to public root
$ProfileSource = Join-Path $PRIVATE_ROOT "Levi_profile.ps1"
if (!(Test-Path $ProfileSource)) { $ProfileSource = Join-Path $DOTFILES_ROOT "Levi_profile.ps1" }

if (Test-Path $ProfileSource) {
    Copy-Item $ProfileSource -Destination "$DestProfile\Microsoft.PowerShell_profile.ps1" -Force
}

$DestConfig = "$LEVI_HOME\.config"
if (!(Test-Path $DestConfig)) { New-Item -ItemType Directory -Path $DestConfig -Force | Out-Null }
$StarshipSource = Join-Path $DOTFILES_ROOT ".config\starship.toml"

if (Test-Path $StarshipSource) {
    Copy-Item $StarshipSource -Destination "$DestConfig\starship.toml" -Force
}

# Fix Ownership so Levi can use them
icacls $LEVI_HOME /setowner $UserName /t /c /q /grant "${UserName}:(OI)(CI)F"

# --- 6. Final Polish & Titus ---
Write-Host "--- Final Pass ---" -ForegroundColor Green
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c # High Performance Mode
irm christitus.com/win | iex # Launches GUI for final "Desktop" tweak
