# --- 1. Admin & Compatibility Check ---
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "Please run this script as Administrator!"
    break
}

$DOTFILES_DIR = $PSScriptRoot
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

# --- 3. Core Tool Installation (Including Nerd Font) ---
Write-Host "--- Installing Developer Stack & Fonts ---" -ForegroundColor Cyan
$Apps = @(
    "Microsoft.PowerShell",     # PowerShell 7
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
$RepoSettingsPath = "$DOTFILES_DIR\terminal-settings.json"

if (Test-Path (Split-Path $TerminalSettingsPath)) {
    if (Test-Path $TerminalSettingsPath) {
        # Check if it's already a link to avoid recursive errors
        $item = Get-Item $TerminalSettingsPath
        if ($item.LinkType -ne "SymbolicLink") {
            Write-Host "Backing up existing terminal settings..." -ForegroundColor Gray
            Move-Item $TerminalSettingsPath "$TerminalSettingsPath.bak_$(Get-Date -f yyyyMMdd)" -Force
            New-Item -ItemType SymbolicLink -Path $TerminalSettingsPath -Target $RepoSettingsPath -Force
        }
    } else {
        New-Item -ItemType SymbolicLink -Path $TerminalSettingsPath -Target $RepoSettingsPath -Force
    }
}

# --- 5. Purge Bloat (Edge & Recall) ---
Write-Host "--- Purging Edge & Recall ---" -ForegroundColor Red
DISM /Online /Disable-Feature /FeatureName:Recall /NoRestart /Quiet | Out-Null
$EdgePath = Get-ChildItem "C:\Program Files (x86)\Microsoft\Edge\Application\1*\Installer\setup.exe" | Select-Object -ExpandProperty FullName -First 1
if ($EdgePath) { Start-Process -FilePath $EdgePath -ArgumentList "--uninstall --system-level --force-uninstall" -Wait }

# --- 6. Re-enable AI & Virtualization ---
Write-Host "--- Ensuring NPU & WSL2 are active ---" -ForegroundColor Green
dism /online /enable-feature /featurename:PlatformAI /all /NoRestart | Out-Null
dism /online /enable-feature /featurename:VirtualMachinePlatform /all /NoRestart | Out-Null
dism /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /NoRestart | Out-Null

# --- 7. Symlinks (Handling both 5.1 and 7 profiles) ---
Write-Host "--- Linking PowerShell Profiles ---" -ForegroundColor Cyan
# Legacy 5.1
if (Test-Path $PROFILE) { Move-Item $PROFILE "$PROFILE.bak_$(Get-Date -f yyyyMMdd)" -ErrorAction SilentlyContinue }
New-Item -ItemType SymbolicLink -Path $PROFILE -Target "$DOTFILES_DIR\Microsoft.PowerShell_profile.ps1" -Force

# Modern 7.x
$PS7_PROFILE_DIR = "$HOME\Documents\PowerShell"
if (!(Test-Path $PS7_PROFILE_DIR)) { New-Item -ItemType Directory -Path $PS7_PROFILE_DIR -Force | Out-Null }
$PS7_PROFILE_PATH = "$PS7_PROFILE_DIR\Microsoft.PowerShell_profile.ps1"
if (Test-Path $PS7_PROFILE_PATH) { Move-Item $PS7_PROFILE_PATH "$PS7_PROFILE_PATH.bak" -ErrorAction SilentlyContinue }
New-Item -ItemType SymbolicLink -Path $PS7_PROFILE_PATH -Target "$DOTFILES_DIR\Microsoft.PowerShell_profile.ps1" -Force

# --- 8. Final Runtimes ---
Write-Host "--- Initializing Runtimes & Gemini Nightly ---" -ForegroundColor Cyan
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
if (Get-Command mise -ErrorAction SilentlyContinue) {
    & "mise" install 
    & "mise" reshim
    npm install -g @google/gemini-cli@nightly --registry=https://registry.npmjs.org/
}

Write-Host "--- Setup Complete! PowerShell 7 is installed and set as default. ---" -ForegroundColor Green
Write-Host "Please close this window and open a NEW Terminal to see the changes." -ForegroundColor Yellow
