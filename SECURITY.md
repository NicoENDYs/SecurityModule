# Security Policy

## Reporting a Vulnerability

If you discover a security issue in this template or its scripts, **please do not open a public GitHub issue**. Instead, use one of the following private channels:

- **GitHub Security Advisories** (preferred):
  [Report a vulnerability](https://github.com/NicoENDYs/SecurityModule/security/advisories/new)

All reports are reviewed by the maintainer. You can expect:

| Action | Timeline |
|--------|----------|
| Initial acknowledgement | Within **72 hours** |
| Triage and severity assessment | Within **5 business days** |
| Patch for CRITICAL issues | Within **7 days** of confirmation |
| Patch for HIGH issues | Within **14 days** of confirmation |
| Public disclosure | Coordinated with reporter after patch is available |

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.x     | Yes       |
| < 1.0   | No        |

## Scope

This repository contains bash scripts, GitHub Actions workflows, Semgrep rules, and Docker Compose files intended for use as a security testing scaffold. The following are in scope for vulnerability reports:

- Command injection in bash scripts
- Insecure defaults that could harm a consumer project
- Supply chain issues (compromised dependencies or Docker images)
- Misleading security guidance in documentation or checklists

## Out of Scope

- Vulnerabilities in third-party tools (Trivy, ZAP, Semgrep, Docker Bench) — report those to their respective projects
- Issues only reproducible with non-default configuration
- Theoretical concerns without a working proof-of-concept

## Acknowledgements

Reporters who responsibly disclose valid vulnerabilities will be credited in the release notes (unless they prefer to remain anonymous).
