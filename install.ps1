# --- 1. Admin & Environment Prep ---
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "Please run this script as Administrator!"
    break
}
$DOTFILES_DIR = $PSScriptRoot
Write-Host "--- Starting Setup: AI Dev Spec (Sequim v4) ---" -ForegroundColor Green

# --- 2. Winget Bootstrap (The Fix for 0x8a15005e) ---
Write-Host "--- Bootstrapping Winget Engine ---" -ForegroundColor Yellow
winget settings --enable BypassCertificatePinningForMicrosoftStore | Out-Null
winget source reset --force | Out-Null
# Force update to latest Winget to ensure --upgrade and registry-checking work
winget install --id Microsoft.AppInstaller --silent --accept-package-agreements --accept-source-agreements
# Refresh path immediately so current session sees new winget features
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# --- 3. OS Hardening (Idempotent Registry) ---
Write-Host "--- Hardening Windows Registry ---" -ForegroundColor Yellow
$RegistryKeys = @(
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows AI"; Name = "DisableAIDataAnalysis"; Value = 1 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "EdgeShoppingAssistantEnabled"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "EdgeCopilotEnabled"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "HubsSidebarEnabled"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"; Name = "DisableWindowsConsumerFeatures"; Value = 1 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "ConnectedSearchUseWeb"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "DisableWebSearch"; Value = 1 }
)

foreach ($Key in $RegistryKeys) {
    if (!(Test-Path $Key.Path)) { New-Item -Path $Key.Path -Force | Out-Null }
    $val = Get-ItemProperty -Path $Key.Path -Name $Key.Name -ErrorAction SilentlyContinue
    if ($null -eq $val -or $val.$($Key.Name) -ne $Key.Value) {
        Set-ItemProperty -Path $Key.Path -Name $Key.Name -Value $Key.Value
    }
}

# --- 4. Core Tool Installation (State-Aware) ---
Write-Host "--- Syncing Developer Stack ---" -ForegroundColor Cyan
$Apps = @(
    "Microsoft.PowerShell", "Google.Chrome", "Zen-Team.Zen-Browser", 
    "starship.starship", "jdx.mise", "ajeetdsouza.zoxide", 
    "junegunn.fzf", "Microsoft.VisualStudioCode", "Docker.DockerDesktop", 
    "GitHub.cli", "DEVCOM.JetBrainsMonoNerdFont"
)

foreach ($App in $Apps) {
    # Check if ALREADY installed via winget registry
    $check = winget list --id $App --exact -ErrorAction SilentlyContinue
    if ($check -match $App) {
        Write-Host "Check: $App is already installed." -ForegroundColor Gray
    } else {
        Write-Host "Installing $App..." -ForegroundColor White
        winget install --id $App --silent --accept-package-agreements --accept-source-agreements
    }
}

# --- 5. Symlinks (Using Guard Logic) ---
Write-Host "--- Linking Dotfiles & Terminal Settings ---" -ForegroundColor Yellow

function New-SafeLink($LinkPath, $TargetPath) {
    if (Test-Path $LinkPath) {
        $item = Get-Item $LinkPath
        if ($item.LinkType -eq "SymbolicLink") { return } # Skip if it's already a link
        Move-Item $LinkPath "$LinkPath.bak_$(Get-Date -f yyyyMMdd)" -Force
    }
    New-Item -ItemType SymbolicLink -Path $LinkPath -Target $TargetPath -Force | Out-Null
}

# Terminal Settings
$TermSettings = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
New-SafeLink $TermSettings "$DOTFILES_DIR\terminal-settings.json"

# PowerShell Profiles (5.1 and 7)
New-SafeLink $PROFILE "$DOTFILES_DIR\Microsoft.PowerShell_profile.ps1"
$PS7_DIR = "$HOME\Documents\PowerShell"; if (!(Test-Path $PS7_DIR)) { mkdir $PS7_DIR | Out-Null }
New-SafeLink "$PS7_DIR\Microsoft.PowerShell_profile.ps1" "$DOTFILES_DIR\Microsoft.PowerShell_profile.ps1"

# --- 6. Runtimes & Gemini CLI ---
Write-Host "--- Initializing Runtimes ---" -ForegroundColor Green
if (Get-Command mise -ErrorAction SilentlyContinue) {
    & "mise" install 
    & "mise" reshim
    npm install -g @google/gemini-cli@nightly --registry=https://registry.npmjs.org/
}

# Clean up security bypass
winget settings --disable BypassCertificatePinningForMicrosoftStore | Out-Null

Write-Host "--- Setup Complete! Run '. `$PROFILE' to activate Starship. ---" -ForegroundColor Green
