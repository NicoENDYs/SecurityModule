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
- `CONTRIBUTING.md`, `.github/PULL_REQUEST_TEMPLATE.md` and `.github/ISSUE_TEMPLATE/` (bug report, feature request, security contact link) — contribution workflow, CI quality bar, and guides for adding Semgrep rules and bumping tool versions.
- `ci.yml` **self-scan** job (dogfooding) — runs the module's own scanners (`scan-trivy.sh fs`, `scan-secrets.sh git`) against this repository on every PR/push and uploads the reports as an artifact. The scripts report findings without gating, so the job fails only if a scanner script itself breaks — catching end-to-end regressions the unit checks miss.
- `ci.yml` **e2e** job — runs `scan-full-dockerized.sh` end to end against a throwaway `nginx:alpine` target (SAST → Trivy image scan → compose up → ZAP → summary) and asserts a structured `summary.txt` is produced, exercising the orchestrator and the ZAP delegation. Docker Bench is skipped (needs host privileges).

### Changed
- **Base images are now pinned by digest (supply-chain hardening).** `nginx:alpine` (Docker lab target + report viewer) and `node:22-alpine` (`audit.sh` fallback runner) are pinned to a `@sha256:…` digest via the new `NGINX_IMAGE`/`NODE_IMAGE` entries in `versions.env`, so a mutated tag in a compromised registry cannot change what runs. `update-versions.yml` refreshes these digests weekly from the Docker Hub API.
- **`scripts/scan-zap-baseline.sh` authentication now actually works.** The previous implementation passed the auth config via ZAP's `-c` flag — which is for alert-filter rules, not authentication — and also collided with the `rules.tsv` `-c` flag, so neither took effect. Authenticated scans now run through the ZAP Automation Framework (`zap.sh -cmd -autorun`) with a generated form-login plan; new `--zap-auth-loggedin`/`--zap-auth-loggedout` flags tune login verification. The generated plan (which contains credentials) is written `chmod 600` and deleted on exit. New `--reports-dir` and `--network-host` flags were added so the orchestrator can drive it.
- **`scripts/scan-full-dockerized.sh` supports authenticated ZAP scans** via `--zap-auth-url/--zap-auth-user/--zap-auth-pass`, and now delegates the ZAP step to `scan-zap-baseline.sh` instead of an inline `docker run` (one shared implementation, consistent with the Docker Bench delegation).
- **`scripts/scan-trivy.sh image` now also emits a CycloneDX SBOM** (`<report>.sbom.cdx.json`) alongside the vulnerability report — increasingly a compliance requirement (NTIA minimum elements, EU Cyber Resilience Act).
- `.github/workflows/trivy.yml` and `.github/workflows/secret-iac.yml` now write a concise results summary to the GitHub Actions run summary (`$GITHUB_STEP_SUMMARY`) so findings counts are visible without opening the Security tab.
- `README.md` and `docs/como-usarlo-en-nuevo-proyecto.md` document the new Semgrep workflow and the aggregated `security.yml`, and link to the beginner guide.
- **Standardised release tags on the `vMAJOR.MINOR.PATCH` convention** (e.g. `v1.7.0`), matching the GitHub Actions ecosystem. `update-v1-tag.yml` now triggers on `vX.Y.Z` tags and maintains **two** floating tags — `v1` (latest major) and `v1.<minor>` (latest patch of a minor) — so `@v1` / `@v1.7` always resolve to the newest release without doc edits. Added a self-updating "Latest release" badge (and a License badge) to the README, and updated the versioning docs/pin examples accordingly.
- **Documentation refreshed across the board** to cover everything above: `README.md` gains a detection-coverage table, an accurate directory tree, local usage for Gitleaks/SBOM/authenticated ZAP, and new "Supply chain & versions" and "Self-validation" sections; `CONTRIBUTING.md` lists the `self-scan`/`e2e` CI jobs; `docs/como-usarlo-en-nuevo-proyecto.md` documents authenticated/active ZAP scans (fixing a mislabelled `ajax` example), the SBOM output, and the Trivy `image-ref`/`trivy-config` inputs; `docs/sin-github.md` replaces stale pinned versions (`trivy:0.61.0`, `zaproxy:stable`) with `versions.env`-aligned tags and adds an SBOM step.
- JSON parsing in `node-web/audit.sh` and `scripts/scan-full-dockerized.sh` now uses `jq` instead of inline `python3` (one less implicit dependency, more idiomatic in Bash).
- `docker/docker-compose.yml` now interpolates tool versions (`${TRIVY_VERSION}`, `${ZAP_VERSION}`, `${SEMGREP_VERSION}`) from `versions.env` via a new `docker/.env` symlink, instead of hardcoding them. The corresponding `sed` sync lines were removed from `update-versions.yml`; interpolation uses `${VAR:?}` so a missing variable fails loudly instead of silently pulling a broken tag.
- `scripts/scan-full-dockerized.sh` now delegates the Docker Bench step to `scripts/docker-bench.sh` (which gained an optional `reports-dir` second argument), instead of running its own inline `docker run`.

### Fixed
- **`trivy.yml` referenced an unresolvable `trivy-action` SHA.** All four `aquasecurity/trivy-action` steps were pinned to `18f2505d…` (labelled `v0.31.0`), a SHA that does not exist in the action's repository, so every Trivy job failed at *Set up job* with `unable to resolve action`. Corrected to the real `v0.31.0` SHA (`76071ef0…`). This never surfaced in CI because the self-scan/e2e jobs exercise the local scripts, not the reusable workflow — now fixed (see below).
- **`secret-iac.yml` Checkov upload failed with `Path does not exist: results.sarif`.** Checkov writes `results_sarif.sarif` (not `results.sarif`) when `--output-file-path` is a directory, so the upload never found the file. The Checkov step now normalises the output to `results.sarif` and fails loudly if no SARIF was produced (catching a future rename).
- **SARIF uploads are now non-blocking** (`continue-on-error: true`) in `semgrep.yml`, `trivy.yml` and `secret-iac.yml`. Repositories without Code Scanning enabled (e.g. private repos without GitHub Advanced Security) previously saw the whole job fail on `Code scanning is not enabled for this repository`; now the scan and job summary still succeed, and the SARIF upload is best-effort.
- **CI now dogfoods the reusable workflows.** New `reusable-trivy`, `reusable-secret-iac` and `reusable-semgrep` jobs in `ci.yml` invoke the actual `workflow_call` workflows against this repo (pinned to the PR's own code), so an unresolvable action SHA or a wrong SARIF filename is caught before release — the exact class of bug that shipped in the two entries above.
- **`v1` floating tag.** Every workflow example in the docs (and the `module-ref` defaults in `zap-baseline.yml` / `semgrep.yml` / `trivy.yml`) references `@v1`, but the repository only had un-prefixed release tags (`1.4.0`, `1.3.5`, …), so all `uses: …@v1` calls failed with *unable to resolve ref*. New workflow `.github/workflows/update-v1-tag.yml` creates and maintains the floating tags: it moves `v1` (major) and `v1.<minor>` to the newest matching release whenever a `vX.Y.Z` tag is pushed, and can be dispatched manually to create/repair them.
- **`trivy.yml` no longer requires a `.trivy.yaml` in the consumer repo.** The reusable workflow passed `trivy-config: ".trivy.yaml"`, but that file ships with this module — not with the caller — so the filesystem scan failed for any consumer without their own copy. The workflow now checks out SecurityModule (new `module-ref` input, default `v1`) and uses its bundled `.trivy.yaml`; a new `trivy-config` input lets consumers point to their own file instead. `.trivy.yaml` gained `.security-module` in `skip-dirs` so the module checkout (and its intentional fake-secret test fixtures) is not scanned as part of the consumer's code.
- **`.gitignore` now actually ignores scan reports.** The previous per-extension patterns (`templates/reports/*.json`, …) only matched the top level, so everything written to per-run `run_TIMESTAMP/` subdirectories — and all `.sarif` reports — was left untracked-but-visible and could be committed by accident. Replaced with `templates/reports/*` + `!templates/reports/.gitkeep`.
- **Docker Bench now works in CI when run through the orchestrator.** `scan-full-dockerized.sh` hardcoded `--pid host --userns host`, which fails on GitHub Actions and most shared runners; `docker-bench.sh` already detected CI and omitted those flags, so the two entry points behaved differently. The orchestrator now delegates to `docker-bench.sh`, sharing one implementation (this also aligns the container mounts, which had diverged).
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

[Unreleased]: https://github.com/nicoendys/securitymodule/compare/v1.7.0...HEAD
[1.1.0]: https://github.com/nicoendys/securitymodule/compare/1.0.1...1.1.0
[1.0.0]: https://github.com/nicoendys/securitymodule/releases/tag/1.0.1
