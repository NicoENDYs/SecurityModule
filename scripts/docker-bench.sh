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

BENCH_IMAGE="docker/docker-bench-security:latest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPORTS_DIR="$REPO_ROOT/templates/reports"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="$REPORTS_DIR/docker-bench_${TIMESTAMP}.log"

log()  { printf '\033[1;33m[bench]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

command -v docker &>/dev/null || die "Docker is not installed or not in PATH."

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

log "Starting Docker Bench for Security…"
docker run --rm \
  --net host \
  --pid host \
  --userns host \
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
