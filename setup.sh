#!/usr/bin/env bash
# setup.sh — Scaffolds the security-testing-template directory structure.
# Run once after cloning to ensure all dirs and placeholder files exist.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log() { printf '\033[1;32m[setup]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; }

DIRS=(
  checklists
  scripts
  templates/zap
  templates/reports
  .github/workflows
  node-web
  docker
  dast
  docs
)

FILES=(
  checklists/owasp-wstg-web.md
  checklists/api-security.md
  checklists/docker-hardening.md
  scripts/scan-trivy.sh
  scripts/scan-zap-baseline.sh
  scripts/docker-bench.sh
  templates/zap/rules.tsv
  .github/workflows/trivy.yml
  .github/workflows/zap-baseline.yml
  node-web/semgrep.yml
  node-web/audit.sh
  docker/docker-compose.yml
  dast/zap-full-scan.conf
  docs/como-usarlo-en-nuevo-proyecto.md
)

log "Creating directory structure under: $ROOT"
for dir in "${DIRS[@]}"; do
  target="$ROOT/$dir"
  if [[ ! -d "$target" ]]; then
    mkdir -p "$target"
    log "  Created dir  → $dir"
  else
    log "  Already exists → $dir"
  fi
done

log "Creating placeholder files (skips existing non-empty files)…"
for file in "${FILES[@]}"; do
  target="$ROOT/$file"
  if [[ ! -f "$target" ]]; then
    touch "$target"
    log "  Created file → $file"
  elif [[ ! -s "$target" ]]; then
    log "  Empty, skipping → $file"
  else
    log "  Exists, skipping → $file"
  fi
done

# Make all scripts executable
chmod +x "$ROOT"/scripts/*.sh 2>/dev/null || true
chmod +x "$ROOT"/node-web/audit.sh 2>/dev/null || true

log "Done. Security-testing-template scaffold complete."
log "Next steps:"
log "  1. Review and fill in any placeholder files."
log "  2. Add this repo as a submodule: git submodule add <url> security"
log "  3. See docs/como-usarlo-en-nuevo-proyecto.md for full instructions."
