# --- 1. Admin Check ---
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "Please run this script as Administrator!"
    break
}

Write-Host "--- Optimizing Surface for House Utility & Entertainment ---" -ForegroundColor Green

# --- 2. Winget Bootstrap (Ensure we can install things) ---
Write-Host "--- Bootstrapping Winget ---" -ForegroundColor Yellow
winget settings --enable BypassCertificatePinningForMicrosoftStore | Out-Null
winget source reset --force | Out-Null
winget install --id Microsoft.AppInstaller --silent --accept-package-agreements --accept-source-agreements

# --- 3. Privacy & Performance Hardening (The De-Bloat) ---
Write-Host "--- Scrubbing Windows Junk ---" -ForegroundColor Yellow
$RegistryKeys = @(
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows AI"; Name = "DisableAIDataAnalysis"; Value = 1 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "EdgeShoppingAssistantEnabled"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "EdgeCopilotEnabled"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"; Name = "DisableWindowsConsumerFeatures"; Value = 1 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "DisableWebSearch"; Value = 1 },
    # Battery Saver: Disable UI transparency
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"; Name = "EnableTransparency"; Value = 0 }
)
foreach ($Key in $RegistryKeys) {
    if (!(Test-Path $Key.Path)) { New-Item -Path $Key.Path -Force | Out-Null }
    Set-ItemProperty -Path $Key.Path -Name $Key.Name -Value $Key.Value
}

# --- 4. Purge Edge & Recall (Save Space) ---
Write-Host "--- Purging Edge & Recall ---" -ForegroundColor Red
DISM /Online /Disable-Feature /FeatureName:Recall /NoRestart /Quiet | Out-Null
$EdgeSetup = Get-ChildItem "C:\Program Files (x86)\Microsoft\Edge\Application\1*\Installer\setup.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName -First 1
if ($EdgeSetup) { Start-Process -FilePath $EdgeSetup -ArgumentList "--uninstall --system-level --force-uninstall" -Wait }

# --- 5. Clean Utility Install (Chrome + Zen) ---
Write-Host "--- Installing Browsers ---" -ForegroundColor Cyan
# We skip Docker, VS Code, Mise, and Starship.
$Apps = @("Google.Chrome", "Zen-Team.Zen-Browser")
foreach ($App in $Apps) {
    winget install --id $App --silent --accept-package-agreements --accept-source-agreements
}

# --- 6. Cleanup any lingering Dev traces ---
Write-Host "--- Cleaning up Dev traces ---" -ForegroundColor Gray
$PurgeList = @("Docker.DockerDesktop", "Microsoft.VisualStudioCode", "jdx.mise", "GitHub.cli")
foreach ($App in $PurgeList) {
    winget uninstall --id $App --silent -ErrorAction SilentlyContinue
}

if (Test-Path "C:\dev") { Remove-Item "C:\dev" -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host "--- Setup Complete! Surface is clean and ready for the boat. ---" -ForegroundColor Green
