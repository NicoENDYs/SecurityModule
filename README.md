# security-testing-template

![CI](https://github.com/NicoENDYs/SecurityModule/actions/workflows/ci.yml/badge.svg)

> **Docs language note:** Detailed guides in [`docs/`](docs/) are written in Spanish intentionally (the primary audience is the original team). The README and all scripts are in English for broader accessibility.

A reusable security-testing scaffold designed to be added as a **Git submodule** to any Node.js or React project. It standardises:

- Security checklists (OWASP WSTG, API Security Top 10, Docker Hardening)
- Local scan scripts (Trivy, ZAP, Gitleaks, Docker Bench) that run via Docker — no host installs needed
- Reusable GitHub Actions workflows (Semgrep SAST + Trivy + Secret/IaC + ZAP) callable with `workflow_call`
- Semgrep SAST rules tailored for JavaScript / TypeScript / React
- **DAST with optional form authentication** (ZAP Automation Framework)
- **CycloneDX SBOM** generation for scanned images
- **Supply-chain hardening**: all tool and base images pinned (by digest where mutable), refreshed weekly, single-sourced from `versions.env`

Detection coverage at a glance:

| Layer | Tool | What it catches |
|-------|------|-----------------|
| SAST | Semgrep | Dangerous code patterns (injection, XSS, weak crypto, hardcoded secrets) in JS/TS/React |
| SCA + IaC | Trivy | Vulnerable dependencies, image CVEs, Dockerfile/Compose misconfigurations, + a CycloneDX SBOM |
| Secrets | Gitleaks | Credentials leaked across the full git history |
| IaC policy | Checkov | Broader infrastructure-as-code policy violations |
| DAST | OWASP ZAP | Vulnerabilities in the running app (baseline, ajax, or authenticated active scan) |
| Runtime | Docker Bench | CIS Docker Benchmark checks on the daemon and containers |

> **🚀 New to security scanning?** Start with the beginner-friendly, jargon-light
> walkthrough: [`docs/guia-principiantes.md`](docs/guia-principiantes.md). It gets
> you from zero to your first scan (and automated CI checks) in a few minutes.

---

## Directory Structure

```text
security-testing-template/
├── setup.sh                          # One-shot scaffold script
├── versions.env                      # Single source of truth for all pinned image versions/digests
├── .trivy.yaml                       # Default Trivy config (severity, skip-dirs, scanners)
├── CONTRIBUTING.md                   # Contribution workflow + CI quality bar
├── CHANGELOG.md · SECURITY.md · LICENSE
├── checklists/
│   ├── owasp-wstg-web.md             # OWASP WSTG v4.2 full checklist
│   ├── api-security.md               # OWASP API Security Top 10 (2023)
│   └── docker-hardening.md           # CIS Docker Benchmark v1.6
├── scripts/
│   ├── scan-full-dockerized.sh       # Orchestrator: SAST → trivy → compose up → ZAP → bench → summary
│   ├── scan-trivy.sh                 # Local Trivy scan (fs | image (+SBOM) | repo | git-history)
│   ├── scan-secrets.sh               # Local Gitleaks secret scan (git | dir)
│   ├── scan-zap-baseline.sh          # Local ZAP scan (baseline | ajax | full; optional auth)
│   ├── docker-bench.sh               # Docker Bench for Security (CI-aware)
│   └── cleanup-reports.sh            # Prune old report directories
├── templates/
│   ├── zap/rules.tsv                 # ZAP alert filter rules
│   └── reports/                      # Output directory for all scan reports (git-ignored)
├── .github/
│   ├── workflows/
│   │   ├── semgrep.yml               # Reusable Semgrep SAST workflow
│   │   ├── trivy.yml                 # Reusable Trivy workflow (fs + image + config)
│   │   ├── secret-iac.yml            # Reusable Gitleaks + Checkov workflow
│   │   ├── zap-baseline.yml          # Reusable ZAP DAST workflow
│   │   ├── ci.yml                    # Self-validation: lint + rule tests + self-scan + E2E
│   │   ├── update-versions.yml       # Weekly PR bumping pinned versions/digests
│   │   └── update-v1-tag.yml         # Keeps the floating `v1` tag on the latest 1.x release
│   ├── ISSUE_TEMPLATE/               # Bug report + feature request + security contact
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── dependabot.yml
├── node-web/
│   ├── semgrep.yml                   # Semgrep rules for JS/TS/React
│   ├── audit.sh                      # npm audit + Semgrep via Docker
│   └── tests/                        # Annotated fixtures validating every Semgrep rule
├── docker/
│   ├── docker-compose.yml            # Isolated security lab (versions from versions.env)
│   └── .env                          # Symlink → ../versions.env (Compose interpolation)
├── dast/
│   └── zap-full-scan.conf            # ZAP active scan configuration
└── docs/
    ├── guia-principiantes.md             # Beginner-friendly quick start (start here)
    ├── como-usarlo-en-nuevo-proyecto.md  # Submodule setup + GitHub Actions integration
    ├── proyecto-dockerizado.md           # Full guide for Dockerized apps
    └── sin-github.md                     # GitLab CI, Bitbucket, Jenkins, local-only
```

---

## Quick Start (local scans)

### Prerequisites

- Docker (the only required tool on your host)
- bash 4+

### 1. Add as a submodule

```bash
# From your project root
git submodule add https://github.com/nicoendys/securitymodule security
git submodule update --init --recursive
```

### 2. Full scan of a Dockerized project (recommended)

```bash
bash security/scripts/scan-full-dockerized.sh \
  --project-root . \
  --url http://localhost:3000 \
  --compose-file docker-compose.yml \
  --service app
```

This single command: runs SAST → builds the image → scans it with Trivy → starts compose → runs ZAP → runs Docker Bench → writes a `summary.txt` with PASS/WARN/FAIL per tool.

### 3. Run individual scans

```bash
bash security/scripts/scan-trivy.sh fs .              # filesystem (vulns + secrets)
bash security/scripts/scan-trivy.sh image app:latest  # Docker image (+ CycloneDX SBOM)
bash security/scripts/scan-trivy.sh git-history .      # secrets across git history
```

Reports are saved to `security/templates/reports/`. The `image` mode also writes
`<report>.sbom.cdx.json` (a CycloneDX SBOM) next to the vulnerability report.

### 4. Scan git history for leaked secrets (Gitleaks)

```bash
bash security/scripts/scan-secrets.sh git .   # full history (needs a complete clone)
bash security/scripts/scan-secrets.sh dir .   # working tree only
```

### 5. Run a ZAP scan against a staging URL

```bash
bash security/scripts/scan-zap-baseline.sh https://staging.example.com          # passive baseline
bash security/scripts/scan-zap-baseline.sh https://staging.example.com ajax      # + ajax spider (SPAs)

# Authenticated scan (form login, via the ZAP Automation Framework):
bash security/scripts/scan-zap-baseline.sh \
  --zap-auth-url https://app.example.com/login \
  --zap-auth-user admin --zap-auth-pass "$PASSWORD" \
  https://app.example.com
```

> Active scanning sends attack payloads — it requires explicit consent
> (`I_OWN_THIS_TARGET=yes … full`). Only run it against systems you own.

### 6. Run npm audit + Semgrep on your project

```bash
# From your project root
bash security/node-web/audit.sh .
```

### 7. Run Docker Bench for Security

```bash
bash security/scripts/docker-bench.sh
```

---

## Documentation

| Guide | Description |
|-------|-------------|
| [`docs/guia-principiantes.md`](docs/guia-principiantes.md) | **Start here.** Zero-to-first-scan walkthrough for beginners, glossary, troubleshooting |
| [`docs/como-usarlo-en-nuevo-proyecto.md`](docs/como-usarlo-en-nuevo-proyecto.md) | Add as git submodule, run local scans, integrate GitHub Actions |
| [`docs/proyecto-dockerizado.md`](docs/proyecto-dockerizado.md) | Full workflow for Dockerized apps: build → scan → ZAP → summary report |
| [`docs/sin-github.md`](docs/sin-github.md) | Use without GitHub: GitLab CI, Bitbucket Pipelines, Jenkins, local-only |

---

## Using the GitHub Actions Workflows

The workflows in `.github/workflows/` are designed for `workflow_call` — they are called from your project's own workflows, not run directly here.

> **Just want everything at once?** Copy the single ready-to-use `security.yml`
> from the [beginner guide](docs/guia-principiantes.md#7-activar-los-escaneos-automáticos-en-github) —
> it wires up Semgrep, Trivy and Secret/IaC in one file.

### Semgrep SAST in your project CI

Runs the module's Semgrep rules (plus the OWASP/JS/TS/React community packs)
against your source code and uploads findings to the Security tab.

```yaml
jobs:
  sast:
    uses: nicoendys/securitymodule/.github/workflows/semgrep.yml@v1
    with:
      # Optional — override the community packs, or add your own:
      config: "p/owasp-top-ten p/javascript p/typescript p/react"
      fail-on-findings: false
    permissions:
      contents: read
      security-events: write
      actions: read
```

### Trivy in your project CI

Create `.github/workflows/security.yml` in **your project**:

```yaml
name: Security Scans

on:
  pull_request:
  push:
    branches: [main]

jobs:
  trivy:
    uses: nicoendys/securitymodule/.github/workflows/trivy.yml@v1
    with:
      severity: "HIGH,CRITICAL"
      fail-on-findings: false
      # image-ref: "ghcr.io/you/app:${{ github.sha }}"  # optional: also scan a built image
      # trivy-config: ".trivy.yaml"                       # optional: your own config (defaults to the module's)
    permissions:
      contents: read
      security-events: write
      actions: read
```

The filesystem scan uses the `.trivy.yaml` shipped with this module by default —
your repo doesn't need its own copy. Pass `trivy-config` to override it, or
`image-ref` to additionally scan a built image.

### Secret & IaC scan in your project CI

Gitleaks scans your full git history for leaked credentials; Checkov adds broader
IaC policy coverage.

```yaml
jobs:
  secret-iac:
    uses: nicoendys/securitymodule/.github/workflows/secret-iac.yml@v1
    permissions:
      contents: read
      security-events: write
      actions: read
```

### ZAP DAST in your project CI

```yaml
jobs:
  zap:
    uses: nicoendys/securitymodule/.github/workflows/zap-baseline.yml@v1
    with:
      target-url: "https://staging.example.com"
      scan-type: "baseline"
      fail-on-warnings: false
    permissions:
      contents: read
      issues: write
      pull-requests: write
```

---

## Checklists

All checklists use markdown checkboxes. Work through them during threat modelling or before each release:

| Checklist | When to use |
|-----------|-------------|
| `checklists/owasp-wstg-web.md` | Full web application penetration testing |
| `checklists/api-security.md` | REST / GraphQL API review |
| `checklists/docker-hardening.md` | Before promoting a container image to production |

---

## Report Location

All scan scripts write reports to `security/templates/reports/` (git-ignored — reports are ephemeral build artifacts, not source). The orchestrator groups each run under a `run_TIMESTAMP/` subdirectory containing `summary.txt` plus every tool's output; the Trivy `image` mode adds a CycloneDX SBOM (`*.sbom.cdx.json`).

To browse HTML reports locally:

```bash
docker compose -f security/docker/docker-compose.yml --profile reports up -d
open http://localhost:8888
```

Prune old runs with `bash security/scripts/cleanup-reports.sh --keep-last 7`.

---

## Supply chain & versions

`versions.env` is the **single source of truth** for every pinned image:

- Tool images (Trivy, ZAP, Semgrep, Gitleaks, Checkov, Docker Bench) are pinned to exact version tags.
- Base images (`nginx:alpine`, `node:22-alpine`) are pinned by **`@sha256:` digest** — mutable tags can't silently change what runs.
- `docker/docker-compose.yml` reads these values through the `docker/.env` symlink, so nothing is duplicated.
- `update-versions.yml` opens a weekly PR that bumps tool versions and refreshes base-image digests from the Docker Hub API.

## Self-validation (dogfooding)

`ci.yml` doesn't just lint the module — it runs the module against itself on every PR/push:

- **self-scan** — `scan-trivy.sh` + `scan-secrets.sh` over this repository.
- **e2e** — the full `scan-full-dockerized.sh` orchestrator against a throwaway target, asserting a structured `summary.txt` is produced.

So a regression in the scripts fails CI here before it can reach a consumer.

---

## Semgrep Rules

The `node-web/semgrep.yml` rules cover:

- `eval()` / `new Function()` — arbitrary code execution
- Command injection via `child_process` (CJS, ESM named + namespace imports)
- SQL injection: string concatenation and Prisma `$queryRaw` interpolation
- Hardcoded JWT secrets and credentials
- Dangerous React patterns (`dangerouslySetInnerHTML`, `javascript:` hrefs)
- Reflected XSS: raw user input in Express `res.send` / Fastify `reply.send`
- Weak cryptography (`MD5`, `SHA-1`, `Math.random()`)
- Path traversal (`path.join`, `fs.readFile`/`writeFile` with user input)
- Prototype pollution
- Wildcard CORS (Express and Fastify)

Every rule has an annotated test fixture in `node-web/tests/`, validated by CI.

Run Semgrep standalone (requires Docker; the tag lives in `versions.env`):

```bash
docker run --rm -v "$(pwd)":/src -v "$(pwd)/security/node-web/semgrep.yml":/semgrep.yml \
  returntocorp/semgrep:1.166.0 semgrep --config /semgrep.yml /src
```

---

## Versioning

| Ref | Recommended use |
|-----|-----------------|
| `@v1` | Floating tag → latest stable 1.x release — **recommended** |
| `@1.4.0` | Pinned to a specific release (compliance environments) |
| `@main` | Bleeding edge — **not recommended** for production |

> **Note:** release tags have **no `v` prefix** (`1.4.0`, `1.3.5`, …). The only
> `v`-prefixed ref is the floating major tag `v1`, which always points to the
> latest 1.x release. The `update-v1-tag.yml` workflow moves `v1` automatically
> whenever a `1.x` tag is pushed (and can be dispatched manually to create it).

When using as a submodule, pin to a tag:
```bash
cd security && git checkout 1.4.0 && cd ..
git add security && git commit -m "chore(security): pin to 1.4.0"
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full guide: branch naming,
commit conventions, what CI enforces, how to add Semgrep rules with test
fixtures, and how tool versions are managed. In short:

1. Fork this repository.
2. Create a branch: `git checkout -b feat/your-change`.
3. Commit with clear messages (Conventional Commits) and update `CHANGELOG.md`.
4. Open a pull request — the template guides you — and make sure `ci.yml` is green.

---

## License

MIT — see [LICENSE](LICENSE).
