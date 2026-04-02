# --- 1. Admin & Environment Prep ---
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "Please run this script as Administrator!"
    break
}

Write-Host "--- Optimizing Surface for Boat Utility (No Chrome) ---" -ForegroundColor Green

# --- 2. Winget Bootstrap ---
Write-Host "--- Bootstrapping Winget ---" -ForegroundColor Yellow
winget settings --enable BypassCertificatePinningForMicrosoftStore | Out-Null
winget source reset --force | Out-Null
winget install --id Microsoft.AppInstaller --silent --accept-package-agreements --accept-source-agreements

# --- 3. Privacy & Battery Hardening ---
Write-Host "--- Scrubbing Windows Junk & Saving Battery ---" -ForegroundColor Yellow
$RegistryKeys = @(
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows AI"; Name = "DisableAIDataAnalysis"; Value = 1 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "EdgeShoppingAssistantEnabled"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "EdgeCopilotEnabled"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"; Name = "DisableWindowsConsumerFeatures"; Value = 1 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "DisableWebSearch"; Value = 1 },
    # Disable UI transparency to save GPU/Battery on the Surface
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"; Name = "EnableTransparency"; Value = 0 }
)
foreach ($Key in $RegistryKeys) {
    if (!(Test-Path $Key.Path)) { New-Item -Path $Key.Path -Force | Out-Null }
    Set-ItemProperty -Path $Key.Path -Name $Key.Name -Value $Key.Value
}

# --- 4. The Big Purge (Edge, Recall, & Chrome) ---
Write-Host "--- Purging Edge, Recall, and Chrome ---" -ForegroundColor Red
DISM /Online /Disable-Feature /FeatureName:Recall /NoRestart /Quiet | Out-Null

# Uninstall Chrome (both User and System scopes)
winget uninstall --id Google.Chrome --scope user --silent -ErrorAction SilentlyContinue
winget uninstall --id Google.Chrome --scope machine --silent -ErrorAction SilentlyContinue

# Uninstall Edge if installer is found
$EdgeSetup = Get-ChildItem "C:\Program Files (x86)\Microsoft\Edge\Application\1*\Installer\setup.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName -First 1
if ($EdgeSetup) { Start-Process -FilePath $EdgeSetup -ArgumentList "--uninstall --system-level --force-uninstall" -Wait }

# --- 5. Clean Utility Install (Zen Browser Only) ---
Write-Host "--- Installing Zen Browser ---" -ForegroundColor Cyan
winget install --id Zen-Team.Zen-Browser --silent --accept-package-agreements --accept-source-agreements

# --- 6. Remove All Dev Tools & Folders ---
Write-Host "--- Wiping Dev Baggage ---" -ForegroundColor Gray
$PurgeList = @("Docker.DockerDesktop", "Microsoft.VisualStudioCode", "jdx.mise", "GitHub.cli", "Microsoft.PowerShell", "starship.starship")
foreach ($App in $PurgeList) {
    winget uninstall --id $App --silent -ErrorAction SilentlyContinue
}

# Delete the dev folder and local profiles
if (Test-Path "C:\dev") { Remove-Item "C:\dev" -Recurse -Force -ErrorAction SilentlyContinue }
$PROFILES = @("$HOME\Documents\WindowsPowerShell", "$HOME\Documents\PowerShell")
foreach ($P in $PROFILES) { if (Test-Path $P) { Remove-Item $P -Recurse -Force -ErrorAction SilentlyContinue } }

Write-Host "--- Setup Complete! Surface is now a lean Utility Tablet. ---" -ForegroundColor Green
Write-Host "Restart recommended to kill background Edge/Recall processes." -ForegroundColor Cyan
