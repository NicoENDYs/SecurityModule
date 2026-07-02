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
# Options:
#   --reports-dir DIR       Directory where reports are written
#                           (default: security/templates/reports;
#                           scan-full-dockerized.sh passes its session dir)
#   --network-host          Run the ZAP container with --network host so it can
#                           reach apps on localhost (used by the orchestrator)
#
# Authentication options (form login — url/user/pass required together):
#   --zap-auth-url   URL    Login form URL (e.g. https://app.example.com/login)
#   --zap-auth-user  USER   Username / email for login
#   --zap-auth-pass  PASS   Password for login
#   --zap-auth-loggedin  RE   Regex proving a logged-IN response (optional)
#   --zap-auth-loggedout RE   Regex proving a logged-OUT response
#                             (default: "(?i)(log ?in|sign ?in)")
#
# How authentication works: authenticated scans run through the ZAP Automation
# Framework (zap.sh -cmd -autorun) with a generated plan, because
# zap-baseline.py has no native form-auth support (its -c flag is for alert
# rules, not auth). Limitations in authenticated mode:
#   - The rules.tsv alert filter is NOT applied.
#   - Always verify the login actually worked: check the authentication lines
#     in the scan output and confirm authenticated pages appear in the report.
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
ZAP_AUTH_LOGGEDIN=""
ZAP_AUTH_LOGGEDOUT='(?i)(log ?in|sign ?in)'
AF_PLAN=""        # path to generated Automation Framework plan (auth mode only)
NETWORK_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reports-dir)         REPORTS_DIR="$2";         shift 2 ;;
    --network-host)        NETWORK_ARGS=(--network host); shift ;;
    --zap-auth-url)        ZAP_AUTH_URL="$2";        shift 2 ;;
    --zap-auth-user)       ZAP_AUTH_USER="$2";       shift 2 ;;
    --zap-auth-pass)       ZAP_AUTH_PASS="$2";       shift 2 ;;
    --zap-auth-loggedin)   ZAP_AUTH_LOGGEDIN="$2";   shift 2 ;;
    --zap-auth-loggedout)  ZAP_AUTH_LOGGEDOUT="$2";  shift 2 ;;
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

# ── Cleanup: remove temp Automation Framework plan on exit ───────────────────
# The generated plan contains credentials — never leave it behind.
cleanup() {
  [[ -n "$AF_PLAN" && -f "$AF_PLAN" ]] && rm -f "$AF_PLAN"
}
trap cleanup EXIT INT TERM

# ── Auth validation ────────────────────────────────────────────────────────────
if [[ -n "$ZAP_AUTH_URL" || -n "$ZAP_AUTH_USER" || -n "$ZAP_AUTH_PASS" ]]; then
  [[ -z "$ZAP_AUTH_URL" || -z "$ZAP_AUTH_USER" || -z "$ZAP_AUTH_PASS" ]] && \
    die "--zap-auth-url, --zap-auth-user, and --zap-auth-pass must all be provided together."
  log "Authenticated scan: login URL=$ZAP_AUTH_URL  user=$ZAP_AUTH_USER"
fi

# Escape a value for use inside a double-quoted YAML scalar.
yaml_escape() {
  local s=${1//\\/\\\\}
  s=${s//\"/\\\"}
  printf '%s' "$s"
}

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

if [[ -n "$ZAP_AUTH_URL" ]]; then
  # ── Authenticated scan — ZAP Automation Framework ────────────────────────────
  # zap-baseline.py cannot authenticate (its -c flag is for alert rules), so
  # authenticated scans run a generated Automation Framework plan instead.
  [[ -f "$ZAP_RULES" ]] && log "NOTE: rules.tsv alert filters are not applied in authenticated mode."

  AF_PLAN="$(mktemp /tmp/zap-af-plan-XXXXXX.yaml)"
  chmod 600 "$AF_PLAN"

  E_TARGET="$(yaml_escape "$TARGET_URL")"
  E_AUTH_URL="$(yaml_escape "$ZAP_AUTH_URL")"

  cat > "$AF_PLAN" <<EOF
env:
  contexts:
    - name: "default"
      urls:
        - "${E_TARGET}"
      includePaths:
        - "${E_TARGET}.*"
      authentication:
        method: "form"
        parameters:
          loginPageUrl: "${E_AUTH_URL}"
          loginRequestUrl: "${E_AUTH_URL}"
          loginRequestBody: "username={%username%}&password={%password%}"
        verification:
          method: "response"
          loggedOutRegex: "$(yaml_escape "$ZAP_AUTH_LOGGEDOUT")"
EOF
  if [[ -n "$ZAP_AUTH_LOGGEDIN" ]]; then
    printf '          loggedInRegex: "%s"\n' "$(yaml_escape "$ZAP_AUTH_LOGGEDIN")" >> "$AF_PLAN"
  fi
  cat >> "$AF_PLAN" <<EOF
      users:
        - name: "scan-user"
          credentials:
            username: "$(yaml_escape "$ZAP_AUTH_USER")"
            password: "$(yaml_escape "$ZAP_AUTH_PASS")"
  parameters:
    failOnError: true
    failOnWarning: false
    progressToStdout: true
jobs:
  - type: spider
    parameters:
      context: "default"
      user: "scan-user"
EOF
  if [[ "$SPIDER_MODE" == "ajax" ]]; then
    cat >> "$AF_PLAN" <<EOF
  - type: ajaxSpider
    parameters:
      context: "default"
      user: "scan-user"
EOF
  fi
  if [[ "$SPIDER_MODE" == "full" ]]; then
    cat >> "$AF_PLAN" <<EOF
  - type: activeScan
    parameters:
      context: "default"
      user: "scan-user"
EOF
  fi
  cat >> "$AF_PLAN" <<EOF
  - type: passiveScan-wait
  - type: report
    parameters:
      template: "traditional-html"
      reportDir: "/zap/wrk"
      reportFile: "${REPORT_BASE}"
  - type: report
    parameters:
      template: "traditional-json"
      reportDir: "/zap/wrk"
      reportFile: "${REPORT_BASE}"
  - type: report
    parameters:
      template: "traditional-md"
      reportDir: "/zap/wrk"
      reportFile: "${REPORT_BASE}"
EOF

  log "Running authenticated ZAP scan (Automation Framework)…"
  AF_EXIT=0
  docker run --rm \
    "${NETWORK_ARGS[@]+"${NETWORK_ARGS[@]}"}" \
    -v "$REPORTS_DIR":/zap/wrk/:rw \
    -v "$AF_PLAN":/zap/af-plan.yaml:ro \
    "$ZAP_IMAGE" zap.sh -cmd -autorun /zap/af-plan.yaml || AF_EXIT=$?

  if [[ $AF_EXIT -ne 0 ]]; then
    log "WARN: Automation Framework exited with code $AF_EXIT — review the output above."
  fi
  [[ -f "$REPORTS_DIR/${REPORT_BASE}.html" ]] || \
    die "ZAP did not produce a report — the automation plan failed. Check the output above."
  log "Verify the login actually worked: check the authentication messages above and confirm authenticated pages appear in the report."
else
  # ── Unauthenticated scan — zap-baseline.py / zap-full-scan.py ────────────────
  log "Running ZAP scan…"
  docker run --rm \
    "${NETWORK_ARGS[@]+"${NETWORK_ARGS[@]}"}" \
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
fi

log "Reports saved:"
log "  $REPORTS_DIR/${REPORT_BASE}.html"
log "  $REPORTS_DIR/${REPORT_BASE}.json"
log "  $REPORTS_DIR/${REPORT_BASE}.md"
log "Scan complete."
