#!/usr/bin/env bash
# audit.sh — Run npm audit + Semgrep on a Node.js / React project.
#
# Usage:
#   ./path/to/security/node-web/audit.sh [project-root] [reports-dir]
#
# Arguments:
#   project-root   Path to the project to scan (default: current working directory)
#   reports-dir    Directory where reports are written (default: security/templates/reports)
#                  Pass a session-specific dir from scan-full-dockerized.sh to keep reports scoped.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECURITY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../versions.env
source "$SECURITY_ROOT/versions.env"
[[ -n "${SEMGREP_VERSION:-}" ]] || die "SEMGREP_VERSION is unset — versions.env not loaded properly"

SEMGREP_IMAGE="returntocorp/semgrep:${SEMGREP_VERSION}"
PROJECT_ROOT="${1:-$(pwd)}"
REPORTS_DIR="${2:-$SECURITY_ROOT/templates/reports}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

log()  { printf '\033[1;34m[audit]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }

require_docker() {
  command -v docker &>/dev/null || { err "Docker is not installed or not in PATH."; exit 1; }
  docker info &>/dev/null 2>&1 || { err "Docker daemon is not running. Start Docker and retry."; exit 1; }
}

require_docker
mkdir -p "$REPORTS_DIR"

log "Project root : $PROJECT_ROOT"
log "Reports dir  : $REPORTS_DIR"

# ── npm audit ──────────────────────────────────────────────────────────────────
NPM_REPORT="$REPORTS_DIR/npm-audit_${TIMESTAMP}.json"
if [[ -f "$PROJECT_ROOT/package.json" ]]; then
  log "Running npm audit…"
  if command -v npm &>/dev/null; then
    npm audit --json --prefix "$PROJECT_ROOT" > "$NPM_REPORT" 2>&1 || {
      warn "npm audit exited non-zero (vulnerabilities found). See: $NPM_REPORT"
    }
  else
    log "npm not found locally — running via Docker node image."
    docker run --rm \
      -v "$PROJECT_ROOT":/app:ro \
      -w /app \
      "$NODE_IMAGE" \
      npm audit --json > "$NPM_REPORT" 2>&1 || {
      warn "npm audit found vulnerabilities. See: $NPM_REPORT"
    }
  fi

  CRITICAL=$(python3 -c "
import json
d = json.load(open('$NPM_REPORT'))
print(d.get('metadata',{}).get('vulnerabilities',{}).get('critical',0))
" 2>/dev/null || echo "?")
  HIGH=$(python3 -c "
import json
d = json.load(open('$NPM_REPORT'))
print(d.get('metadata',{}).get('vulnerabilities',{}).get('high',0))
" 2>/dev/null || echo "?")
  log "npm audit results — critical: $CRITICAL  high: $HIGH"
  log "Full report: $NPM_REPORT"
else
  warn "No package.json found at $PROJECT_ROOT — skipping npm audit."
fi

# ── Semgrep ────────────────────────────────────────────────────────────────────
# Write directly to a file inside the container to avoid mixing progress/warning
# lines printed to stdout with the JSON payload.
SEMGREP_REPORT="$REPORTS_DIR/semgrep_${TIMESTAMP}.json"
SEMGREP_CONFIG="$SCRIPT_DIR/semgrep.yml"
log "Running Semgrep via Docker…"
docker run --rm \
  -v "$PROJECT_ROOT":/src:ro \
  -v "$SEMGREP_CONFIG":/semgrep.yml:ro \
  -v "$REPORTS_DIR":/reports \
  "$SEMGREP_IMAGE" \
  semgrep \
    --config /semgrep.yml \
    --config "p/owasp-top-ten" \
    --config "p/javascript" \
    --config "p/typescript" \
    --config "p/react" \
    --json \
    --output /reports/"$(basename "$SEMGREP_REPORT")" \
    /src || {
  warn "Semgrep found findings or encountered errors. See: $SEMGREP_REPORT"
}

FINDINGS=$(python3 -c "
import json
d = json.load(open('$SEMGREP_REPORT'))
print(len(d.get('results',[])))
" 2>/dev/null || echo "?")
log "Semgrep findings: $FINDINGS"
log "Full report: $SEMGREP_REPORT"

log "Audit complete."
