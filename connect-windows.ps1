# ═══════════════════════════════════════════════════════════════
#  ClawBot — Connect to VM  (Windows PowerShell)
#
#  HOW TO USE:
#  1. Change the IP below to your Azure VM's IP address
#  2. Make sure your key.pem is saved at C:\Users\YourName\key.pem
#  3. Right-click this file → "Run with PowerShell"
#     OR open PowerShell and run:
#        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#        .\connect-windows.ps1
# ═══════════════════════════════════════════════════════════════

# ↓↓↓ CHANGE THIS TO YOUR VM'S IP ADDRESS ↓↓↓
$env:VM_IP = "PASTE_YOUR_IP_HERE"
# ↑↑↑ THAT'S THE ONLY LINE YOU NEED TO CHANGE ↑↑↑

# Key file — update this path if your key.pem is saved somewhere else
$KEY = "$HOME\key.pem"

# ── Sanity checks ────────────────────────────────────────────
if ($env:VM_IP -eq "PASTE_YOUR_IP_HERE") {
    Write-Host ""
    Write-Host "ERROR: Set your VM IP at the top of this script first." -ForegroundColor Red
    Write-Host "  Open connect-windows.ps1 and replace PASTE_YOUR_IP_HERE with your Azure VM IP." -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path $KEY)) {
    Write-Host ""
    Write-Host "ERROR: Key file not found at $KEY" -ForegroundColor Red
    Write-Host "  Save your Azure key.pem to: $HOME\key.pem" -ForegroundColor Yellow
    Write-Host "  Or update the `$KEY variable at the top of this script." -ForegroundColor Yellow
    exit 1
}

# Fix key permissions (Windows SSH requires the key to be locked down)
Write-Host "Fixing key file permissions..." -ForegroundColor Cyan
icacls $KEY /inheritance:r /grant:r "$($env:USERNAME):(R)" | Out-Null

# ── SSH into the VM ──────────────────────────────────────────
Write-Host ""
Write-Host "Connecting to azureuser@$env:VM_IP ..." -ForegroundColor Green
Write-Host ""
ssh -i $KEY -o StrictHostKeyChecking=accept-new "azureuser@$env:VM_IP"
