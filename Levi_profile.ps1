# Simple Navigation
function .. { Set-Location .. }
function cls { Clear-Host }
Set-Alias -Name which -Value Get-Command

# UI Prompts
if (Get-Command starship -ErrorAction SilentlyContinue) { Invoke-Expression (& starship init powershell | Out-String) }
if (Get-Command zoxide -ErrorAction SilentlyContinue) { Invoke-Expression (& zoxide init powershell | Out-String) }

# Quick Cleanup for gamers
function clean-pc {
    ipconfig /flushdns
    rmrf $env:TEMP\*
    Write-Host "System Flushed & Cleaned" -ForegroundColor Green
}
