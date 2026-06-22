#!/usr/bin/env bash
# scan-zap-baseline.sh — Run OWASP ZAP scan locally via Docker.
# No ZAP installation required on the host.
#
# Usage:
#   ./scripts/scan-zap-baseline.sh [OPTIONS] <target-url> [mode]
#
# Modes:
#   baseline  (default) Passive scan — safe against any URL
#   ajax               Passive scan + ajax spider for SPAs (still passive)
#   full               ACTIVE scan — sends attack payloads. Only run against
#                      targets you own. Requires: I_OWN_THIS_TARGET=yes
#
# Authentication options (all three required together):
#   --zap-auth-url   URL    Login form URL (e.g. https://app.example.com/login)
#   --zap-auth-user  USER   Username / email for login
#   --zap-auth-pass  PASS   Password for login
#
# Examples:
#   ./scripts/scan-zap-baseline.sh https://staging.example.com
#   ./scripts/scan-zap-baseline.sh https://staging.example.com ajax
#   I_OWN_THIS_TARGET=yes ./scripts/scan-zap-baseline.sh https://staging.example.com full
#   ./scripts/scan-zap-baseline.sh \
#     --zap-auth-url https://app.example.com/login \
#     --zap-auth-user admin --zap-auth-pass secret \
#     https://app.example.com baseline
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECURITY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Logging helpers — defined before sourcing versions.env so the guard below can
# call die() with a clear message (Bash has no function hoisting).
log() { printf '\033[1;35m[zap]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; }
die() { err "$*"; exit 1; }

# shellcheck source=../versions.env
source "$SECURITY_ROOT/versions.env"
[[ -n "${ZAP_VERSION:-}" ]] || die "ZAP_VERSION is unset — versions.env not loaded properly"

ZAP_IMAGE="ghcr.io/zaproxy/zaproxy:${ZAP_VERSION}"
REPORTS_DIR="$SECURITY_ROOT/templates/reports"
ZAP_RULES="$SECURITY_ROOT/templates/zap/rules.tsv"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

require_docker() {
  command -v docker &>/dev/null || die "Docker is not installed or not in PATH."
  docker info &>/dev/null 2>&1 || die "Docker daemon is not running. Start Docker and retry."
}

# ── Argument parsing ───────────────────────────────────────────────────────────
ZAP_AUTH_URL=""
ZAP_AUTH_USER=""
ZAP_AUTH_PASS=""
ZAP_AUTH_CONF=""  # path to generated temp conf, set later if auth is requested

while [[ $# -gt 0 ]]; do
  case "$1" in
    --zap-auth-url)  ZAP_AUTH_URL="$2";  shift 2 ;;
    --zap-auth-user) ZAP_AUTH_USER="$2"; shift 2 ;;
    --zap-auth-pass) ZAP_AUTH_PASS="$2"; shift 2 ;;
    --) shift; break ;;
    -*) die "Unknown option: $1. Use --help for usage." ;;
    *)  break ;;
  esac
done

require_docker

[[ -z "${1:-}" ]] && die "Usage: $0 [--zap-auth-url URL --zap-auth-user USER --zap-auth-pass PASS] <target-url> [baseline|ajax|full]"

TARGET_URL="$1"
SPIDER_MODE="${2:-baseline}"
SAFE_NAME=$(printf '%s' "$TARGET_URL" | tr -c '[:alnum:]_.-' '_')
REPORT_BASE="zap-${SPIDER_MODE}_${SAFE_NAME}_${TIMESTAMP}"

mkdir -p "$REPORTS_DIR"

# ── Cleanup: remove temp auth conf on exit ────────────────────────────────────
cleanup() {
  [[ -n "$ZAP_AUTH_CONF" && -f "$ZAP_AUTH_CONF" ]] && rm -f "$ZAP_AUTH_CONF"
}
trap cleanup EXIT INT TERM

# ── Optional: generate temp ZAP auth config ───────────────────────────────────
AUTH_MOUNT=()
AUTH_FLAG=()
if [[ -n "$ZAP_AUTH_URL" || -n "$ZAP_AUTH_USER" || -n "$ZAP_AUTH_PASS" ]]; then
  [[ -z "$ZAP_AUTH_URL" || -z "$ZAP_AUTH_USER" || -z "$ZAP_AUTH_PASS" ]] && \
    die "--zap-auth-url, --zap-auth-user, and --zap-auth-pass must all be provided together."
  ZAP_AUTH_CONF="$(mktemp /tmp/zap-auth-XXXXXX.conf)"
  cat > "$ZAP_AUTH_CONF" <<EOF
# Auto-generated ZAP auth config — deleted after scan
auth.loginUrl=${ZAP_AUTH_URL}
auth.loginRequestData=username%3D%7B%25username%25%7D%26password%3D%7B%25password%25%7D
auth.usernameParameter=username
auth.passwordParameter=password
auth.loggedInIndicator=\\QDashboard\\E
auth.loggedOutIndicator=\\QSign in\\E
users.user1.credentials.username=${ZAP_AUTH_USER}
users.user1.credentials.password=${ZAP_AUTH_PASS}
EOF
  AUTH_MOUNT=(-v "$ZAP_AUTH_CONF":/zap/wrk/auth.conf:ro)
  AUTH_FLAG=(-c /zap/wrk/auth.conf)
  log "Auth config: login URL=$ZAP_AUTH_URL  user=$ZAP_AUTH_USER"
fi

log "Target URL : $TARGET_URL"
log "Scan mode  : $SPIDER_MODE"
log "Reports dir: $REPORTS_DIR"

# ── Resolve ZAP command and arguments based on mode ───────────────────────────
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
  "${AUTH_MOUNT[@]+"${AUTH_MOUNT[@]}"}" \
  "$ZAP_IMAGE" "$ZAP_CMD" \
    -t "$TARGET_URL" \
    -r "${REPORT_BASE}.html" \
    -J "${REPORT_BASE}.json" \
    -w "${REPORT_BASE}.md" \
    "${ZAP_EXTRA_ARGS[@]+"${ZAP_EXTRA_ARGS[@]}"}" \
    "${RULES_FLAG[@]+"${RULES_FLAG[@]}"}" \
    "${AUTH_FLAG[@]+"${AUTH_FLAG[@]}"}" \
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
