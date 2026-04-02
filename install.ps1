# --- 1. Admin & Compatibility Check ---
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "Please run this script as Administrator!"
    break
}

# Check version for logging
$isLegacy = $PSVersionTable.PSVersion.Major -le 5
Write-Host "--- Starting Setup (Detected PS Version: $($PSVersionTable.PSVersion)) ---" -ForegroundColor Green

# --- 2. OS Hardening (Registry Level) ---
Write-Host "--- Hardening Windows Registry ---" -ForegroundColor Yellow
$RegistryKeys = @(
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows AI"; Name = "DisableAIDataAnalysis"; Value = 1 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "EdgeShoppingAssistantEnabled"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "EdgeCopilotEnabled"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "HubsSidebarEnabled"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"; Name = "DisableWindowsConsumerFeatures"; Value = 1 }
)

foreach ($Key in $RegistryKeys) {
    if (!(Test-Path $Key.Path)) { New-Item -Path $Key.Path -Force | Out-Null }
    Set-ItemProperty -Path $Key.Path -Name $Key.Name -Value $Key.Value
}

# --- 3. Core Tool Installation (Crucial: Installs PS7 first) ---
Write-Host "--- Installing Developer Stack ---" -ForegroundColor Cyan
# We force install PowerShell 7 immediately so it's available for the rest of the script
$Apps = @(
    "Microsoft.PowerShell",     # This is PowerShell 7
    "Google.Chrome",
    "Zen-Team.Zen-Browser",
    "starship.starship",
    "jschmid1.mise",
    "ajeetdsouza.zoxide",
    "junegunn.fzf",
    "Microsoft.VisualStudioCode",
    "Docker.DockerDesktop",
    "Microsoft.GitHubCLI",
    "DEVCOM.JetBrainsMonoNerdFont"
)

foreach ($App in $Apps) {
    Write-Host "Checking $App..." -ForegroundColor Gray
    winget install --id $App --silent --accept-package-agreements --accept-source-agreements --upgrade
}

# --- 4. Symlink Windows Terminal Settings ---
Write-Host "--- Linking Windows Terminal Settings ---" -ForegroundColor Yellow
$TerminalSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$RepoSettingsPath = "$PSScriptRoot\terminal-settings.json"

if (Test-Path (Split-Path $TerminalSettingsPath)) {
    if (Test-Path $TerminalSettingsPath) {
        Write-Host "Backing up existing terminal settings..." -ForegroundColor Gray
        Move-Item $TerminalSettingsPath "$TerminalSettingsPath.bak_$(Get-Date -f yyyyMMdd)" -Force
    }
    New-Item -ItemType SymbolicLink -Path $TerminalSettingsPath -Target $RepoSettingsPath -Force
    Write-Host "Success: Windows Terminal settings linked." -ForegroundColor Green
}

# --- 5. Make PowerShell 7 the Default Terminal Profile ---
Write-Host "--- Setting PowerShell 7 as Default Profile ---" -ForegroundColor Yellow
if (Test-Path $TerminalSettingsPath) {
    $settings = Get-Content $TerminalSettingsPath | ConvertFrom-Json
    # Find the GUID for PowerShell 7 (pwsh.exe)
    $pwshProfile = $settings.profiles.list | Where-Object { $_.commandline -like "*pwsh.exe*" -or $_.name -eq "PowerShell" -or $_.source -like "*PowershellCore*" }
    if ($pwshProfile) {
        $settings.defaultProfile = $pwshProfile.guid
        $settings | ConvertTo-Json -Depth 10 | Set-Content $TerminalSettingsPath
        Write-Host "Success: PowerShell 7 is now your default terminal." -ForegroundColor Green
    }
}

# --- 6. Purge Bloat (Edge & Recall) ---
Write-Host "--- Purging Edge & Recall ---" -ForegroundColor Red
DISM /Online /Disable-Feature /FeatureName:Recall /NoRestart /Quiet | Out-Null
$EdgePath = Get-ChildItem "C:\Program Files (x86)\Microsoft\Edge\Application\1*\Installer\setup.exe" | Select-Object -ExpandProperty FullName -First 1
if ($EdgePath) { Start-Process -FilePath $EdgePath -ArgumentList "--uninstall --system-level --force-uninstall" -Wait }

# --- 7. Re-enable AI & Virtualization ---
Write-Host "--- Ensuring NPU & WSL2 are active ---" -ForegroundColor Green
dism /online /enable-feature /featurename:PlatformAI /all /NoRestart | Out-Null
dism /online /enable-feature /featurename:VirtualMachinePlatform /all /NoRestart | Out-Null
dism /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /NoRestart | Out-Null

# --- 8. Symlinks (Handling both 5.1 and 7 profiles) ---
Write-Host "--- Linking Dotfiles ---" -ForegroundColor Cyan
$DOTFILES_DIR = $PSScriptRoot

# Link legacy 5.1 profile
if (Test-Path $PROFILE) { Move-Item $PROFILE "$PROFILE.bak_$(Get-Date -f yyyyMMdd)" }
New-Item -ItemType SymbolicLink -Path $PROFILE -Target "$DOTFILES_DIR\Microsoft.PowerShell_profile.ps1" -Force

# Link modern 7.x profile (different path)
$PS7_PROFILE_DIR = "$HOME\Documents\PowerShell"
if (!(Test-Path $PS7_PROFILE_DIR)) { New-Item -ItemType Directory -Path $PS7_PROFILE_DIR -Force | Out-Null }
$PS7_PROFILE_PATH = "$PS7_PROFILE_DIR\Microsoft.PowerShell_profile.ps1"
if (Test-Path $PS7_PROFILE_PATH) { Move-Item $PS7_PROFILE_PATH "$PS7_PROFILE_PATH.bak" }
New-Item -ItemType SymbolicLink -Path $PS7_PROFILE_PATH -Target "$DOTFILES_DIR\Microsoft.PowerShell_profile.ps1" -Force

# --- 8. Final Runtimes ---
Write-Host "--- Initializing Runtimes ---" -ForegroundColor Cyan
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
if (Get-Command mise -ErrorAction SilentlyContinue) {
    & "mise" install 
    npm install -g @google/gemini-cli@nightly --registry=https://registry.npmjs.org/
}

Write-Host "--- Setup Complete! PowerShell 7 is installed and set as default. ---" -ForegroundColor Green
Write-Host "Please close this window and open a NEW Terminal to see the changes." -ForegroundColor Yellow
