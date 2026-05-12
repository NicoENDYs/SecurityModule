#!/usr/bin/env bash
# scan-zap-baseline.sh — Run OWASP ZAP scan locally via Docker.
# No ZAP installation required on the host.
#
# Usage:
#   ./scripts/scan-zap-baseline.sh <target-url> [mode]
#
# Modes:
#   baseline  (default) Passive scan — safe against any URL
#   ajax               Passive scan + ajax spider for SPAs (still passive)
#   full               ACTIVE scan — sends attack payloads. Only run against
#                      targets you own. Requires: I_OWN_THIS_TARGET=yes
#
# Examples:
#   ./scripts/scan-zap-baseline.sh https://staging.example.com
#   ./scripts/scan-zap-baseline.sh https://staging.example.com ajax
#   I_OWN_THIS_TARGET=yes ./scripts/scan-zap-baseline.sh https://staging.example.com full
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECURITY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../versions.env
source "$SECURITY_ROOT/versions.env"
[[ -n "${ZAP_VERSION:-}" ]] || die "ZAP_VERSION is unset — versions.env not loaded properly"

ZAP_IMAGE="ghcr.io/zaproxy/zaproxy:${ZAP_VERSION}"
REPORTS_DIR="$SECURITY_ROOT/templates/reports"
ZAP_RULES="$SECURITY_ROOT/templates/zap/rules.tsv"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

log() { printf '\033[1;35m[zap]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; }
die() { err "$*"; exit 1; }

require_docker() {
  command -v docker &>/dev/null || die "Docker is not installed or not in PATH."
  docker info &>/dev/null 2>&1 || die "Docker daemon is not running. Start Docker and retry."
}

require_docker

[[ -z "${1:-}" ]] && die "Usage: $0 <target-url> [baseline|ajax|full]"

TARGET_URL="$1"
SPIDER_MODE="${2:-baseline}"
SAFE_NAME=$(printf '%s' "$TARGET_URL" | tr -c '[:alnum:]_.-' '_')
REPORT_BASE="zap-${SPIDER_MODE}_${SAFE_NAME}_${TIMESTAMP}"

mkdir -p "$REPORTS_DIR"

log "Target URL : $TARGET_URL"
log "Scan mode  : $SPIDER_MODE"
log "Reports dir: $REPORTS_DIR"

# Resolve ZAP command and arguments based on mode
case "$SPIDER_MODE" in
  baseline)
    ZAP_CMD="zap-baseline.py"
    ZAP_EXTRA_ARGS=()
    ;;
  ajax)
    # Passive scan with ajax spider — safe for SPAs, still does NOT send attack payloads
    ZAP_CMD="zap-baseline.py"
    ZAP_EXTRA_ARGS=(-j)
    ;;
  full)
    # Active scan: sends attack payloads. Requires explicit consent.
    if [[ "${I_OWN_THIS_TARGET:-}" != "yes" ]]; then
      die "Active scan requires explicit consent. Re-run with:
  I_OWN_THIS_TARGET=yes $0 $TARGET_URL full
WARNING: Only scan targets you own or have written permission to test."
    fi
    log "WARNING: Active scan enabled against $TARGET_URL"
    ZAP_CMD="zap-full-scan.py"
    ZAP_EXTRA_ARGS=()
    ;;
  *)
    die "Unknown mode '$SPIDER_MODE'. Use: baseline | ajax | full"
    ;;
esac

RULES_MOUNT=()
RULES_FLAG=()
if [[ -f "$ZAP_RULES" ]]; then
  RULES_MOUNT=(-v "$ZAP_RULES":/zap/rules.tsv:ro)
  RULES_FLAG=(-c /zap/rules.tsv)
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
    "${ZAP_EXTRA_ARGS[@]+"${ZAP_EXTRA_ARGS[@]}"}" \
    "${RULES_FLAG[@]+"${RULES_FLAG[@]}"}" \
    -I || {
  EXIT=$?
  # ZAP exits non-zero when alerts are found; that is expected.
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
