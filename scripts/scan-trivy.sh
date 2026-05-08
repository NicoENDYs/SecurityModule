#!/usr/bin/env bash
# scan-trivy.sh — Run Trivy locally via Docker without installing it on the host.
# Scans the filesystem or a Docker image and writes reports to templates/reports/.
#
# Usage:
#   ./scripts/scan-trivy.sh fs [path]            # filesystem scan (default: project root)
#   ./scripts/scan-trivy.sh image <image:tag>    # Docker image scan
#   ./scripts/scan-trivy.sh repo <git-url>       # remote repository scan
set -euo pipefail

TRIVY_IMAGE="aquasec/trivy:0.61.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPORTS_DIR="$REPO_ROOT/templates/reports"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

log()  { printf '\033[1;36m[trivy]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

command -v docker &>/dev/null || die "Docker is not installed or not in PATH."

mkdir -p "$REPORTS_DIR"

SCAN_MODE="${1:-fs}"
SCAN_TARGET="${2:-/project}"

case "$SCAN_MODE" in
  fs)
    TARGET_PATH="${2:-$REPO_ROOT}"
    REPORT_NAME="trivy-fs_${TIMESTAMP}"
    log "Scanning filesystem: $TARGET_PATH"
    docker run --rm \
      -v "$TARGET_PATH":/project:ro \
      -v "$REPORTS_DIR":/reports \
      -v trivy-cache:/root/.cache/trivy \
      "$TRIVY_IMAGE" fs \
        --exit-code 0 \
        --severity HIGH,CRITICAL \
        --format table \
        --output /reports/"${REPORT_NAME}.txt" \
        /project

    docker run --rm \
      -v "$TARGET_PATH":/project:ro \
      -v "$REPORTS_DIR":/reports \
      -v trivy-cache:/root/.cache/trivy \
      "$TRIVY_IMAGE" fs \
        --exit-code 0 \
        --severity HIGH,CRITICAL \
        --format json \
        --output /reports/"${REPORT_NAME}.json" \
        /project

    log "Reports saved:"
    log "  $REPORTS_DIR/${REPORT_NAME}.txt"
    log "  $REPORTS_DIR/${REPORT_NAME}.json"
    ;;

  image)
    [[ -z "${2:-}" ]] && die "Usage: $0 image <image:tag>"
    IMAGE_TAG="$2"
    SAFE_NAME="${IMAGE_TAG//[:\/]/_}"
    REPORT_NAME="trivy-image_${SAFE_NAME}_${TIMESTAMP}"
    log "Scanning image: $IMAGE_TAG"
    docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v "$REPORTS_DIR":/reports \
      -v trivy-cache:/root/.cache/trivy \
      "$TRIVY_IMAGE" image \
        --exit-code 0 \
        --severity HIGH,CRITICAL \
        --format table \
        --output /reports/"${REPORT_NAME}.txt" \
        "$IMAGE_TAG"

    docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v "$REPORTS_DIR":/reports \
      -v trivy-cache:/root/.cache/trivy \
      "$TRIVY_IMAGE" image \
        --exit-code 0 \
        --severity HIGH,CRITICAL \
        --format json \
        --output /reports/"${REPORT_NAME}.json" \
        "$IMAGE_TAG"

    log "Reports saved:"
    log "  $REPORTS_DIR/${REPORT_NAME}.txt"
    log "  $REPORTS_DIR/${REPORT_NAME}.json"
    ;;

  repo)
    [[ -z "${2:-}" ]] && die "Usage: $0 repo <git-url>"
    GIT_URL="$2"
    SAFE_NAME="$(echo "$GIT_URL" | sed 's|[^a-zA-Z0-9]|_|g')"
    REPORT_NAME="trivy-repo_${SAFE_NAME}_${TIMESTAMP}"
    log "Scanning remote repository: $GIT_URL"
    docker run --rm \
      -v "$REPORTS_DIR":/reports \
      -v trivy-cache:/root/.cache/trivy \
      "$TRIVY_IMAGE" repo \
        --exit-code 0 \
        --severity HIGH,CRITICAL \
        --format table \
        --output /reports/"${REPORT_NAME}.txt" \
        "$GIT_URL"

    log "Report saved: $REPORTS_DIR/${REPORT_NAME}.txt"
    ;;

  *)
    die "Unknown scan mode '$SCAN_MODE'. Use: fs | image | repo"
    ;;
esac

log "Scan complete."
