# 🦞 ClawBot Setup Guide

> Just follow the steps. Each code block = copy, paste, done.

---

## 🗝️ First — get these 3 things ready

Open these links and copy your tokens before you start:

| # | What | Link |
|---|---|---|
| 1 | **OpenRouter API key** | https://openrouter.ai/keys → click **Create key** |
| 2 | **Telegram Bot token** | https://t.me/BotFather → send `/newbot` → copy the token it gives you |
| 3 | **Discord Bot token** | https://discord.com/developers/applications → New Application → Bot tab → **Reset Token** → copy it |

Save them somewhere. The setup script will ask for them.

---

## Step 1 — Make the Azure VM

> **Already have a Ubuntu 22.04 VM?** Skip to Step 2.

First install the Azure CLI if you haven't: https://aka.ms/installazurecli

Then open a terminal on your computer and paste all of this at once:

```bash
az login

az group create --name openclaw-rg --location koreacentral

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

az vm open-port --resource-group openclaw-rg --name openclaw-vm --port 22  --priority 1000
az vm open-port --resource-group openclaw-rg --name openclaw-vm --port 80  --priority 1010
az vm open-port --resource-group openclaw-rg --name openclaw-vm --port 443 --priority 1020
```

Then run this to get your VM's IP address — **copy it down**:

```bash
az vm list-ip-addresses \
  --resource-group openclaw-rg \
  --name openclaw-vm \
  --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" \
  --output tsv
```

---

## Step 2 — Connect to the VM

Pick your OS below. You only need to change **one line** — your IP.

---

### 🍎 Mac or Linux

1. Download [`connect-mac-linux.sh`](connect-mac-linux.sh) from this repo
2. Open it in any text editor and change this one line at the top:
   ```bash
   export VM_IP="PASTE_YOUR_IP_HERE"   # ← put your IP here
   ```
3. Save the file, then run:
   ```bash
   bash connect-mac-linux.sh
   ```

> Your key file should be at `~/key.pem`. If it's somewhere else, also update the `KEY=` line in the script.

---

### 🪟 Windows

> Make sure you have **OpenSSH** installed — it comes with Windows 10/11 by default.

1. Download [`connect-windows.ps1`](connect-windows.ps1) from this repo
2. Open it in Notepad and change this one line at the top:
   ```powershell
   $env:VM_IP = "PASTE_YOUR_IP_HERE"   # ← put your IP here
   ```
3. Save your `key.pem` file to `C:\Users\YourName\key.pem`
4. Open **PowerShell** (search for it in Start menu), then run:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```
   Then drag-and-drop the `connect-windows.ps1` file into the PowerShell window and press Enter.

---

Once connected you'll see a prompt like `azureuser@openclaw-vm:~$` — you're in. ✅

---

## Step 3 — Install ClawBot on the VM

You're now inside the VM. Paste this one line and press Enter:

```bash
curl -fsSL https://raw.githubusercontent.com/RusilKoirala/lyra/main/setup.sh | bash
```

It will ask for your **3 tokens** from Step 0. Paste them in when prompted.

Then it runs automatically — takes ~2 minutes. When done it prints your dashboard link and token.

---

## Step 4 — Open the dashboard

1. Go to `https://YOUR_VM_IP/` in your browser
2. You'll see a cert warning — click **Advanced → Proceed** (it's safe, just self-signed)
3. Paste the **gateway token** from the terminal output
4. Back in the VM terminal, approve the browser:
   ```bash
   openclaw devices list
   openclaw devices approve <requestId>
   ```

Your bot is now live on Telegram and Discord. ✅

---

## Useful commands (run inside the VM)

```bash
openclaw gateway status        # is it running?
openclaw health                # full health check
openclaw channels list         # see connected bots

journalctl --user -u openclaw-gateway -f   # live logs
systemctl --user restart openclaw-gateway  # restart

npm install -g openclaw@latest && systemctl --user restart openclaw-gateway  # update
```

---

## Something broke?

| Problem | Fix |
|---|---|
| Can't open dashboard in browser | Make sure ports **80 and 443** are open — run the `az vm open-port` commands from Step 1 again |
| Bot not responding on Telegram | Run `openclaw channels list` — check the token is correct |
| Discord bot shows offline | Go to Discord Developer Portal → your app → Bot → enable **Message Content Intent** |
| Everything stopped after you closed the terminal | Run `sudo loginctl enable-linger $USER` inside the VM |
| Want to see what's happening | Run `journalctl --user -u openclaw-gateway -f` inside the VM |

---

## Reference

- OpenClaw docs: https://docs.openclaw.ai  
- OpenRouter models: https://openrouter.ai/models  
- Azure CLI install: https://aka.ms/installazurecli

