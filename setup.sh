#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
#  ClawBot / OpenClaw Full Setup Script
#  Tested on: Ubuntu 22.04 LTS (Azure Standard D2as v4)
#  Usage: bash setup.sh
# ═══════════════════════════════════════════════════════════════════════════════
set -e

# ─── Colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
die()     { echo -e "${RED}[ERR]${RESET}   $*" >&2; exit 1; }

echo -e "${BOLD}"
echo "  ╔═══════════════════════════════════════════╗"
echo "  ║   🦞  ClawBot / OpenClaw  Setup Script    ║"
echo "  ║       Ubuntu 22.04 LTS  ·  Azure VM       ║"
echo "  ╚═══════════════════════════════════════════╝"
echo -e "${RESET}"

# ─── 0. Collect required secrets up-front ─────────────────────────────────────
echo -e "${BOLD}Before we start, you need three things:${RESET}"
echo "  1. OpenRouter API key  → https://openrouter.ai/keys"
echo "  2. Telegram Bot token  → https://t.me/BotFather"
echo "  3. Discord Bot token   → https://discord.com/developers/applications"
echo ""

# Allow pre-seeding via env vars (useful for CI / cloud-init)
if [[ -z "$OPENROUTER_API_KEY" ]]; then
  read -rsp "  OpenRouter API key : " OPENROUTER_API_KEY; echo
fi
if [[ -z "$TELEGRAM_BOT_TOKEN" ]]; then
  read -rsp "  Telegram Bot token : " TELEGRAM_BOT_TOKEN; echo
fi
if [[ -z "$DISCORD_BOT_TOKEN" ]]; then
  read -rsp "  Discord  Bot token : " DISCORD_BOT_TOKEN; echo
fi
echo ""

[[ -z "$OPENROUTER_API_KEY" ]] && die "OpenRouter API key is required."
[[ -z "$TELEGRAM_BOT_TOKEN" ]] && die "Telegram Bot token is required."
[[ -z "$DISCORD_BOT_TOKEN"  ]] && die "Discord Bot token is required."

# Agent persona (can override via env)
AGENT_NAME="${AGENT_NAME:-Lyra}"
AGENT_TIMEZONE="${AGENT_TIMEZONE:-Asia/Kathmandu}"
OPENCLAW_PORT="${OPENCLAW_PORT:-18789}"

# ─── 1. System prerequisites ──────────────────────────────────────────────────
info "[1/8] Installing system prerequisites..."
sudo apt-get update -qq
sudo apt-get install -y \
  git curl jq ca-certificates openssl \
  nginx unzip build-essential
success "System packages installed."

# ─── 2. FNM + Node.js 22 ──────────────────────────────────────────────────────
info "[2/8] Installing FNM (Fast Node Manager) + Node.js 22..."

if ! command -v fnm &>/dev/null; then
  curl -fsSL https://fnm.vercel.app/install | bash -s -- \
    --install-dir "$HOME/.local/share/fnm" \
    --skip-shell
  export PATH="$HOME/.local/share/fnm:$PATH"
  eval "$(fnm env)"
  success "FNM installed."
else
  export PATH="$HOME/.local/share/fnm:$PATH"
  eval "$(fnm env)"
  warn "FNM already present, skipped."
fi

# Add FNM to .bashrc if not already there
if ! grep -q 'FNM_PATH' ~/.bashrc; then
  cat >> ~/.bashrc <<'BASHRC'

FNM_PATH="/home/${USER}/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "`fnm env`"
fi
BASHRC
  success "FNM added to ~/.bashrc"
fi

fnm install 22 --silent 2>/dev/null || true
fnm use 22
fnm default 22
eval "$(fnm env)" 2>/dev/null || true

echo "  Node : $(node --version)"
echo "  npm  : $(npm --version)"
success "Node.js 22 ready."

# ─── 3. Global npm packages ───────────────────────────────────────────────────
info "[3/8] Installing openclaw, clawhub, vercel (globally)..."
npm install -g openclaw@latest clawhub@latest vercel@latest --silent
echo "  openclaw : $(openclaw --version 2>/dev/null)"
echo "  clawhub  : $(clawhub --version  2>/dev/null || echo 'installed')"
echo "  vercel   : $(vercel --version   2>/dev/null || echo 'installed')"
success "Global npm packages installed."

# ─── 4. OpenClaw configuration ────────────────────────────────────────────────
info "[4/8] Writing OpenClaw config..."

OPENCLAW_DIR="$HOME/.openclaw"
mkdir -p "$OPENCLAW_DIR/workspace" "$OPENCLAW_DIR/logs" \
         "$OPENCLAW_DIR/memory"    ~/briefings

GATEWAY_TOKEN=$(openssl rand -hex 24)

cat > "$OPENCLAW_DIR/openclaw.json" <<EOF
{
  "meta": {
    "lastTouchedVersion": "$(openclaw --version 2>/dev/null || echo '2026.3.1')"
  },
  "ui": {
    "assistant": { "name": "${AGENT_NAME}", "avatar": "💫" }
  },
  "auth": {
    "profiles": {
      "openrouter:default": {
        "provider": "openrouter",
        "mode": "api_key",
        "apiKey": "${OPENROUTER_API_KEY}"
      }
    }
  },
  "agents": {
    "defaults": {
      "model": { "primary": "openrouter/auto" },
      "models": { "openrouter/auto": { "alias": "OpenRouter" } },
      "workspace": "${OPENCLAW_DIR}/workspace",
      "userTimezone": "${AGENT_TIMEZONE}",
      "compaction": { "mode": "safeguard" },
      "maxConcurrent": 4,
      "subagents": { "maxConcurrent": 8 }
    },
    "list": [
      {
        "id": "main",
        "default": true,
        "model": "openrouter/auto",
        "identity": {
          "name": "${AGENT_NAME}",
          "theme": "tech baddie — sharp, confident, a little flirty, always right",
          "emoji": "💫"
        }
      }
    ]
  },
  "messages": { "ackReactionScope": "group-mentions" },
  "commands": {
    "native": "auto",
    "nativeSkills": "auto",
    "restart": true,
    "ownerDisplay": "raw"
  },
  "session": { "dmScope": "per-channel-peer" },
  "channels": {
    "telegram": {
      "enabled": true,
      "dmPolicy": "open",
      "botToken": "${TELEGRAM_BOT_TOKEN}",
      "allowFrom": ["*"],
      "groupPolicy": "open",
      "streaming": "off"
    },
    "discord": {
      "enabled": true,
      "token": "${DISCORD_BOT_TOKEN}",
      "groupPolicy": "open",
      "streaming": "off"
    }
  },
  "gateway": {
    "port": ${OPENCLAW_PORT},
    "mode": "local",
    "bind": "loopback",
    "controlUi": {
      "allowedOrigins": [
        "https://$(curl -s ifconfig.me 2>/dev/null || echo '0.0.0.0')",
        "http://localhost:${OPENCLAW_PORT}",
        "http://127.0.0.1:${OPENCLAW_PORT}"
      ]
    },
    "auth": {
      "mode": "token",
      "token": "${GATEWAY_TOKEN}"
    },
    "trustedProxies": ["loopback"],
    "tailscale": { "mode": "off", "resetOnExit": false },
    "nodes": {
      "denyCommands": [
        "camera.snap","camera.clip","screen.record",
        "calendar.add","contacts.add","reminders.add"
      ]
    }
  },
  "plugins": { "entries": { "discord": { "enabled": true } } }
}
EOF

success "openclaw.json written."

# ─── 4b. Shell completions ────────────────────────────────────────────────────
mkdir -p "$OPENCLAW_DIR/completions"
openclaw completion bash > "$OPENCLAW_DIR/completions/openclaw.bash" 2>/dev/null || true
if ! grep -q 'openclaw.bash' ~/.bashrc; then
  echo 'source "$HOME/.openclaw/completions/openclaw.bash"' >> ~/.bashrc
fi

# ─── 5. Self-signed TLS certificate for nginx ─────────────────────────────────
info "[5/8] Generating self-signed TLS certificate..."
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
sudo mkdir -p /etc/nginx/ssl
sudo openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/openclaw.key \
  -out    /etc/nginx/ssl/openclaw.crt \
  -subj   "/CN=${PUBLIC_IP}/O=OpenClaw/C=US" \
  -addext "subjectAltName=IP:${PUBLIC_IP},IP:127.0.0.1" \
  2>/dev/null
sudo chmod 600 /etc/nginx/ssl/openclaw.key
success "TLS cert generated (10-year self-signed, IP: ${PUBLIC_IP})."

# ─── 6. nginx reverse proxy ───────────────────────────────────────────────────
info "[6/8] Configuring nginx (HTTP→HTTPS + reverse proxy to :${OPENCLAW_PORT})..."

sudo tee /etc/nginx/sites-available/openclaw > /dev/null <<NGINX
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;
    server_name _;

    ssl_certificate     /etc/nginx/ssl/openclaw.crt;
    ssl_certificate_key /etc/nginx/ssl/openclaw.key;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    location / {
        proxy_pass         http://127.0.0.1:${OPENCLAW_PORT};
        proxy_http_version 1.1;

        # WebSocket
        proxy_set_header Upgrade    \$http_upgrade;
        proxy_set_header Connection "upgrade";

        # Standard headers
        proxy_set_header Host              \$host;
        proxy_set_header X-Real-IP         \$remote_addr;
        proxy_set_header X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # Long-lived WS connections
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
}
NGINX

sudo ln -sf /etc/nginx/sites-available/openclaw /etc/nginx/sites-enabled/openclaw
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx
success "nginx configured: HTTP→HTTPS, proxy→127.0.0.1:${OPENCLAW_PORT}."

# ─── 7. systemd user service for openclaw-gateway ────────────────────────────
info "[7/8] Installing openclaw-gateway systemd user service..."

NODE_BIN=$(which node)
OPENCLAW_BIN=$(npm root -g)/openclaw/dist/index.js

mkdir -p ~/.config/systemd/user

cat > ~/.config/systemd/user/openclaw-gateway.service <<UNIT
[Unit]
Description=OpenClaw Gateway
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=${NODE_BIN} ${OPENCLAW_BIN} gateway --port ${OPENCLAW_PORT}
Restart=always
RestartSec=5
KillMode=process
Environment=HOME=${HOME}
Environment=TMPDIR=/tmp
Environment=PATH=${HOME}/.local/share/fnm:${HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin
Environment=OPENCLAW_GATEWAY_PORT=${OPENCLAW_PORT}
Environment=OPENCLAW_GATEWAY_TOKEN=${GATEWAY_TOKEN}
Environment=OPENCLAW_SYSTEMD_UNIT=openclaw-gateway.service
Environment=OPENCLAW_SERVICE_MARKER=openclaw
Environment=OPENCLAW_SERVICE_KIND=gateway

[Install]
WantedBy=default.target
UNIT

# Enable linger so the user service persists after logout
sudo loginctl enable-linger "$USER"

systemctl --user daemon-reload
systemctl --user enable openclaw-gateway
systemctl --user restart openclaw-gateway

sleep 4

if systemctl --user is-active --quiet openclaw-gateway; then
  success "openclaw-gateway service is running."
else
  warn "Service may still be starting. Check: systemctl --user status openclaw-gateway"
fi

# ─── 8. Daily digest cron (8:00 AM NPT = 02:15 UTC) ──────────────────────────
info "[8/8] Setting up daily briefing cron job..."

DIGEST_SCRIPT="$OPENCLAW_DIR/workspace/send_digest.sh"
DAILY_DIGEST_PY="$OPENCLAW_DIR/workspace/daily_digest.py"

# create a minimal digest script if not already there
if [[ ! -f "$DIGEST_SCRIPT" ]]; then
  mkdir -p "$OPENCLAW_DIR/workspace"
  cat > "$DIGEST_SCRIPT" <<'DIGEST'
#!/bin/bash
# send_digest.sh — Daily inbox digest via openclaw CLI
# Cron: 15 2 * * * (02:15 UTC = 08:00 AM NPT)

set -a
source "$(dirname "$0")/.env" 2>/dev/null || true
set +a

BRIEFING_DIR="${HOME}/briefings"
mkdir -p "$BRIEFING_DIR"
DATE=$(date +%Y-%m-%d)
OUTFILE="${BRIEFING_DIR}/digest-${DATE}.txt"
LOGFILE="${BRIEFING_DIR}/digest-${DATE}.log"

PYTHON_SCRIPT="$(dirname "$0")/daily_digest.py"

if [[ -f "$PYTHON_SCRIPT" ]]; then
  python3 "$PYTHON_SCRIPT" > "$OUTFILE" 2>"$LOGFILE"
  STATUS=$?
else
  echo "No daily_digest.py found — skipping digest." > "$OUTFILE"
  STATUS=0
fi

if [[ $STATUS -ne 0 ]]; then
  MSG="❌ *Inbox Digest Failed*\n\nError:\n$(tail -20 "$LOGFILE")"
else
  MSG=$(cat "$OUTFILE")
fi

# Optional: set TELEGRAM_CHAT_ID in ~/.openclaw/workspace/.env
if [[ -n "$TELEGRAM_CHAT_ID" ]]; then
  openclaw message send \
    --channel telegram \
    --target "$TELEGRAM_CHAT_ID" \
    --message "$MSG" >> "$LOGFILE" 2>&1
fi

echo "[$(date)] Digest done. Exit: $STATUS" >> "$LOGFILE"
DIGEST
  chmod +x "$DIGEST_SCRIPT"
  success "Digest script written to $DIGEST_SCRIPT"
fi

# Install cron entry (idempotent)
CRON_LINE="15 2 * * * /bin/bash ${DIGEST_SCRIPT} >> ${HOME}/briefings/cron.log 2>&1"
( crontab -l 2>/dev/null | grep -v 'send_digest'; echo "$CRON_LINE" ) | crontab -
success "Cron job installed (02:15 UTC daily = 08:00 AM NPT)."

# ─── Final summary ────────────────────────────────────────────────────────────
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

echo ""
echo -e "${BOLD}${GREEN}"
echo "  ╔═══════════════════════════════════════════════════════════╗"
echo "  ║             🦞  ClawBot is READY!                         ║"
echo "  ╠═══════════════════════════════════════════════════════════╣"
echo "  ║                                                           ║"
echo -e "  ║  Web dashboard (HTTPS):                                   ║"
echo -e "  ║  ${CYAN}https://${PUBLIC_IP}/${GREEN}                                    ║"
echo "  ║  (Accept the self-signed cert warning in browser)        ║"
echo "  ║                                                           ║"
echo -e "  ║  Direct (SSH tunnel):                                     ║"
echo -e "  ║  ${CYAN}http://127.0.0.1:${OPENCLAW_PORT}/${GREEN}                               ║"
echo "  ║                                                           ║"
echo -e "  ║  Gateway token:                                           ║"
echo -e "  ║  ${CYAN}${GATEWAY_TOKEN}${GREEN}  ║"
echo "  ║                                                           ║"
echo "  ║  Channels:  Telegram ✓   Discord ✓                       ║"
echo "  ║  Agent:     ${AGENT_NAME} (openrouter/auto)                      ║"
echo "  ║                                                           ║"
echo "  ╠═══════════════════════════════════════════════════════════╣"
echo "  ║  IMPORTANT: Open Azure NSG ports 80 + 443 if not open!   ║"
echo "  ║  Portal → VM → Networking → Inbound port rules           ║"
echo "  ╚═══════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

echo "  Useful commands:"
echo "    openclaw gateway status"
echo "    openclaw channels list"
echo "    openclaw health"
echo "    openclaw doctor"
echo "    systemctl --user status openclaw-gateway"
echo "    journalctl --user -u openclaw-gateway -f"
echo ""
echo "  Approve a new browser device:"
echo "    openclaw devices list"
echo "    openclaw devices approve <requestId>"
echo ""
