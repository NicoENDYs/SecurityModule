# Changelog

All notable changes to `security-testing-template` are documented here.  
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- `.github/workflows/semgrep.yml` — reusable (`workflow_call`) Semgrep SAST scan. Runs this module's rules (`node-web/semgrep.yml`) plus the OWASP/JS/TS/React community packs against the caller's source, uploads SARIF to the Security tab, writes a job summary, and supports an optional `fail-on-findings` gate on ERROR-level findings. The Semgrep image tag is read from `versions.env` at run time, so it stays in sync without editing the workflow. Closes the gap where the module shipped Semgrep rules but had no reusable CI workflow to run them.
- `.github/workflows/secret-iac.yml` — reusable (`workflow_call`) Secret & IaC scan: Gitleaks scans the full git history for leaked credentials and Checkov adds broader IaC policy coverage. Both run via Docker and upload SARIF to the Security tab.
- `scripts/scan-secrets.sh` — local Gitleaks runner via Docker (`git` history / `dir` working-tree modes), mirroring `scan-trivy.sh`.
- `GITLEAKS_VERSION` and `CHECKOV_VERSION` in `versions.env`; `update-versions.yml` now tracks both and syncs the pinned tags in `secret-iac.yml`.
- `docs/guia-principiantes.md` — beginner-friendly, jargon-light quick-start guide: what each tool does, a minimal glossary, zero-to-first-scan steps, a single copy-paste `security.yml`, how to read results, troubleshooting, FAQ, and a command cheat sheet.

### Changed
- `.github/workflows/trivy.yml` and `.github/workflows/secret-iac.yml` now write a concise results summary to the GitHub Actions run summary (`$GITHUB_STEP_SUMMARY`) so findings counts are visible without opening the Security tab.
- `README.md` and `docs/como-usarlo-en-nuevo-proyecto.md` document the new Semgrep workflow and the aggregated `security.yml`, and link to the beginner guide.
- JSON parsing in `node-web/audit.sh` and `scripts/scan-full-dockerized.sh` now uses `jq` instead of inline `python3` (one less implicit dependency, more idiomatic in Bash).

### Fixed
- **`v1` floating tag now exists.** Every workflow example in the docs (and the `module-ref` defaults in `zap-baseline.yml` / `semgrep.yml` / `trivy.yml`) references `@v1`, but the repository only had un-prefixed release tags (`1.4.0`, `1.3.5`, …), so all `uses: …@v1` calls failed with *unable to resolve ref*. The `v1` tag is now published and moves with each 1.x release. Docs that referenced non-existent `v`-prefixed release tags (`v1.1.0`, `v1.2.0`) now use real tag names.
- **`trivy.yml` no longer requires a `.trivy.yaml` in the consumer repo.** The reusable workflow passed `trivy-config: ".trivy.yaml"`, but that file ships with this module — not with the caller — so the filesystem scan failed for any consumer without their own copy. The workflow now checks out SecurityModule (new `module-ref` input, default `v1`) and uses its bundled `.trivy.yaml`; a new `trivy-config` input lets consumers point to their own file instead. `.trivy.yaml` gained `.security-module` in `skip-dirs` so the module checkout (and its intentional fake-secret test fixtures) is not scanned as part of the consumer's code.
- **`.gitignore` now actually ignores scan reports.** The previous per-extension patterns (`templates/reports/*.json`, …) only matched the top level, so everything written to per-run `run_TIMESTAMP/` subdirectories — and all `.sarif` reports — was left untracked-but-visible and could be committed by accident. Replaced with `templates/reports/*` + `!templates/reports/.gitkeep`.
- `log`/`err`/`die` helpers are now defined **before** the `versions.env` source guard in `scan-trivy.sh`, `scan-zap-baseline.sh`, `docker-bench.sh` and `scan-full-dockerized.sh`. Bash has no function hoisting, so on the failure path the guard previously printed `die: command not found` instead of its intended message.
- `node-web/audit.sh` now defines `die()` (it was referenced by the `versions.env` guard but never defined).
- `docker-bench.sh` now defines `warn()` (it was referenced in the CI-detection branch but never defined).

---

## [1.1.0] — 2026-05-09

### Added
- `versions.env` — central source of truth for all pinned Docker image versions (Trivy, ZAP, Semgrep, Docker Bench). All scripts now source this file so tool versions are updated in one place.
- `require_docker()` — helper in every script that checks both Docker binary and daemon before running, with a clear error message.
- `--health-path` flag in `scan-full-dockerized.sh` — custom readiness endpoint for APIs that return 404 on `/`.
- Semgrep test fixtures in `node-web/tests/` with `// ruleid:` and `// ok:` annotations covering all rules.
- `.github/workflows/ci.yml` — self-validation CI: ShellCheck, actionlint, Semgrep rule unit tests.
- `.github/workflows/update-versions.yml` — weekly automated PR to bump tool versions in `versions.env`.
- `.github/dependabot.yml` — weekly Dependabot updates for GitHub Actions and Docker images.
- `SECURITY.md` — vulnerability disclosure policy with 72h response SLA.
- `LICENSE` — MIT license.
- Explicit `docker volume create securitymodule-trivy-cache` before first use — prevents silent failure on clean environments.
- `versions.env` validation guard in every script — fails fast with a clear message if the file was not sourced correctly.
- SSRF (40046) and XXE (90023) alert IDs added to `templates/zap/rules.tsv` as `FAIL`.

### Changed
- `scan-zap-baseline.sh`: `ajax` mode now correctly calls `zap-baseline.py -j` (passive + Ajax spider) instead of the active `zap-full-scan.py`. Full active scan requires `I_OWN_THIS_TARGET=yes` and explicit `full` mode.
- `scan-full-dockerized.sh`: SAST reports now written to the session-specific `run_TIMESTAMP/` directory (second arg to `audit.sh`). Removed duplicate Trivy run; uses `trivy convert` to produce table output from existing JSON. `COMPOSE_PID` string replaced with proper `COMPOSE_STARTED` boolean.
- `scan-trivy.sh`: `repo` mode now also produces JSON + table pair. Filename sanitisation uses `tr` instead of `sed` to handle special chars (`@`, `+`).
- `node-web/semgrep.yml`: `no-child-process-exec-with-variable` and `no-child-process-execsync-with-variable` now detect ESM named imports and namespace imports in addition to CJS. `no-math-random-for-secrets` severity lowered to `INFO`. `no-hardcoded-password-in-object` excludes test/fixture directories. Fixed `no-dangerously-set-inner-html` (invalid YAML + wrong JSX pattern). Fixed `no-href-javascript` (patterns that never matched). Fixed `no-hardcoded-jwt-secret` and `no-hardcoded-password-in-object` (used `patterns:` AND logic instead of `pattern-either:` OR logic).
- `docker/docker-compose.yml`: removed `version: "3.9"` (deprecated in Compose V2) and hardcoded `172.28.0.0/24` subnet. Pinned all images to exact tags.
- All GitHub Actions workflows now pin actions to SHA.
- All `@main` workflow references replaced with `@v1`.

### Fixed
- `trivy-cache` Docker volume renamed to `securitymodule-trivy-cache` to avoid conflicts with other projects.
- `zap-full-scan.conf`: removed duplicate `ajaxSpider.maxDuration=5` line.

---

## [1.0.0] — 2026-05-08

### Added
- Initial scaffold: OWASP WSTG, API Security Top 10, CIS Docker Benchmark checklists.
- `scan-trivy.sh` — Trivy filesystem, image, and repo scans via Docker.
- `scan-zap-baseline.sh` — OWASP ZAP baseline DAST scan via Docker.
- `docker-bench.sh` — Docker Bench for Security CIS checks.
- `scan-full-dockerized.sh` — Orchestrator: SAST → build → Trivy → compose up → ZAP → Bench → summary report.
- `node-web/audit.sh` — npm audit + Semgrep SAST for JS/TS/React projects.
- `node-web/semgrep.yml` — Custom Semgrep rules covering eval, command injection, SQL injection, hardcoded secrets, dangerous React patterns, weak crypto, path traversal, prototype pollution, wildcard CORS.
- `.github/workflows/trivy.yml` — Reusable Trivy workflow (`workflow_call`).
- `.github/workflows/zap-baseline.yml` — Reusable ZAP DAST workflow (`workflow_call`).
- `docker/docker-compose.yml` — Isolated security lab (ZAP, Trivy, Semgrep, report viewer).
- `dast/zap-full-scan.conf` — ZAP active scan configuration.
- `templates/zap/rules.tsv` — ZAP alert filter rules.
- `setup.sh` — One-shot scaffold script for new projects.
- Docs: `como-usarlo-en-nuevo-proyecto.md`, `proyecto-dockerizado.md`, `sin-github.md`.

[Unreleased]: https://github.com/nicoendys/securitymodule/compare/1.4.0...HEAD
[1.1.0]: https://github.com/nicoendys/securitymodule/compare/1.0.1...1.1.0
[1.0.0]: https://github.com/nicoendys/securitymodule/releases/tag/1.0.1
