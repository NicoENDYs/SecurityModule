# security-testing-template

A reusable security-testing scaffold designed to be added as a **Git submodule** to any Node.js or React project. It standardises:

- Security checklists (OWASP WSTG, API Security Top 10, Docker Hardening)
- Local scan scripts (Trivy, ZAP, Docker Bench) that run via Docker — no host installs needed
- Reusable GitHub Actions workflows (Trivy + ZAP) callable with `workflow_call`
- Semgrep SAST rules tailored for JavaScript / TypeScript / React

---

## Directory Structure

```text
security-testing-template/
├── setup.sh                          # One-shot scaffold script
├── checklists/
│   ├── owasp-wstg-web.md             # OWASP WSTG v4.2 full checklist
│   ├── api-security.md               # OWASP API Security Top 10 (2023)
│   └── docker-hardening.md           # CIS Docker Benchmark v1.6
├── scripts/
│   ├── scan-full-dockerized.sh       # Orchestrator: build → trivy → compose up → ZAP → bench → summary
│   ├── scan-trivy.sh                 # Local Trivy scan (fs | image | repo)
│   ├── scan-zap-baseline.sh          # Local ZAP baseline or full scan
│   └── docker-bench.sh               # Docker Bench for Security
├── templates/
│   ├── zap/rules.tsv                 # ZAP alert filter rules
│   └── reports/                      # Output directory for all scan reports
├── .github/workflows/
│   ├── trivy.yml                     # Reusable Trivy workflow
│   └── zap-baseline.yml              # Reusable ZAP DAST workflow
├── node-web/
│   ├── semgrep.yml                   # Semgrep rules for JS/TS/React
│   └── audit.sh                      # npm audit + Semgrep via Docker
├── docker/
│   └── docker-compose.yml            # Isolated security lab
├── dast/
│   └── zap-full-scan.conf            # ZAP active scan configuration
└── docs/
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
bash security/scripts/scan-trivy.sh fs .        # filesystem
bash security/scripts/scan-trivy.sh image app:latest  # Docker image
```

Reports are saved to `security/templates/reports/`.

### 4. Run a ZAP baseline scan against a staging URL

```bash
bash security/scripts/scan-zap-baseline.sh https://staging.example.com
```

### 5. Run npm audit + Semgrep on your project

```bash
# From your project root
bash security/node-web/audit.sh .
```

### 6. Run Docker Bench for Security

```bash
bash security/scripts/docker-bench.sh
```

---

## Documentation

| Guide | Description |
|-------|-------------|
| [`docs/como-usarlo-en-nuevo-proyecto.md`](docs/como-usarlo-en-nuevo-proyecto.md) | Add as git submodule, run local scans, integrate GitHub Actions |
| [`docs/proyecto-dockerizado.md`](docs/proyecto-dockerizado.md) | Full workflow for Dockerized apps: build → scan → ZAP → summary report |
| [`docs/sin-github.md`](docs/sin-github.md) | Use without GitHub: GitLab CI, Bitbucket Pipelines, Jenkins, local-only |

---

## Using the GitHub Actions Workflows

The workflows in `.github/workflows/` are designed for `workflow_call` — they are called from your project's own workflows, not run directly here.

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

All scan scripts write reports to `security/templates/reports/`. This directory is listed in `.gitignore` by convention — reports are ephemeral build artifacts, not source.

To browse HTML reports locally:

```bash
docker compose -f security/docker/docker-compose.yml --profile reports up -d
open http://localhost:8888
```

---

## Semgrep Rules

The `node-web/semgrep.yml` rules cover:

- `eval()` / `new Function()` — arbitrary code execution
- Command injection via `child_process`
- SQL injection string concatenation
- Hardcoded JWT secrets and credentials
- Dangerous React patterns (`dangerouslySetInnerHTML`, `javascript:` hrefs)
- Weak cryptography (`MD5`, `SHA-1`, `Math.random()`)
- Path traversal from user input
- Prototype pollution
- Wildcard CORS

Run Semgrep standalone (requires Docker):

```bash
docker run --rm -v "$(pwd)":/src -v "$(pwd)/security/node-web/semgrep.yml":/semgrep.yml \
  returntocorp/semgrep semgrep --config /semgrep.yml /src
```

---

## Versioning

| Ref | Recommended use |
|-----|-----------------|
| `@v1` | Latest stable 1.x release — **recommended** |
| `@v1.1.0` | Pinned to a specific release (compliance environments) |
| `@main` | Bleeding edge — **not recommended** for production |

When using as a submodule, pin to a tag:
```bash
cd security && git checkout v1.1.0 && cd ..
git add security && git commit -m "chore(security): pin to v1.1.0"
```

---

## Contributing

1. Fork this repository.
2. Create a branch: `git checkout -b feat/your-change`.
3. Commit with clear messages.
4. Open a pull request.

---

## License

MIT — see [LICENSE](LICENSE).
