#!/bin/bash
set -e

echo "[*] Starting Malper setup..."

# --- base dependencies ---
echo "[*] Installing base dependencies..."
sudo apt-get update
sudo apt-get install -y curl wget unzip python3 uuid-runtime ca-certificates gnupg lsb-release

# --- docker ---
echo "[*] Installing Docker..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker "$USER" || true
echo "[+] Docker installed"

# --- aws cli ---
echo "[*] Installing AWS CLI..."
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp/aws-install
sudo /tmp/aws-install/aws/install
rm -rf /tmp/awscliv2.zip /tmp/aws-install
aws --version
echo "[+] AWS CLI installed"

# --- malper-analyse ---
echo "[*] Installing malper-analyse..."
curl -sL $(curl -s https://api.github.com/repos/MKMithun2806/Malper-Analyse-Tool/releases/latest \
  | grep "browser_download_url.*\.deb" \
  | cut -d '"' -f 4) -o /tmp/malper-analyse.deb
sudo dpkg -i /tmp/malper-analyse.deb
rm /tmp/malper-analyse.deb
echo "[+] malper-analyse installed"

# --- vulnmalper ---
echo "[*] Installing vulnmalper..."
URL=$(curl -s https://api.github.com/repos/MKMithun2806/VulnMalper/releases/latest \
  | grep browser_download_url | grep .deb | cut -d '"' -f 4)
curl -L -o /tmp/vulnmalper.deb "$URL"
sudo apt install -y /tmp/vulnmalper.deb
sudo apt-get install -f -y
rm -f /tmp/vulnmalper.deb
echo "[+] vulnmalper installed"

# --- docker image ---
echo "[*] Pulling malper-suite docker image..."
sudo docker pull mitchaster/malper-suite:latest
echo "[+] Docker image ready"

# --- httpx ---
echo "[*] Installing httpx..."
tmp=$(mktemp -d) && cd "$tmp"
url=$(curl -fsSL https://api.github.com/repos/projectdiscovery/httpx/releases/latest \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(next((a['browser_download_url'] for a in d.get('assets',[]) if 'linux_amd64' in a.get('name','') and a.get('name','').endswith('.zip')), ''))")
curl -fL "$url" -o httpx.zip
unzip -o httpx.zip && chmod +x httpx
sudo mv httpx /usr/local/bin/
cd / && rm -rf "$tmp"
httpx -version
echo "[+] httpx installed"

# --- chromium ---
echo "[*] Installing chromium..."
sudo apt-get install -y chromium-browser
echo "[+] chromium installed"

echo ""
echo "[*] Pulling orchestrator..."
curl -fsSL https://raw.githubusercontent.com/MKMithun2806/Project-Watchdog-V2/refs/heads/main/Scripts/malper.sh \
  -o /usr/local/bin/malper.sh
chmod +x /usr/local/bin/malper.sh
echo "[+] Orchestrator ready"

echo "[*] Starting orchestrator..."
/usr/local/bin/malper.sh
