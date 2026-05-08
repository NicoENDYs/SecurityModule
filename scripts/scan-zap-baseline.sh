#!/usr/bin/env bash
# scan-zap-baseline.sh — Run OWASP ZAP baseline scan locally via Docker.
# No ZAP installation required on the host.
#
# Usage:
#   ./scripts/scan-zap-baseline.sh <target-url> [ajax]
#
# Examples:
#   ./scripts/scan-zap-baseline.sh https://staging.example.com
#   ./scripts/scan-zap-baseline.sh https://staging.example.com ajax   # uses ajaxSpider
set -euo pipefail

ZAP_IMAGE="ghcr.io/zaproxy/zaproxy:stable"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPORTS_DIR="$REPO_ROOT/templates/reports"
ZAP_RULES="$REPO_ROOT/templates/zap/rules.tsv"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

log()  { printf '\033[1;35m[zap]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

command -v docker &>/dev/null || die "Docker is not installed or not in PATH."

[[ -z "${1:-}" ]] && die "Usage: $0 <target-url> [ajax]"

TARGET_URL="$1"
SPIDER_MODE="${2:-baseline}"
SAFE_NAME="$(echo "$TARGET_URL" | sed 's|[^a-zA-Z0-9]|_|g')"
REPORT_BASE="zap-${SPIDER_MODE}_${SAFE_NAME}_${TIMESTAMP}"

mkdir -p "$REPORTS_DIR"

log "Target URL : $TARGET_URL"
log "Spider mode: $SPIDER_MODE"
log "Reports dir: $REPORTS_DIR"

ZAP_CMD="zap-baseline.py"
[[ "$SPIDER_MODE" == "ajax" ]] && ZAP_CMD="zap-full-scan.py"

RULES_MOUNT=()
if [[ -f "$ZAP_RULES" ]]; then
  RULES_MOUNT=(-v "$ZAP_RULES":/zap/rules.tsv:ro)
  RULES_FLAG=(-c /zap/rules.tsv)
else
  RULES_FLAG=()
fi

log "Pulling ZAP image (if not cached)…"
docker pull "$ZAP_IMAGE" --quiet

log "Running ZAP scan…"
docker run --rm \
  -v "$REPORTS_DIR":/zap/wrk/:rw \
  "${RULES_MOUNT[@]+"${RULES_MOUNT[@]}"}" \
  "$ZAP_IMAGE" "$ZAP_CMD" \
    -t "$TARGET_URL" \
    -r "${REPORT_BASE}.html" \
    -J "${REPORT_BASE}.json" \
    -w "${REPORT_BASE}.md" \
    "${RULES_FLAG[@]+"${RULES_FLAG[@]}"}" \
    -I || {
  EXIT=$?
  # ZAP exits non-zero when alerts are found; that is expected and not a tool failure.
  if [[ $EXIT -eq 2 ]]; then
    log "WARN: ZAP found FAIL-level alerts (exit 2). Review the report."
  elif [[ $EXIT -ne 0 ]]; then
    die "ZAP exited with unexpected code $EXIT."
  fi
}

log "Reports saved:"
log "  $REPORTS_DIR/${REPORT_BASE}.html"
log "  $REPORTS_DIR/${REPORT_BASE}.json"
log "  $REPORTS_DIR/${REPORT_BASE}.md"
log "Scan complete."
