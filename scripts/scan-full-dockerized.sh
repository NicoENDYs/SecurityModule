#!/usr/bin/env bash
# scan-full-dockerized.sh — Complete security scan pipeline for a Dockerized project.
#
# Runs in order:
#   1. npm audit + Semgrep (SAST on source code)
#   2. docker build (if no pre-built image given)
#   3. Trivy image scan (CVEs in the built image)
#   4. docker compose up (start the project)
#   5. ZAP baseline scan (DAST against the running app)
#   6. Docker Bench for Security (CIS runtime checks)
#   7. Consolidated summary report with pass/fail exit code
#
# Usage:
#   ./scripts/scan-full-dockerized.sh [OPTIONS]
#
# Options:
#   -p, --project-root  PATH     Path to the project to scan (default: current dir)
#   -u, --url           URL      URL to scan with ZAP (default: http://localhost:3000)
#   -i, --image         IMAGE    Pre-built image tag (skips docker build step)
#   -f, --compose-file  FILE     docker-compose file to use (default: docker-compose.yml)
#   -s, --service       NAME     Compose service name to wait for (default: app)
#   -t, --timeout       SECS     Seconds to wait for app to be ready (default: 60)
#   -H, --health-path   PATH     HTTP path used for readiness check (default: /)
#   -S, --severity      LEVEL    Trivy severity filter (default: HIGH,CRITICAL)
#   --skip-sast                  Skip npm audit + Semgrep
#   --skip-trivy                 Skip Trivy image scan
#   --skip-zap                   Skip ZAP baseline scan
#   --skip-bench                 Skip Docker Bench
#   --fail-on-findings           Exit 1 if any HIGH/CRITICAL findings (default: warn only)
#   --allow-status   CODE        Additional HTTP status code accepted as "ready" by wait_for_url
#                                (default: only 2xx; use e.g. --allow-status 503 for maintenance pages)
#   -h, --help                   Show this help
#
# Example:
#   ./security/scripts/scan-full-dockerized.sh \
#     --project-root /home/user/myapp \
#     --url http://localhost:4000 \
#     --health-path /api/health \
#     --compose-file docker-compose.prod.yml \
#     --service backend \
#     --fail-on-findings

set -euo pipefail

# ── Bootstrap ─────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECURITY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../versions.env
source "$SECURITY_ROOT/versions.env"
for _v in TRIVY_VERSION ZAP_VERSION BENCH_VERSION SEMGREP_VERSION; do
  [[ -n "${!_v:-}" ]] || die "$_v is unset — versions.env not loaded properly"
done
unset _v

REPORTS_DIR="$SECURITY_ROOT/templates/reports"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
SESSION_DIR="$REPORTS_DIR/run_${TIMESTAMP}"

# ── Defaults ───────────────────────────────────────────────────────────────────
PROJECT_ROOT="${PWD}"
ZAP_URL="http://localhost:3000"
HEALTH_PATH="/"
IMAGE_TAG=""
COMPOSE_FILE="docker-compose.yml"
COMPOSE_SERVICE="app"
READY_TIMEOUT=60
SEVERITY="HIGH,CRITICAL"
SKIP_SAST=false
SKIP_TRIVY=false
SKIP_ZAP=false
SKIP_BENCH=false
FAIL_ON_FINDINGS=false
COMPOSE_STARTED=false
ALLOW_STATUS=""
BUILT_IMAGE=""

# ── Colors ─────────────────────────────────────────────────────────────────────
RED='\033[1;31m'; GRN='\033[1;32m'; YLW='\033[1;33m'
CYN='\033[1;36m'; RST='\033[0m'

log()  { printf "${CYN}[scan]${RST} %s\n" "$*"; }
ok()   { printf "${GRN}[PASS]${RST} %s\n" "$*"; }
warn() { printf "${YLW}[WARN]${RST} %s\n" "$*"; }
fail() { printf "${RED}[FAIL]${RST} %s\n" "$*"; }
die()  { fail "$*"; exit 1; }

require_docker() {
  command -v docker &>/dev/null || die "Docker is not installed or not in PATH."
  docker info &>/dev/null 2>&1 || die "Docker daemon is not running. Start Docker and retry."
  docker volume create securitymodule-trivy-cache &>/dev/null || true
}

# ── Argument parsing ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--project-root)  PROJECT_ROOT="$2"; shift 2 ;;
    -u|--url)           ZAP_URL="$2"; shift 2 ;;
    -i|--image)         IMAGE_TAG="$2"; shift 2 ;;
    -f|--compose-file)  COMPOSE_FILE="$2"; shift 2 ;;
    -s|--service)       COMPOSE_SERVICE="$2"; shift 2 ;;
    -t|--timeout)       READY_TIMEOUT="$2"; shift 2 ;;
    -H|--health-path)   HEALTH_PATH="$2"; shift 2 ;;
    -S|--severity)      SEVERITY="$2"; shift 2 ;;
    --skip-sast)        SKIP_SAST=true; shift ;;
    --skip-trivy)       SKIP_TRIVY=true; shift ;;
    --skip-zap)         SKIP_ZAP=true; shift ;;
    --skip-bench)       SKIP_BENCH=true; shift ;;
    --fail-on-findings) FAIL_ON_FINDINGS=true; shift ;;
    --allow-status)    ALLOW_STATUS="$2"; shift 2 ;;
    -h|--help)
      sed -n '/^# Usage/,/^[^#]/{ /^#/{ s/^# \{0,1\}//; p } }' "$0"
      exit 0 ;;
    *) die "Unknown option: $1. Use --help for usage." ;;
  esac
done

# ── Validation ─────────────────────────────────────────────────────────────────
require_docker
[[ -d "$PROJECT_ROOT" ]] || die "Project root does not exist: $PROJECT_ROOT"

mkdir -p "$SESSION_DIR"

declare -A SCORES=([sast]="SKIP" [trivy]="SKIP" [zap]="SKIP" [bench]="SKIP")
CRITICAL_FINDINGS=0

# ── Cleanup on exit ────────────────────────────────────────────────────────────
cleanup() {
  if [[ "$COMPOSE_STARTED" == true ]]; then
    log "Stopping compose services started by this scan…"
    docker compose -f "$PROJECT_ROOT/$COMPOSE_FILE" down --timeout 10 &>/dev/null || true
  fi
  if [[ -n "$BUILT_IMAGE" ]]; then docker rmi "$BUILT_IMAGE" &>/dev/null || true; fi
}
trap cleanup EXIT INT TERM

# ── Helper: wait for HTTP endpoint ────────────────────────────────────────────
wait_for_url() {
  local url="$1" timeout="$2" elapsed=0
  local status_pattern="^2[0-9]{2}$"
  [[ -n "$ALLOW_STATUS" ]] && status_pattern="^(2[0-9]{2}|${ALLOW_STATUS})$"
  log "Waiting for $url to respond with 2xx${ALLOW_STATUS:+ or $ALLOW_STATUS} (timeout: ${timeout}s)…"
  until curl -s --max-time 3 -o /dev/null -w '%{http_code}' "$url" | grep -qE "$status_pattern"; do
    sleep 2; elapsed=$((elapsed + 2))
    [[ $elapsed -ge $timeout ]] && die "Timed out waiting for $url after ${timeout}s"
    log "  …still waiting (${elapsed}s elapsed)"
  done
  ok "Application is responding at $url"
}

# ══════════════════════════════════════════════════════════════════════════════
log "═══════════════════════════════════════════════════════"
log " Security Scan — Dockerized Project"
log " Project : $PROJECT_ROOT"
log " Session : $SESSION_DIR"
log " Time    : $(date)"
log "═══════════════════════════════════════════════════════"

# ── Step 1: SAST (npm audit + Semgrep) ────────────────────────────────────────
if [[ "$SKIP_SAST" == false ]]; then
  log "━━━ Step 1/4: SAST (npm audit + Semgrep) ━━━"
  AUDIT_SCRIPT="$SECURITY_ROOT/node-web/audit.sh"
  # Pass SESSION_DIR as the output directory so reports land in this run's folder
  if bash "$AUDIT_SCRIPT" "$PROJECT_ROOT" "$SESSION_DIR" > "$SESSION_DIR/sast.log" 2>&1; then
    NPM_CRITICAL=$(python3 -c "
import json, glob, sys
files = glob.glob('$SESSION_DIR/npm-audit_*.json')
if files:
    d = json.load(open(sorted(files)[-1]))
    print(d.get('metadata',{}).get('vulnerabilities',{}).get('critical',0))
else:
    print(0)
" 2>/dev/null || echo 0)
    SEMGREP_ERRORS=$(python3 -c "
import json, glob
files = glob.glob('$SESSION_DIR/semgrep_*.json')
if files:
    d = json.load(open(sorted(files)[-1]))
    errors = [r for r in d.get('results',[]) if r.get('extra',{}).get('severity','') == 'ERROR']
    print(len(errors))
else:
    print(0)
" 2>/dev/null || echo 0)
    if [[ "$NPM_CRITICAL" -gt 0 || "$SEMGREP_ERRORS" -gt 0 ]]; then
      warn "SAST: npm critical=$NPM_CRITICAL  semgrep errors=$SEMGREP_ERRORS"
      SCORES[sast]="WARN"
      CRITICAL_FINDINGS=$((CRITICAL_FINDINGS + NPM_CRITICAL + SEMGREP_ERRORS))
    else
      ok "SAST: no critical findings"
      SCORES[sast]="PASS"
    fi
  else
    warn "SAST script exited non-zero — check $SESSION_DIR/sast.log"
    SCORES[sast]="WARN"
  fi
else
  log "Skipping SAST (--skip-sast)"
fi

# ── Step 2: Docker build + Trivy image scan ───────────────────────────────────
if [[ "$SKIP_TRIVY" == false ]]; then
  log "━━━ Step 2/4: Docker Image Scan (Trivy) ━━━"

  if [[ -z "$IMAGE_TAG" ]]; then
    COMPOSE_YML="$PROJECT_ROOT/$COMPOSE_FILE"
    if [[ -f "$COMPOSE_YML" ]]; then
      log "Building image via docker compose (service: $COMPOSE_SERVICE)…"
      docker compose -f "$COMPOSE_YML" build "$COMPOSE_SERVICE" \
        >"$SESSION_DIR/docker-build.log" 2>&1
      IMAGE_TAG=$(docker compose -f "$COMPOSE_YML" images -q "$COMPOSE_SERVICE" 2>/dev/null | head -1)
      BUILT_IMAGE="$IMAGE_TAG"
    elif [[ -f "$PROJECT_ROOT/Dockerfile" ]]; then
      IMAGE_TAG="security-scan-target:${TIMESTAMP}"
      log "Building image from Dockerfile…"
      docker build -t "$IMAGE_TAG" "$PROJECT_ROOT" \
        >"$SESSION_DIR/docker-build.log" 2>&1
      BUILT_IMAGE="$IMAGE_TAG"
    else
      warn "No Dockerfile or compose file found — skipping image scan."
      SCORES[trivy]="SKIP"
    fi
  fi

  if [[ -n "$IMAGE_TAG" ]]; then
    log "Scanning image: $IMAGE_TAG"
    docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v "$SESSION_DIR":/reports \
      -v securitymodule-trivy-cache:/root/.cache/trivy \
      "aquasec/trivy:${TRIVY_VERSION}" image \
        --exit-code 0 \
        --severity "$SEVERITY" \
        --format json \
        --output /reports/trivy-image.json \
        "$IMAGE_TAG" 2>"$SESSION_DIR/trivy.log" || true

    docker run --rm \
      -v "$SESSION_DIR":/reports \
      -v securitymodule-trivy-cache:/root/.cache/trivy \
      "aquasec/trivy:${TRIVY_VERSION}" convert \
        --format table \
        --output /reports/trivy-image.txt \
        /reports/trivy-image.json 2>>"$SESSION_DIR/trivy.log" || true

    if [[ -f "$SESSION_DIR/trivy-image.json" ]]; then
      TRIVY_VULNS=$(python3 -c "
import json
d = json.load(open('$SESSION_DIR/trivy-image.json'))
total = sum(len(r.get('Vulnerabilities') or []) for r in (d.get('Results') or []))
print(total)
" 2>/dev/null || echo "?")
      if [[ "$TRIVY_VULNS" == "0" ]]; then
        ok "Trivy: 0 vulnerabilities ($SEVERITY)"
        SCORES[trivy]="PASS"
      else
        warn "Trivy: $TRIVY_VULNS vulnerabilities found ($SEVERITY). See trivy-image.txt"
        SCORES[trivy]="WARN"
        CRITICAL_FINDINGS=$((CRITICAL_FINDINGS + TRIVY_VULNS))
      fi
    else
      warn "Trivy report not generated — check $SESSION_DIR/trivy.log"
      SCORES[trivy]="WARN"
    fi
  fi
else
  log "Skipping Trivy (--skip-trivy)"
fi

# ── Step 3: Bring up the project + ZAP baseline ───────────────────────────────
if [[ "$SKIP_ZAP" == false ]]; then
  log "━━━ Step 3/4: DAST — ZAP Baseline Scan ━━━"
  COMPOSE_YML="$PROJECT_ROOT/$COMPOSE_FILE"
  READINESS_URL="${ZAP_URL%/}${HEALTH_PATH}"

  if [[ -f "$COMPOSE_YML" ]]; then
    log "Starting project with docker compose…"
    docker compose -f "$COMPOSE_YML" up -d 2>"$SESSION_DIR/compose-up.log"
    COMPOSE_STARTED=true
    wait_for_url "$READINESS_URL" "$READY_TIMEOUT"
  else
    warn "No compose file at $COMPOSE_YML — assuming the app is already running."
    wait_for_url "$READINESS_URL" 10
  fi

  ZAP_BASE="zap-baseline_${TIMESTAMP}"
  ZAP_RULES="$SECURITY_ROOT/templates/zap/rules.tsv"
  RULES_MOUNT=()
  RULES_FLAG=()
  if [[ -f "$ZAP_RULES" ]]; then
    RULES_MOUNT=(-v "$ZAP_RULES":/zap/rules.tsv:ro)
    RULES_FLAG=(-c /zap/rules.tsv)
  fi

  ZAP_EXIT=0
  docker run --rm \
    --network host \
    -v "$SESSION_DIR":/zap/wrk/:rw \
    "${RULES_MOUNT[@]+"${RULES_MOUNT[@]}"}" \
    "ghcr.io/zaproxy/zaproxy:${ZAP_VERSION}" \
    zap-baseline.py \
      -t "$ZAP_URL" \
      -r "${ZAP_BASE}.html" \
      -J "${ZAP_BASE}.json" \
      -w "${ZAP_BASE}.md" \
      "${RULES_FLAG[@]+"${RULES_FLAG[@]}"}" \
      -I 2>"$SESSION_DIR/zap.log" || ZAP_EXIT=$?

  if [[ $ZAP_EXIT -eq 2 ]]; then
    warn "ZAP found FAIL-level alerts (exit 2). See ${ZAP_BASE}.html"
    SCORES[zap]="WARN"
    CRITICAL_FINDINGS=$((CRITICAL_FINDINGS + 1))
  elif [[ $ZAP_EXIT -ne 0 ]]; then
    warn "ZAP unexpected exit $ZAP_EXIT — check $SESSION_DIR/zap.log"
    SCORES[zap]="WARN"
  else
    ZAP_JSON="$SESSION_DIR/${ZAP_BASE}.json"
    if [[ -f "$ZAP_JSON" ]]; then
      ZAP_ALERTS=$(python3 -c "
import json
d = json.load(open('$ZAP_JSON'))
high = [a for s in d.get('site',[]) for a in s.get('alerts',[]) if int(a.get('riskcode',0)) >= 2]
print(len(high))
" 2>/dev/null || echo 0)
      if [[ "$ZAP_ALERTS" -gt 0 ]]; then
        warn "ZAP: $ZAP_ALERTS medium/high alerts. See ${ZAP_BASE}.html"
        SCORES[zap]="WARN"
        CRITICAL_FINDINGS=$((CRITICAL_FINDINGS + ZAP_ALERTS))
      else
        ok "ZAP: no medium/high alerts"
        SCORES[zap]="PASS"
      fi
    else
      ok "ZAP: scan completed (no JSON to parse)"
      SCORES[zap]="PASS"
    fi
  fi

  if [[ "$COMPOSE_STARTED" == true ]]; then
    log "Stopping compose services…"
    docker compose -f "$COMPOSE_YML" down --timeout 10 2>/dev/null || true
    COMPOSE_STARTED=false
  fi
else
  log "Skipping ZAP (--skip-zap)"
fi

# ── Step 4: Docker Bench ──────────────────────────────────────────────────────
if [[ "$SKIP_BENCH" == false ]]; then
  log "━━━ Step 4/4: Docker Bench for Security ━━━"
  docker run --rm \
    --net host \
    --pid host \
    --userns host \
    --cap-add audit_control \
    -e DOCKER_CONTENT_TRUST=0 \
    -v /etc:/etc:ro \
    -v /var/lib:/var/lib:ro \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    --label docker_bench_security \
    "docker/docker-bench-security:${BENCH_VERSION}" \
    > "$SESSION_DIR/docker-bench.log" 2>&1 || true

  BENCH_WARNS=$(grep -c '\[WARN\]' "$SESSION_DIR/docker-bench.log" || true)
  if [[ "$BENCH_WARNS" -eq 0 ]]; then
    ok "Docker Bench: 0 warnings"
    SCORES[bench]="PASS"
  else
    warn "Docker Bench: $BENCH_WARNS warnings. See docker-bench.log"
    SCORES[bench]="WARN"
  fi
else
  log "Skipping Docker Bench (--skip-bench)"
fi

# ── Consolidated summary ───────────────────────────────────────────────────────
SUMMARY_FILE="$SESSION_DIR/summary.txt"
{
  echo "══════════════════════════════════════════════════════"
  echo " Security Scan Summary"
  echo " Project : $PROJECT_ROOT"
  echo " Run at  : $(date)"
  echo " Reports : $SESSION_DIR"
  echo "══════════════════════════════════════════════════════"
  printf " %-18s  %s\n" "Tool" "Result"
  echo "──────────────────────────────────────────────────────"
  for tool in sast trivy zap bench; do
    printf " %-18s  %s\n" "$tool" "${SCORES[$tool]}"
  done
  echo "──────────────────────────────────────────────────────"
  echo " Total critical findings: $CRITICAL_FINDINGS"
  echo "══════════════════════════════════════════════════════"
} | tee "$SUMMARY_FILE"

log "Reports written to $SESSION_DIR:"
find "$SESSION_DIR" -type f | sort | while read -r f; do
  printf "   %s\n" "${f#"$SESSION_DIR/"}"
done

if [[ "$FAIL_ON_FINDINGS" == true && "$CRITICAL_FINDINGS" -gt 0 ]]; then
  fail "Failing build: $CRITICAL_FINDINGS critical finding(s). See summary above."
  exit 1
fi

ok "Scan pipeline complete."
