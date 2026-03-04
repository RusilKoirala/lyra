#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  ClawBot — SSH Connect Script for Mac / Linux
#  Usage: bash connect-mac-linux.sh
# ═══════════════════════════════════════════════════════════════

# ── SET YOUR VM IP HERE ──────────────────────────────────────
export VM_IP="PASTE_YOUR_IP_HERE"
# ─────────────────────────────────────────────────────────────

# Key file location — change this if you saved it elsewhere
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
