#!/usr/bin/env bash
set -euo pipefail

#############################################
# DockSec Suite - Docker Image Security Scan
# Runs: Trivy + Dockle + Falco (runtime)
#
# Author: Armors Security (Champa)
# Version: 1.0
#############################################

# -------- CONFIG --------
REPORT_DIR="reports"
PERIMG_DIR="$REPORT_DIR/per-image"
COMBINED_DIR="$REPORT_DIR/combined"
FALCO_LOG="$REPORT_DIR/falco_runtime.log"
FALCO_CONTAINER="docksec_falco"
FALCO_IMAGE="falcosecurity/falco:0.42.1"

mkdir -p "$PERIMG_DIR" "$COMBINED_DIR"

COMBINED_CSV="$COMBINED_DIR/docksec_all_images.csv"

# -------- HELPER: check dependency --------
check_cmd() {
  local cmd="$1"
  local url="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[!] Required command '$cmd' not found in PATH."
    echo "    Please install it first: $url"
    exit 1
  fi
}

# -------- CHECK DEPENDENCIES --------
check_cmd docker "https://docs.docker.com/get-docker/"
check_cmd trivy "https://aquasecurity.github.io/trivy/v0.56.0/getting-started/installation/"
check_cmd dockle "https://github.com/goodwithtech/dockle"
check_cmd jq "https://stedolan.github.io/jq/"

# -------- PULL FALCO IMAGE (optional but recommended) --------
FALCO_AVAILABLE=1
if ! docker image inspect "$FALCO_IMAGE" >/dev/null 2>&1; then
  echo "[+] Falco image not found locally. Pulling $FALCO_IMAGE ..."
  if ! docker pull "$FALCO_IMAGE"; then
    echo "[!] Failed to pull Falco image. Runtime monitoring will be skipped."
    FALCO_AVAILABLE=0
  fi
fi

# -------- PREPARE COMBINED CSV --------
echo 'SourceImage,Scanner,Target,Package,VulnerabilityID,Title,Severity,Installed,Fixed,Ref' > "$COMBINED_CSV"

#############################################
# INPUT: ask user how to provide images
#############################################

echo "=============================================="
echo "           DOCKSEC - FULL SECURITY SCAN"
echo "=============================================="
echo ""
echo "How do you want to provide Docker images?"
echo "  1) Enter ONE image manually"
echo "  2) Enter MULTIPLE images manually"
echo "  3) Provide a FILE with one image per line"
echo ""

read -rp "Select option (1/2/3): " INPUT_MODE

IMAGES=()

case "$INPUT_MODE" in
  1)
    read -rp "Enter Docker image (e.g. python:3.12): " IMG
    IMAGES+=("$IMG")
    ;;
  2)
    echo "Enter images (type 'done' when finished):"
    while true; do
      read -rp "> " IMG
      [[ "$IMG" == "done" ]] && break
      [[ -n "$IMG" ]] && IMAGES+=("$IMG")
    done
    ;;
  3)
    read -rp "Enter path to image list file: " FILE
    if [[ ! -f "$FILE" ]]; then
      echo "[!] File not found: $FILE"
      exit 1
    fi
    while IFS= read -r LINE; do
      [[ -z "$LINE" ]] && continue
      [[ "$LINE" =~ ^# ]] && continue
      IMAGES+=("$LINE")
    done < "$FILE"
    ;;
  *)
    echo "[!] Invalid option"
    exit 1
    ;;
esac

if [[ ${#IMAGES[@]} -eq 0 ]]; then
  echo "[!] No images provided. Exiting."
  exit 1
fi

#############################################
# START FALCO (if available)
#############################################

if [[ "$FALCO_AVAILABLE" -eq 1 ]]; then
  echo "[+] Starting Falco runtime monitor container..."

  docker rm -f "$FALCO_CONTAINER" >/dev/null 2>&1 || true

  docker run -d \
    --name "$FALCO_CONTAINER" \
    --privileged \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /dev:/host/dev \
    -v /proc:/host/proc:ro \
    -v /boot:/host/boot:ro \
    -v /lib/modules:/host/lib/modules:ro \
    -v /usr:/host/usr:ro \
    "$FALCO_IMAGE" >/dev/null

  # give Falco a moment to boot
  sleep 5
  echo "[+] Falco started."
else
  echo "[!] Falco not available. Skipping runtime monitoring."
fi

#############################################
# MAIN LOOP: scan each image
#############################################

for IMAGE in "${IMAGES[@]}"; do
  SAFE_NAME="$(echo "$IMAGE" | tr '/:' '__')"

  echo ""
  echo "=============================================="
  echo "          PROCESSING IMAGE: $IMAGE"
  echo "=============================================="

  # Pull image (if not present)
  if docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "[+] Image already present locally."
    PULLED_BY_SCRIPT=0
  else
    echo "[+] Pulling image from registry..."
    docker pull "$IMAGE"
    PULLED_BY_SCRIPT=1
  fi

  ########################################
  # TRIVY SCAN
  ########################################
  TRIVY_JSON="$PERIMG_DIR/trivy_${SAFE_NAME}.json"
  echo "[+] Running Trivy..."
  trivy image \
    --scanners vuln \
    --format json \
    -o "$TRIVY_JSON" \
    "$IMAGE"

  echo "[+] Adding Trivy results to combined CSV..."
  jq -r --arg image "$IMAGE" '
    .Results[]
    | .Target as $target
    | (.Vulnerabilities // [])[]
    | [
        $image,                     # SourceImage
        "Trivy",                    # Scanner
        $target,                    # Target (core package / jar / layer)
        .PkgName,                   # Package
        .VulnerabilityID,           # CVE / Advisory ID
        ( .Title // "" | gsub("[\r\n]"; " ") ), # Title (one line)
        .Severity,                  # Severity
        ( .InstalledVersion // "" ),# Installed
        ( .FixedVersion // "" ),    # Fixed
        ( .PrimaryURL // "" )       # Ref
      ]
      | @csv
  ' "$TRIVY_JSON" >> "$COMBINED_CSV"

  ########################################
  # DOCKLE SCAN
  ########################################
  DOCKLE_TXT="$PERIMG_DIR/dockle_${SAFE_NAME}.txt"
  echo "[+] Running Dockle..."
  # Dockle exits non-zero for findings, so we don't fail the script
  if dockle "$IMAGE" > "$DOCKLE_TXT" 2>&1; then
    DOCKLE_STATUS="OK"
  else
    DOCKLE_STATUS="WARNINGS"
  fi

  # Add a simple row pointing to Dockle text output
  echo "\"$IMAGE\",\"Dockle\",\"Image\",\"Config\",\"-\",\"See dockle_${SAFE_NAME}.txt ($DOCKLE_STATUS)\",\"INFO\",\"-\",\"-\",\"-\"" >> "$COMBINED_CSV"

  ########################################
  # FALCO RUNTIME CHECK (if available)
  ########################################

  if [[ "$FALCO_AVAILABLE" -eq 1 ]]; then
    echo "[+] Starting short-lived container for Falco runtime check..."
    TEST_CONTAINER="docksec_test_${SAFE_NAME}"

    # run a simple long-lived command so Falco can observe it
    if docker run -d --name "$TEST_CONTAINER" "$IMAGE" tail -f /dev/null >/dev/null 2>&1; then
      # give Falco a few seconds to observe
      sleep 5
      docker rm -f "$TEST_CONTAINER" >/dev/null 2>&1 || true
    else
      echo "[!] Could not start test container for $IMAGE (may not support tail -f /dev/null). Skipping Falco runtime for this image."
    fi
  fi

  ########################################
  # CLEANUP IMAGE (optional)
  ########################################

  echo "[+] Removing image locally to save disk..."
  docker rmi "$IMAGE" >/dev/null 2>&1 || true

done

#############################################
# STOP FALCO & SAVE LOGS
#############################################

if [[ "$FALCO_AVAILABLE" -eq 1 ]]; then
  echo "[+] Stopping Falco and saving logs..."
  mkdir -p "$REPORT_DIR"
  docker logs "$FALCO_CONTAINER" > "$FALCO_LOG" 2>&1 || true
  docker rm -f "$FALCO_CONTAINER" >/dev/null 2>&1 || true
else
  echo "[!] Falco was not running, no runtime log captured."
fi

#############################################
# FINAL SUMMARY
#############################################

echo ""
echo "=============================================="
echo "           DOCKSEC SCAN COMPLETED"
echo "=============================================="
echo "Combined CSV report : $COMBINED_CSV"
echo "Per-image Trivy JSON: $PERIMG_DIR/trivy_*.json"
echo "Per-image Dockle txt: $PERIMG_DIR/dockle_*.txt"
if [[ "$FALCO_AVAILABLE" -eq 1 ]]; then
  echo "Falco runtime log   : $FALCO_LOG"
else
  echo "Falco runtime log   : (not available - Falco not pulled)"
fi
echo ""
echo "All images processed and local copies removed."
echo "=============================================="

