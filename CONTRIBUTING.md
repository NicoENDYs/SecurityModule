# Contributing to security-testing-template

Thanks for helping improve this module! This guide covers the workflow, the
quality bar enforced by CI, and how to extend the trickier parts (Semgrep
rules, tool versions).

---

## Workflow

1. **Fork** the repository (or create a branch if you have write access).
2. **Branch** from `main` using a descriptive prefix:
   - `feat/<short-description>` — new functionality
   - `fix/<short-description>` — bug fixes
   - `docs/<short-description>` — documentation only
   - `chore/<short-description>` — maintenance, version bumps
3. **Commit** using [Conventional Commits](https://www.conventionalcommits.org/)
   style, matching the existing history:
   ```
   feat(ci): add reusable Semgrep SAST workflow
   fix(scripts): define die() before the versions.env guard
   chore(versions): bump pinned tool versions
   ```
4. **Open a pull request** against `main`. The PR template will guide you
   through the expected sections (Summary / Key Changes / Implementation
   Details).
5. Update **`CHANGELOG.md`** under `[Unreleased]` for any user-visible change.

---

## Quality bar — what CI checks

Every PR must pass `ci.yml` (see the Actions tab). It runs:

| Job | What it validates | Run locally |
|-----|-------------------|-------------|
| **ShellCheck** | All bash scripts (`scripts/*.sh`, `node-web/audit.sh`, `setup.sh`) | `shellcheck --source-path=SCRIPTDIR -x scripts/*.sh node-web/audit.sh setup.sh` |
| **actionlint** | Workflow syntax in `.github/workflows/` (includes ShellCheck on every `run:` block) | `docker run --rm -v "$PWD":/repo -w /repo rhysd/actionlint:latest` |
| **Semgrep rule tests** | Every fixture in `node-web/tests/` against the full ruleset | See [Adding a Semgrep rule](#adding-a-semgrep-rule) |

Notes that save review round-trips:

- Bash scripts follow `set -euo pipefail`, define `log`/`err`/`die` helpers
  **before** sourcing `versions.env`, and run all tools via Docker (never
  assume a tool is installed on the host).
- Group consecutive redirects to the same file (`{ ...; } >> file`), or
  actionlint fails with ShellCheck SC2129.
- Workflow actions are pinned to a commit SHA with a version comment
  (`uses: owner/action@<sha> # vX.Y.Z`).

---

## Adding a Semgrep rule

Rules live in [`node-web/semgrep.yml`](node-web/semgrep.yml); fixtures live in
[`node-web/tests/`](node-web/tests/).

1. Add the rule to `node-web/semgrep.yml` with `metadata.category` and
   `metadata.cwe`.
2. Create a fixture `node-web/tests/<rule-topic>.js` (or `.jsx`) with
   annotated lines:
   ```js
   // ruleid: your-rule-id        ← the NEXT line must be flagged
   eval(userInput);

   // ok: your-rule-id            ← the NEXT line must NOT be flagged
   eval("use strict");
   ```
3. Optionally add `node-web/tests/<rule-topic>.yml` containing just your rule
   for quick local iteration:
   ```bash
   docker run --rm -v "$PWD/node-web":/src returntocorp/semgrep:<version> \
     semgrep --test /src/tests
   ```

> ⚠️ **Important:** CI tests every fixture against the **full** `semgrep.yml`,
> not just your rule. If a line in your fixture happens to match *another*
> rule, CI fails until you annotate that line too (with the other rule's id).
> Keep fixtures minimal to avoid accidental matches.

---

## Updating tool versions

**`versions.env` is the single source of truth.** Scripts source it at run
time, and `docker/docker-compose.yml` interpolates it via the `docker/.env`
symlink — never hardcode a version in those files.

The weekly `update-versions.yml` workflow opens an automated PR when new
releases are available. If you bump a version manually, change it only in
`versions.env` (plus the pinned tags in `.github/workflows/ci.yml` and
`secret-iac.yml`, which the workflow syncs via `sed`).

---

## Releases

- Release tags carry **no `v` prefix**: `1.4.0`, `1.5.0`, …
- The floating tag **`v1`** always points at the latest 1.x release. The
  `update-v1-tag.yml` workflow moves it automatically when a `1.*` tag is
  pushed (and supports manual dispatch to create or repair it).
- Consumers are told to pin `@v1` (workflows) or a specific tag (submodules),
  so breaking changes to reusable workflow inputs require a major-version plan.

---

## Reporting security issues

Please do **not** open a public issue for vulnerabilities — follow
[SECURITY.md](SECURITY.md) and use
[GitHub Security Advisories](https://github.com/NicoENDYs/SecurityModule/security/advisories/new).
