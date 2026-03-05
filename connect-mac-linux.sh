#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  ClawBot — Connect to VM  (Mac / Linux)
#
#  HOW TO USE:
#  1. Change the IP below to your Azure VM's IP address
#  2. Make sure your key.pem is saved at ~/key.pem
#  3. Run:  bash connect-mac-linux.sh
# ═══════════════════════════════════════════════════════════════

# ↓↓↓ CHANGE THIS TO YOUR VM'S IP ADDRESS ↓↓↓
export VM_IP="PASTE_YOUR_IP_HERE"
# ↑↑↑ THAT'S THE ONLY LINE YOU NEED TO CHANGE ↑↑↑

# Key file — update this path if your key.pem is saved somewhere else
KEY="$HOME/key.pem"

# ── Sanity checks ────────────────────────────────────────────
if [[ "$VM_IP" == "PASTE_YOUR_IP_HERE" ]]; then
  echo ""
  echo "ERROR: Set your VM IP at the top of this script first."
  echo "  Open connect-mac-linux.sh and replace PASTE_YOUR_IP_HERE with your Azure VM IP."
  exit 1
fi

if [[ ! -f "$KEY" ]]; then
  echo ""
  echo "ERROR: Key file not found at $KEY"
  echo "  Save your Azure key.pem to: $HOME/key.pem"
  echo "  Or update the KEY variable at the top of this script."
  exit 1
fi

# Fix key permissions (SSH refuses keys that are too open)
chmod 400 "$KEY"

# ── SSH into the VM ──────────────────────────────────────────
echo ""
echo "Connecting to azureuser@$VM_IP ..."
echo ""
ssh -i "$KEY" -o StrictHostKeyChecking=accept-new "azureuser@$VM_IP"
