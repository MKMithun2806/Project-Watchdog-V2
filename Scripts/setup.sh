#!/bin/bash
set -e

# ─────────────────────────────────────────
# telegram notify
# ─────────────────────────────────────────
tg() {
  [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]] || return 0
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=$1" \
    -d "parse_mode=Markdown" > /dev/null
}

# ─────────────────────────────────────────
# trap
# ─────────────────────────────────────────
on_error() {
  local exit_code=$?
  local line=$1
  tg "🛠️ *Setup failed*%0ATarget: \`$TARGET\`%0ALine: \`$line\`%0AExit: \`$exit_code\`%0A%0ATerminating..."
  INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
  REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
  aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" --region "$REGION" || true
}

trap 'on_error $LINENO' ERR

tg "🛠️ *Starting setup...*%0ATarget: \`$TARGET\`%0AMode: \`$MODE\`"
echo "[*] Starting Malper setup..."

# ─────────────────────────────────────────
# swapfile
# ─────────────────────────────────────────
echo "[*] Configuring swapfile..."
fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# ─────────────────────────────────────────
# base deps
# ─────────────────────────────────────────
echo "[*] Installing base dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq \
  curl wget unzip python3 uuid-runtime \
  ca-certificates gnupg lsb-release nmap
echo "[+] Base deps installed"

# ─────────────────────────────────────────
# docker
# ─────────────────────────────────────────
echo "[*] Installing Docker..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io
systemctl enable docker
systemctl start docker
echo "[+] Docker installed"

# ─────────────────────────────────────────
# ghcr login
# ─────────────────────────────────────────
echo "[*] Logging into ghcr.io..."
echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin
echo "[+] ghcr.io login done"

# ─────────────────────────────────────────
# pull_image helper — 5 retries, 15s backoff
# ─────────────────────────────────────────
pull_image() {
  local img=$1
  for attempt in 1 2 3 4 5; do
    if docker pull "$img" 2>&1; then
      echo "[+] $img ready"
      return 0
    fi
    echo "[!] Pull failed: $img (attempt $attempt/5), retrying in 15s..."
    sleep 15
  done
  echo "[!] WARNING: $img could not be pulled after 5 attempts — continuing"
  return 0  # don't fail setup, vulnmalper will handle missing images
}

# ─────────────────────────────────────────
# pre-pull tool images in parallel
# ─────────────────────────────────────────
echo "[*] Pre-pulling vulnmalper tool images..."
IMAGES=(
  "ghcr.io/mkmithun2806/whatweb:latest"
  "ghcr.io/mkmithun2806/wafw00f:latest"
  "ghcr.io/mkmithun2806/testssl.sh:latest"
  "ghcr.io/sullo/nikto:latest"
  "ghcr.io/mkmithun2806/nuclei:latest"
  "ghcr.io/mkmithun2806/wapiti:latest"
  "ghcr.io/mkmithun2806/sqlmap:latest"
  "ghcr.io/mkmithun2806/ffuf:latest"
  "ghcr.io/mkmithun2806/feroxbuster:latest"
  "ghcr.io/mkmithun2806/katana:latest"
)

# pull in parallel, cap at 4 concurrent
PIDS=()
COUNT=0
for img in "${IMAGES[@]}"; do
  pull_image "$img" &
  PIDS+=($!)
  COUNT=$((COUNT + 1))
  if [[ $COUNT -ge 4 ]]; then
    wait "${PIDS[0]}"
    PIDS=("${PIDS[@]:1}")
    COUNT=$((COUNT - 1))
  fi
done
# wait for remaining
for pid in "${PIDS[@]}"; do
  wait "$pid"
done
echo "[+] Tool images ready"

# ─────────────────────────────────────────
# malper-suite (netmalper)
# ─────────────────────────────────────────
echo "[*] Pulling malper-suite docker image..."
pull_image "mitchaster/malper-suite:latest"
echo "[+] Docker image ready"

# ─────────────────────────────────────────
# aws cli
# ─────────────────────────────────────────
echo "[*] Installing AWS CLI..."
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp/aws-install
/tmp/aws-install/aws/install
rm -rf /tmp/awscliv2.zip /tmp/aws-install
aws --version
echo "[+] AWS CLI installed"

# ─────────────────────────────────────────
# malper-analyse
# ─────────────────────────────────────────
echo "[*] Installing malper-analyse..."
DEB_URL=$(curl -s https://api.github.com/repos/MKMithun2806/Malper-Analyse-Tool/releases/latest \
  | grep "browser_download_url.*\.deb" | cut -d '"' -f 4)
curl -sL "$DEB_URL" -o /tmp/malper-analyse.deb
dpkg -i /tmp/malper-analyse.deb
rm /tmp/malper-analyse.deb
echo "[+] malper-analyse installed"

# ─────────────────────────────────────────
# vulnmalper
# ─────────────────────────────────────────
echo "[*] Installing vulnmalper..."
URL=$(curl -s https://api.github.com/repos/MKMithun2806/VulnMalper/releases/latest \
  | grep browser_download_url | grep .deb | cut -d '"' -f 4)
curl -fsSL -o /tmp/vulnmalper.deb "$URL"
apt install -y /tmp/vulnmalper.deb
apt-get install -f -y
rm -f /tmp/vulnmalper.deb
echo "[+] vulnmalper installed"

# ─────────────────────────────────────────
# httpx
# ─────────────────────────────────────────
echo "[*] Installing httpx..."
tmp=$(mktemp -d)
HTTPX_URL=$(curl -fsSL https://api.github.com/repos/projectdiscovery/httpx/releases/latest \
  | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(next((a['browser_download_url'] for a in d.get('assets',[])
  if 'linux_amd64' in a.get('name','') and a.get('name','').endswith('.zip')), ''))
")
curl -fsSL "$HTTPX_URL" -o "$tmp/httpx.zip"
unzip -o "$tmp/httpx.zip" -d "$tmp"
chmod +x "$tmp/httpx"
mv "$tmp/httpx" /usr/local/bin/
rm -rf "$tmp"
httpx -version
echo "[+] httpx installed"

# ─────────────────────────────────────────
# chromium (head mode only)
# ─────────────────────────────────────────
if [[ "$MODE" == "head" ]]; then
  echo "[*] Installing chromium..."
  systemctl start snapd || true
  for i in {1..5}; do
    if apt-get install -y chromium-browser; then
      echo "[+] chromium installed"
      break
    fi
    echo "[!] Chromium install failed, retrying ($i/5)..."
    sleep 10
  done
else
  echo "[*] Skipping chromium (MODE is not 'head')"
fi

# ─────────────────────────────────────────
# orchestrator
# ─────────────────────────────────────────
echo ""
echo "[*] Pulling orchestrator..."
curl -fsSL https://raw.githubusercontent.com/MKMithun2806/Project-Watchdog-V2/refs/heads/main/Scripts/malper.sh \
  -o /usr/local/bin/malper.sh
chmod +x /usr/local/bin/malper.sh
echo "[+] Orchestrator ready"

tg "✅ *Setup complete\!*%0AStarting orchestrator..."
echo "[*] Starting orchestrator..."
exec /usr/local/bin/malper.sh
