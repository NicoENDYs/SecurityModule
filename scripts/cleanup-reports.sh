#!/usr/bin/env bash
# cleanup-reports.sh — Remove old security scan run directories.
#
# Usage:
#   ./scripts/cleanup-reports.sh [OPTIONS]
#
# Options:
#   --keep-last  DAYS   Remove run_* directories older than DAYS days (default: 30)
#   --dry-run           Print what would be deleted without removing anything
#   -h, --help          Show this help
#
# Examples:
#   ./scripts/cleanup-reports.sh                    # delete runs older than 30 days
#   ./scripts/cleanup-reports.sh --keep-last 7      # delete runs older than 7 days
#   ./scripts/cleanup-reports.sh --dry-run          # preview deletions only
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECURITY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPORTS_DIR="$SECURITY_ROOT/templates/reports"

KEEP_DAYS=30
DRY_RUN=false

log()  { printf '\033[1;32m[cleanup]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[cleanup]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep-last) KEEP_DAYS="$2"; shift 2 ;;
    --dry-run)   DRY_RUN=true; shift ;;
    -h|--help)
      sed -n '/^# Usage/,/^[^#]/{ /^#/{ s/^# \{0,1\}//; p } }' "$0"
      exit 0 ;;
    *) die "Unknown option: $1. Use --help for usage." ;;
  esac
done

[[ "$KEEP_DAYS" =~ ^[0-9]+$ ]] || die "--keep-last must be a positive integer, got: $KEEP_DAYS"
[[ -d "$REPORTS_DIR" ]] || { log "Reports directory does not exist: $REPORTS_DIR"; exit 0; }

log "Reports dir : $REPORTS_DIR"
log "Removing runs older than $KEEP_DAYS day(s)${DRY_RUN:+ [DRY RUN — no files deleted]}"

FOUND=0
while IFS= read -r -d '' dir; do
  FOUND=$((FOUND + 1))
  if [[ "$DRY_RUN" == true ]]; then
    warn "  Would delete: $(basename "$dir")"
  else
    rm -rf "$dir"
    log "  Deleted: $(basename "$dir")"
  fi
done < <(find "$REPORTS_DIR" -maxdepth 1 -name 'run_*' -type d -mtime +"$KEEP_DAYS" -print0)

if [[ "$FOUND" -eq 0 ]]; then
  log "Nothing to clean up (no runs older than $KEEP_DAYS day(s))."
else
  log "Done — ${FOUND} run director${FOUND:+ies} ${DRY_RUN:+would be }removed."
fi
