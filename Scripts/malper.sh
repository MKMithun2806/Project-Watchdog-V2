#!/bin/bash
set -e

# env vars injected by Lambda via user data:
# TARGET, MODE, SUPABASE_URL, SUPABASE_KEY, SUPABASE_BUCKET, OPENROUTER_API_KEY
# TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID

if [[ -z "$TARGET" ]]; then
  echo "[!] TARGET not set"; exit 1
fi
if [[ -z "$OPENROUTER_API_KEY" ]]; then
  echo "[!] OPENROUTER_API_KEY not set"; exit 1
fi
if [[ -z "$SUPABASE_URL" || -z "$SUPABASE_KEY" || -z "$SUPABASE_BUCKET" ]]; then
  echo "[!] Missing Supabase env vars"; exit 1
fi
if [[ -z "$TELEGRAM_BOT_TOKEN" || -z "$TELEGRAM_CHAT_ID" ]]; then
  echo "[!] Missing Telegram env vars"; exit 1
fi

export OPENROUTER_API_KEY="$OPENROUTER_API_KEY"

# ─────────────────────────────────────────
# telegram notify function
# ─────────────────────────────────────────
tg() {
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=$1" \
    -d "parse_mode=Markdown" > /dev/null
}

# ─────────────────────────────────────────
# telegram send log file
# ─────────────────────────────────────────
send_log_file() {
  [ -f /var/log/malper.log ] || return 0
  local ts=$(date -u +"%Y-%m-%d %H:%M:%SZ")
  local caption="📋 *Log:* \`$TARGET\` | \`${MODE:-normal}\` | $ts"
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument" \
    -F "chat_id=${TELEGRAM_CHAT_ID}" \
    -F "document=@/var/log/malper.log" \
    -F "caption=$caption" \
    -F "parse_mode=Markdown" > /dev/null
}

# ─────────────────────────────────────────
# trap — fires on any unexpected failure
# ─────────────────────────────────────────
on_error() {
  local exit_code=$?
  local line=$1
  local last_log=$(tail -5 /var/log/malper.log 2>/dev/null | tr '\n' '|')
  tg "💀 *Malper crashed*%0ATarget: \`$TARGET\`%0ALine: \`$line\`%0AExit: \`$exit_code\`%0A%0A*Last logs:*%0A\`$last_log\`%0A%0ATerminating..."
  send_log_file
  INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
  REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
  aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" --region "$REGION" || true
}

trap 'on_error $LINENO' ERR

# --- mode flags ---
case "${MODE:-normal}" in
  normal)
    VULNMALPER_FLAGS=""
    ;;
  stealth)
    VULNMALPER_FLAGS="--polite --quiet"
    ;;
  head)
    VULNMALPER_FLAGS="--polite --quiet --headless"
    ;;
  *)
    echo "[!] Unknown mode: $MODE (valid: normal, stealth, head)"
    exit 1
    ;;
esac

echo "[*] Target : $TARGET"
echo "[*] Mode   : ${MODE:-normal}"
echo "[*] Flags  : ${VULNMALPER_FLAGS:-none}"

SCAN_BASE="/opt/malper/scans"
SCAN_DIR="$SCAN_BASE/$TARGET"
mkdir -p "$SCAN_DIR"

tg "🟢 *Malper Online*%0ATarget: \`$TARGET\` | Mode: \`${MODE:-normal}\`"

# ─────────────────────────────────────────
# 1. netmalper (docker)
# ─────────────────────────────────────────
tg "🔍 *netmalper started*%0ATarget: \`$TARGET\`"
echo "[*] Running netmalper..."
sudo docker run --rm \
  -v "$SCAN_DIR":/app \
  mitchaster/malper-suite:latest \
  "$TARGET" 2>&1 | tee -a /var/log/malper.log

GRAPH=$(ls "$SCAN_DIR"/*_graph.json 2>/dev/null | head -1)
if [[ -z "$GRAPH" ]]; then
  tg "❌ *netmalper failed* — no graph JSON produced"
  exit 1
fi
echo "[+] Graph: $GRAPH"

# ─────────────────────────────────────────
# 2. vulnmalper
# ─────────────────────────────────────────
tg "🔎 *vulnmalper started*%0AMode: \`${MODE:-normal}\`"
echo "[*] Running vulnmalper (mode: ${MODE:-normal})..."
cd "$SCAN_DIR"
sudo vulnmalper $VULNMALPER_FLAGS "$(basename "$GRAPH")" 2>&1 | tee -a /var/log/malper.log

REPORT=$(ls "$SCAN_DIR"/vulnmalper_*.md 2>/dev/null | grep -v '_analysed_' | head -1)
if [[ -z "$REPORT" ]]; then
  tg "❌ *vulnmalper failed* — no report produced"
  exit 1
fi
echo "[+] Report: $REPORT"

# ─────────────────────────────────────────
# 3. malper-analyse
# ─────────────────────────────────────────
tg "🧠 *malper-analyse started*"
echo "[*] Running malper-analyse..."
cd "$SCAN_DIR"
malper-analyse "$(basename "$REPORT")" 2>&1 | tee -a /var/log/malper.log

SUMMARY=$(ls "$SCAN_DIR"/*_analysed_*.md 2>/dev/null | head -1)
if [[ -z "$SUMMARY" ]]; then
  tg "❌ *malper-analyse failed* — no summary produced"
  exit 1
fi
echo "[+] Summary: $SUMMARY"

# ─────────────────────────────────────────
# 4. push to supabase
# ─────────────────────────────────────────
tg "☁️ *Pushing to Supabase...*"
echo "[*] Pushing to Supabase..."

SCAN_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
REMOTE_FOLDER="$TARGET/$SCAN_ID"

upload_file() {
  local file=$1
  local remote_name=$2
  echo "[*] Uploading $remote_name..."
  local body
  local res
  body=$(curl -s -w "\n%{http_code}" -X POST \
    "$SUPABASE_URL/storage/v1/object/$SUPABASE_BUCKET/$REMOTE_FOLDER/$remote_name" \
    -H "Authorization: Bearer $SUPABASE_KEY" \
    -H "Content-Type: application/octet-stream" \
    --data-binary @"$file")
  res=$(echo "$body" | tail -1)
  echo "[*] Upload response for $remote_name: $res — $(echo "$body" | head -1)"
  if [[ "$res" != "200" && "$res" != "201" ]]; then
    tg "❌ *Supabase upload failed* — $remote_name (HTTP $res)"
    exit 1
  fi
  echo "[+] $remote_name uploaded"
}

upload_file "$GRAPH"   "attack_surface.json"
upload_file "$REPORT"  "report.md"
upload_file "$SUMMARY" "summary.md"

echo "[*] Inserting scan record..."
res=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "$SUPABASE_URL/rest/v1/recon_scans" \
  -H "Authorization: Bearer $SUPABASE_KEY" \
  -H "apikey: $SUPABASE_KEY" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=minimal" \
  -d "{
    \"id\": \"$SCAN_ID\",
    \"target\": \"$TARGET\",
    \"graph_url\": \"$REMOTE_FOLDER/attack_surface.json\",
    \"report_url\": \"$REMOTE_FOLDER/report.md\",
    \"summary_url\": \"$REMOTE_FOLDER/summary.md\"
  }")

if [[ "$res" != "201" ]]; then
  tg "❌ *DB insert failed* (HTTP $res)"
  exit 1
fi

echo "[+] Scan ID: $SCAN_ID"
tg "✅ *Scan done\!*%0ATarget: \`$TARGET\`%0AScan ID: \`$SCAN_ID\`"
echo "[+] Pipeline complete. Terminating instance..."

send_log_file

# ─────────────────────────────────────────
# 5. terminate EC2
# ─────────────────────────────────────────
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

aws ec2 terminate-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION"
