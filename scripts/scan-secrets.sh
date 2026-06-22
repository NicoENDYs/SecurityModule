#!/usr/bin/env bash
# scan-secrets.sh — Run Gitleaks locally via Docker to find leaked credentials.
# No Gitleaks installation required on the host. Mirrors scan-trivy.sh.
#
# Usage:
#   ./scripts/scan-secrets.sh git [path]   # scan full git history (default mode)
#   ./scripts/scan-secrets.sh dir [path]   # scan working tree only (no git history)
#
# Notes:
#   - 'git' mode scans the entire commit history and needs a full clone
#     (not --depth=1). In CI run: git fetch --unshallow || true
#   - Reports (SARIF + JSON) are written to templates/reports/.
#   - Exit code is forced to 0 so a finding does not abort the script; review
#     the printed summary and the reports instead.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECURITY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Logging helpers — defined before sourcing versions.env so the guard below can
# call die() with a clear message (Bash has no function hoisting).
log() { printf '\033[1;32m[secrets]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; }
die() { err "$*"; exit 1; }

# shellcheck source=../versions.env
source "$SECURITY_ROOT/versions.env"
[[ -n "${GITLEAKS_VERSION:-}" ]] || die "GITLEAKS_VERSION is unset — versions.env not loaded properly"

# Gitleaks Docker tags are prefixed with "v"; versions.env stores the bare version.
GITLEAKS_IMAGE="zricethezav/gitleaks:v${GITLEAKS_VERSION}"
REPORTS_DIR="$SECURITY_ROOT/templates/reports"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

require_docker() {
  command -v docker &>/dev/null || die "Docker is not installed or not in PATH."
  docker info &>/dev/null 2>&1 || die "Docker daemon is not running. Start Docker and retry."
}

require_docker
mkdir -p "$REPORTS_DIR"

SCAN_MODE="${1:-git}"
TARGET_PATH="${2:-$SECURITY_ROOT}"
[[ -d "$TARGET_PATH" ]] || die "Target path does not exist: $TARGET_PATH"

SAFE_NAME=$(printf '%s' "$TARGET_PATH" | tr -c '[:alnum:]_.-' '_')
REPORT_NAME="gitleaks-${SCAN_MODE}_${SAFE_NAME}_${TIMESTAMP}"

GIT_FLAG=()
case "$SCAN_MODE" in
  git)
    [[ -d "$TARGET_PATH/.git" ]] || die "Not a git repository: $TARGET_PATH (use 'dir' mode for plain folders)"
    log "Scanning git history for secrets: $TARGET_PATH"
    log "NOTE: Requires full clone — in CI run: git fetch --unshallow || true"
    ;;
  dir)
    GIT_FLAG=(--no-git)
    log "Scanning working tree for secrets (no git history): $TARGET_PATH"
    ;;
  *)
    die "Unknown scan mode '$SCAN_MODE'. Use: git | dir"
    ;;
esac

EXIT=0
docker run --rm \
  -v "$TARGET_PATH":/repo:ro \
  -v "$REPORTS_DIR":/reports \
  "$GITLEAKS_IMAGE" \
  detect \
    --source=/repo \
    "${GIT_FLAG[@]+"${GIT_FLAG[@]}"}" \
    --report-format=sarif \
    --report-path=/reports/"${REPORT_NAME}.sarif" \
    --redact \
    --exit-code=1 \
    --verbose || EXIT=$?

if [[ $EXIT -eq 1 ]]; then
  log "WARN: Gitleaks found potential secrets. Review: $REPORTS_DIR/${REPORT_NAME}.sarif"
elif [[ $EXIT -ne 0 ]]; then
  die "Gitleaks exited with unexpected code $EXIT."
else
  log "No secrets found."
fi

log "Report saved: $REPORTS_DIR/${REPORT_NAME}.sarif"
log "Scan complete."
