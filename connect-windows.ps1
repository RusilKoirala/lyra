# ═══════════════════════════════════════════════════════════════
#  ClawBot — SSH Connect Script for Windows (PowerShell)
#  Run in PowerShell (Windows 10/11 has OpenSSH built-in)
# ═══════════════════════════════════════════════════════════════

# ── SET YOUR VM IP HERE ──────────────────────────────────────
$env:VM_IP = "PASTE_YOUR_IP_HERE"
# ─────────────────────────────────────────────────────────────

# Key file location — change this if you saved it elsewhere
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
