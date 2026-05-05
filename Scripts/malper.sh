#!/bin/bash
set -e

# env vars injected by Lambda via user data:
# TARGET, MODE, SUPABASE_URL, SUPABASE_KEY, SUPABASE_BUCKET, OPENROUTER_API_KEY

if [[ -z "$TARGET" ]]; then
  echo "[!] TARGET not set"; exit 1
fi
if [[ -z "$OPENROUTER_API_KEY" ]]; then
  echo "[!] OPENROUTER_API_KEY not set"; exit 1
fi
if [[ -z "$SUPABASE_URL" || -z "$SUPABASE_KEY" || -z "$SUPABASE_BUCKET" ]]; then
  echo "[!] Missing Supabase env vars"; exit 1
fi

export OPENROUTER_API_KEY="$OPENROUTER_API_KEY"

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

# ─────────────────────────────────────────
# 1. netmalper (docker)
# ─────────────────────────────────────────
echo "[*] Running netmalper..."
sudo docker run --rm \
  -v "$SCAN_DIR":/app \
  mitchaster/malper-suite:latest \
  "$TARGET"

GRAPH=$(ls "$SCAN_DIR"/*_graph.json 2>/dev/null | head -1)
if [[ -z "$GRAPH" ]]; then
  echo "[!] netmalper produced no graph JSON"; exit 1
fi
echo "[+] Graph: $GRAPH"

# ─────────────────────────────────────────
# 2. vulnmalper
# ─────────────────────────────────────────
echo "[*] Running vulnmalper (mode: ${MODE:-normal})..."
cd "$SCAN_DIR"
sudo vulnmalper $VULNMALPER_FLAGS "$(basename "$GRAPH")"

REPORT=$(ls "$SCAN_DIR"/vulnmalper_*.md 2>/dev/null | grep -v '_analysed_' | head -1)
if [[ -z "$REPORT" ]]; then
  echo "[!] vulnmalper produced no report"; exit 1
fi
echo "[+] Report: $REPORT"

# ─────────────────────────────────────────
# 3. malper-analyse
# ─────────────────────────────────────────
echo "[*] Running malper-analyse..."
cd "$SCAN_DIR"
malper-analyse "$(basename "$REPORT")"

SUMMARY=$(ls "$SCAN_DIR"/*_analysed_*.md 2>/dev/null | head -1)
if [[ -z "$SUMMARY" ]]; then
  echo "[!] malper-analyse produced no summary"; exit 1
fi
echo "[+] Summary: $SUMMARY"

# ─────────────────────────────────────────
# 4. push to supabase
# ─────────────────────────────────────────
echo "[*] Pushing to Supabase..."

SCAN_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
REMOTE_FOLDER="$TARGET/$SCAN_ID"

upload_file() {
  local file=$1
  local remote_name=$2
  echo "[*] Uploading $remote_name..."
  local res
  res=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "$SUPABASE_URL/storage/v1/object/$SUPABASE_BUCKET/$REMOTE_FOLDER/$remote_name" \
    -H "Authorization: Bearer $SUPABASE_KEY" \
    -H "Content-Type: application/octet-stream" \
    --data-binary @"$file")
  if [[ "$res" != "200" ]]; then
    echo "[!] Upload failed for $remote_name (HTTP $res)"; exit 1
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
  echo "[!] DB insert failed (HTTP $res)"; exit 1
fi

echo "[+] Scan ID: $SCAN_ID"
echo "[+] Pipeline complete. Terminating instance..."

# ─────────────────────────────────────────
# 5. terminate EC2
# ─────────────────────────────────────────
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

aws ec2 terminate-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION"
