# 🦞 ClawBot Setup Guide

Self-hosted AI assistant on Azure — Telegram + Discord + Web dashboard.  
Follow these steps top to bottom. Each block is meant to be **copy-pasted directly**.

---

## Before you begin — grab these 3 things

You'll need them when the setup script asks:

| What | Where to get it |
|---|---|
| **OpenRouter API key** | https://openrouter.ai/keys → Create key |
| **Telegram Bot token** | https://t.me/BotFather → `/newbot` → copy the token |
| **Discord Bot token** | https://discord.com/developers/applications → New App → Bot → Reset Token |

---

## Step 1 — Create the Azure VM

> Skip this if you already have a VM running Ubuntu 22.04.

Install the Azure CLI first if you don't have it: https://aka.ms/installazurecli

Paste this in your **local terminal**:

```bash
# Login
az login

# Create resource group
az group create \
  --name openclaw-rg \
  --location koreacentral

# Create the VM  (same spec as the reference machine)
az vm create \
  --resource-group openclaw-rg \
  --name openclaw-vm \
  --image Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest \
  --size Standard_D2as_v4 \
  --admin-username azureuser \
  --generate-ssh-keys \
  --security-type TrustedLaunch \
  --enable-secure-boot true \
  --enable-vtpm true \
  --public-ip-sku Standard

# Open SSH, HTTP, and HTTPS ports
az vm open-port --resource-group openclaw-rg --name openclaw-vm --port 22  --priority 1000
az vm open-port --resource-group openclaw-rg --name openclaw-vm --port 80  --priority 1010
az vm open-port --resource-group openclaw-rg --name openclaw-vm --port 443 --priority 1020

# Get your VM's public IP
az vm list-ip-addresses \
  --resource-group openclaw-rg \
  --name openclaw-vm \
  --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" \
  --output tsv
```

Note down the IP from the last command.

---

## Step 2 — SSH into the VM

```bash
ssh -i ~/key.pem azureuser@<YOUR_VM_IP>
```

> If you used `--generate-ssh-keys` above, Azure saved the key to `~/.ssh/id_rsa`.  
> In that case just use: `ssh azureuser@<YOUR_VM_IP>`

---

## Step 3 — Run the setup script inside the VM

Once you're **inside the VM**, paste this one command:

```bash
curl -fsSL https://raw.githubusercontent.com/rusilkoirala/lyra/main/setup.sh | bash
```

The script will prompt you for the 3 tokens from above, then fully configure everything automatically.

---

### What it installs

```
[1/8]  System packages          git, curl, jq, openssl, nginx
[2/8]  Node.js 22               via FNM
[3/8]  openclaw + clawhub       npm install -g
[4/8]  Config                   ~/.openclaw/openclaw.json
[5/8]  TLS certificate          self-signed, /etc/nginx/ssl/
[6/8]  nginx                    HTTP → HTTPS → proxy to gateway
[7/8]  systemd service          openclaw-gateway (auto-restart)
[8/8]  Daily digest cron        08:00 AM NPT via Telegram
```

When it finishes you'll see your **gateway token** and dashboard URL printed in the terminal.

---

## Step 4 — Open the dashboard

1. Go to `https://<YOUR_VM_IP>/` in your browser  
   *(click through the self-signed cert warning)*
2. Paste the **gateway token** shown at the end of the setup output
3. Approve the browser session on the VM:

```bash
openclaw devices list
openclaw devices approve <requestId>
```

That's it — your bot is live on Telegram and Discord. ✅

---

## Useful commands

```bash
# Check everything is running
openclaw gateway status
openclaw health

# Live gateway logs
journalctl --user -u openclaw-gateway -f

# Restart the gateway
systemctl --user restart openclaw-gateway

# Update to latest
npm install -g openclaw@latest && systemctl --user restart openclaw-gateway
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Can't reach dashboard | Make sure NSG has ports **80 + 443** open (Step 1) |
| Gateway not running | `systemctl --user start openclaw-gateway` |
| Telegram bot silent | `openclaw channels list` — verify token |
| Discord bot offline | Enable **Message Content Intent** in the Discord developer portal |
| Service dies on logout | `sudo loginctl enable-linger $USER` |
| See logs | `journalctl --user -u openclaw-gateway -f` |

---

## Reference

- OpenClaw docs: https://docs.openclaw.ai  
- OpenRouter models: https://openrouter.ai/models  
- Azure CLI install: https://aka.ms/installazurecli

