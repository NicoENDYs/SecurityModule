#!/usr/bin/env bash
# docker-bench.sh — Run Docker Bench for Security against the local Docker daemon.
# Implements CIS Docker Benchmark checks without installing anything on the host.
#
# Usage:
#   ./scripts/docker-bench.sh [container-name-pattern]
#
# Examples:
#   ./scripts/docker-bench.sh                  # check all containers
#   ./scripts/docker-bench.sh myapp            # focus on containers matching 'myapp'
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECURITY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Logging helpers — defined before sourcing versions.env so the guard below can
# call die() with a clear message (Bash has no function hoisting).
log()  { printf '\033[1;33m[bench]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
die()  { err "$*"; exit 1; }

# shellcheck source=../versions.env
source "$SECURITY_ROOT/versions.env"
[[ -n "${BENCH_VERSION:-}" ]] || die "BENCH_VERSION is unset — versions.env not loaded properly"

BENCH_IMAGE="docker/docker-bench-security:${BENCH_VERSION}"
REPORTS_DIR="$SECURITY_ROOT/templates/reports"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="$REPORTS_DIR/docker-bench_${TIMESTAMP}.log"

require_docker() {
  command -v docker &>/dev/null || die "Docker is not installed or not in PATH."
  docker info &>/dev/null 2>&1 || die "Docker daemon is not running. Start Docker and retry."
}

require_docker
mkdir -p "$REPORTS_DIR"

CONTAINER_FILTER="${1:-}"
EXTRA_ARGS=()
if [[ -n "$CONTAINER_FILTER" ]]; then
  EXTRA_ARGS=(--include-test-output -c container_images -i "$CONTAINER_FILTER")
  log "Focusing on containers matching: $CONTAINER_FILTER"
else
  log "Running full Docker Bench assessment…"
fi

log "Pulling image (if not cached)…"
docker pull "$BENCH_IMAGE" --quiet

# --userns host and --pid host require Linux user namespace access that is
# restricted on GitHub Actions and most shared CI runners. Detect and adapt.
USERNS_ARG=(--userns host)
PID_ARG=(--pid host)
if [[ -n "${CI:-}" || -n "${GITHUB_ACTIONS:-}" ]]; then
  warn "CI environment detected — omitting --userns host and --pid host."
  warn "Kernel-level CIS checks (sections 1.x) will be skipped by Docker Bench."
  USERNS_ARG=()
  PID_ARG=()
fi

log "Starting Docker Bench for Security…"
docker run --rm \
  --net host \
  "${PID_ARG[@]+"${PID_ARG[@]}"}" \
  "${USERNS_ARG[@]+"${USERNS_ARG[@]}"}" \
  --cap-add audit_control \
  -e DOCKER_CONTENT_TRUST="${DOCKER_CONTENT_TRUST:-0}" \
  -v /etc:/etc:ro \
  -v /usr/bin/containerd:/usr/bin/containerd:ro \
  -v /usr/bin/runc:/usr/bin/runc:ro \
  -v /usr/lib/systemd:/usr/lib/systemd:ro \
  -v /var/lib:/var/lib:ro \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  --label docker_bench_security \
  "$BENCH_IMAGE" \
  "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}" \
  | tee "$REPORT_FILE"

log "Report saved: $REPORT_FILE"

WARNS=$(grep -c '\[WARN\]' "$REPORT_FILE" || true)
INFOS=$(grep -c '\[INFO\]' "$REPORT_FILE" || true)
log "Summary → WARN: $WARNS  INFO: $INFOS"
log "Review the report for remediations."
