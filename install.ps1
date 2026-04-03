# --- 1. Admin & Environment Prep ---
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "Please run this script as Administrator!"
    break
}
$DOTFILES_DIR = $PSScriptRoot
Write-Host "--- Starting Setup: AI Dev Spec (Sequim v5.7) ---" -ForegroundColor Green

# --- 2. Winget Bootstrap (The Fix for 0x8a15005e) ---
Write-Host "--- Bootstrapping Winget Engine ---" -ForegroundColor Yellow
winget settings --enable BypassCertificatePinningForMicrosoftStore | Out-Null
winget source reset --force | Out-Null
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

# --- 4. Core Tool Installation (Corrected IDs) ---
Write-Host "--- Syncing Developer Stack ---" -ForegroundColor Cyan
$Apps = @(
    "Microsoft.PowerShell", "Git.Git", "Google.Chrome", "Zen-Team.Zen-Browser", 
    "starship.starship", 
    "jdx.mise",             # <--- FIXED ID
    "ajeetdsouza.zoxide", 
    "junegunn.fzf", "Microsoft.VisualStudioCode", "Docker.DockerDesktop", 
    "GitHub.cli",           # <--- FIXED ID
    "DEVCOM.JetBrainsMonoNerdFont", "GnuPG.GnuPG"
)

foreach ($App in $Apps) {
    $check = winget list --id $App --exact -ErrorAction SilentlyContinue
    if ($check -match $App) {
        Write-Host "Check: $App is already installed." -ForegroundColor Gray
    } else {
        Write-Host "Installing $App..." -ForegroundColor White
        winget install --id $App --silent --accept-package-agreements --accept-source-agreements
    }
}

# --- 5. Symlinks & Git/GPG Logic ---
Write-Host "--- Linking Dotfiles & Configuring Git/GPG ---" -ForegroundColor Yellow
function New-SafeLink($LinkPath, $TargetPath) {
    if (Test-Path $LinkPath) {
        $item = Get-Item $LinkPath
        if ($item.LinkType -eq "SymbolicLink") { return } 
        Move-Item $LinkPath "$LinkPath.bak_$(Get-Date -f yyyyMMdd)" -Force -ErrorAction SilentlyContinue
    }
    # Ensure parent directory exists (critical for fresh installs)
    $parent = Split-Path $LinkPath
    if (!(Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    New-Item -ItemType SymbolicLink -Path $LinkPath -Target $TargetPath -Force | Out-Null
}

# Profile & Terminal Links
$TermSettings = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
New-SafeLink $TermSettings "$DOTFILES_DIR\terminal-settings.json"
New-SafeLink "$HOME\.config\starship.toml" "$DOTFILES_DIR\starship.toml"
New-SafeLink $PROFILE "$DOTFILES_DIR\Microsoft.PowerShell_profile.ps1"
$PS7_DIR = "$HOME\Documents\PowerShell"; if (!(Test-Path $PS7_DIR)) { mkdir $PS7_DIR | Out-Null }
New-SafeLink "$PS7_DIR\Microsoft.PowerShell_profile.ps1" "$DOTFILES_DIR\Microsoft.PowerShell_profile.ps1"
# Mise Global Config (Maps your dotfiles version to the Windows AppData path)
$MiseConfigPath = Join-Path $env:APPDATA "mise\config.toml"
New-SafeLink $MiseConfigPath "$DOTFILES_DIR\.config\mise\config.toml"

# Gemini Settings
$GEMINI_DIR = "$HOME\.gemini"
if (-not (Test-Path $GEMINI_DIR)) { New-Item -ItemType Directory -Path $GEMINI_DIR -Force | Out-Null }
New-SafeLink "$GEMINI_DIR\settings.json" "$DOTFILES_DIR\.gemini\settings.json"

# 5c. Git Identity & GPG Auto-Gen (The "I/O Error" Fixes)
if (Get-Command gpg -ErrorAction SilentlyContinue) {
    # Force Git to use the standalone GnuPG, not the internal Git-bundled one
    $GPG_PATH = (Get-Command gpg).Source
    git config --global gpg.program "$GPG_PATH"
    
    git config --global user.name "Matt Korwel"
    git config --global user.email "matt.korwel@gmail.com"
    git config --global include.path "C:/dev/dotfiles/.gitconfig.shared"
    git config --global core.symlinks true

    if (!(gpg --list-secret-keys 2>$null)) {
        Write-Host "Generating GPG Key..." -ForegroundColor Cyan
        $batch = "Key-Type: RSA`nKey-Length: 4096`nName-Real: Matt Korwel`nName-Email: matt.korwel@gmail.com`nExpire-Date: 0`n%no-protection`n%commit"
        $batch | Out-File "$env:TEMP\gpg_gen.txt" -Encoding utf8
        gpg --batch --generate-key "$env:TEMP\gpg_gen.txt"
    }

    $keyId = (gpg --list-secret-keys --keyid-format=LONG | Select-String "sec" | ForEach-Object { ($_ -split '/')[1] -split ' ' | Select-Object -First 1 })
    if ($keyId) {
        git config --global user.signingkey $keyId
        git config --global commit.gpgsign true
    }
}

# --- 6. Runtimes & Gemini CLI (The Real Test) ---
Write-Host "--- Initializing Runtimes & Gemini CLI ---" -ForegroundColor Green
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

if (Get-Command mise -ErrorAction SilentlyContinue) {
    Write-Host "Mise found. Installing runtimes..." -ForegroundColor Gray
    & "mise" trust
    & "mise" install 
    & "mise" reshim
    # Use mise exec to ensure node/npm is in path for the global install
    & "mise" exec -- -- npm install -g @google/gemini-cli@nightly --registry=https://registry.npmjs.org/
} else {
    Write-Error "Mise was not found in the path. Gemini CLI install skipped."
}

# OneDrive "Not Digitally Signed" Fix
if ((Get-ExecutionPolicy) -ne 'Bypass') {
    Set-ExecutionPolicy Unrestricted -Scope CurrentUser -Force -ErrorAction SilentlyContinue
}

winget settings --disable BypassCertificatePinningForMicrosoftStore | Out-Null
Write-Host "--- Setup Complete! Run '. `$PROFILE' to activate. ---" -ForegroundColor Green