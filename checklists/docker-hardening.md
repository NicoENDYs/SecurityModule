# Docker Hardening Checklist

> Based on CIS Docker Benchmark v1.6 and Docker security best practices.  
> Status key: `[ ]` Not started · `[~]` In progress · `[x]` Done · `[N/A]` Not applicable

---

## 1. Docker Host Configuration

| CIS ID | Check | Status | Notes |
|--------|-------|--------|-------|
| 1.1 | Docker daemon runs as root but is configured securely | `[ ]` | |
| 1.2 | Docker daemon socket not exposed over TCP without TLS | `[ ]` | |
| 1.3 | Docker daemon configured to use TLS authentication | `[ ]` | |
| 1.4 | Docker content trust enabled (`DOCKER_CONTENT_TRUST=1`) | `[ ]` | |
| 1.5 | Host OS is hardened and kept up to date | `[ ]` | |
| 1.6 | Auditing configured for Docker daemon socket | `[ ]` | /var/run/docker.sock |
| 1.7 | Docker's default bridge `docker0` is not used for inter-container comms | `[ ]` | |

---

## 2. Docker Daemon Configuration

| CIS ID | Check | Status | Notes |
|--------|-------|--------|-------|
| 2.1 | `--icc=false` (disable inter-container communication by default) | `[ ]` | |
| 2.2 | `--log-level=info` set | `[ ]` | |
| 2.3 | Iptables rules not disabled (`--iptables` not set to false) | `[ ]` | |
| 2.4 | Insecure registries not configured | `[ ]` | |
| 2.5 | `aufs` storage driver not used | `[ ]` | Prefer overlay2 |
| 2.6 | TLS CA certificate configured | `[ ]` | |
| 2.7 | Default `ulimits` set appropriately | `[ ]` | |
| 2.8 | User namespace remapping enabled | `[ ]` | `--userns-remap=default` |
| 2.9 | Experimental features disabled in production | `[ ]` | |
| 2.10 | Live restore enabled (`--live-restore`) | `[ ]` | |
| 2.11 | `userland-proxy` disabled where not needed | `[ ]` | |
| 2.12 | Daemon-wide custom seccomp profile applied | `[ ]` | |
| 2.13 | Containers restricted from acquiring new privileges | `[ ]` | `--no-new-privileges` |

---

## 3. Docker Image Security

| Check | Status | Notes |
|-------|--------|-------|
| Base images sourced from official or verified registries | `[ ]` | |
| Minimal base image used (distroless, alpine, scratch) | `[ ]` | |
| No credentials, secrets, or tokens baked into image layers | `[ ]` | |
| Multi-stage builds used to minimize attack surface | `[ ]` | |
| `.dockerignore` excludes `.git`, `.env`, `node_modules`, secrets | `[ ]` | |
| Image scanned for CVEs before deployment (Trivy / Grype) | `[ ]` | |
| `USER` instruction sets a non-root user | `[ ]` | |
| Image signed with Docker Content Trust or Sigstore | `[ ]` | |
| Image digest pinned in `FROM` (`image@sha256:…`) | `[ ]` | |
| No `SUID`/`SGID` binaries in image unless required | `[ ]` | |
| `HEALTHCHECK` instruction defined | `[ ]` | |

---

## 4. Container Runtime Configuration

| CIS ID | Check | Status | Notes |
|--------|-------|--------|-------|
| 5.1 | `--privileged` flag not used | `[ ]` | |
| 5.2 | Sensitive host filesystem paths not mounted | `[ ]` | /, /boot, /etc |
| 5.3 | Docker socket not mounted inside containers | `[ ]` | /var/run/docker.sock |
| 5.4 | `--memory` limit set | `[ ]` | Prevent OOM DoS |
| 5.5 | CPU shares/quotas set | `[ ]` | `--cpu-shares` |
| 5.6 | Container root filesystem is read-only (`--read-only`) | `[ ]` | |
| 5.7 | Capabilities dropped to minimum (`--cap-drop=ALL`, add only needed) | `[ ]` | |
| 5.8 | `--security-opt=no-new-privileges` set | `[ ]` | |
| 5.9 | Seccomp profile applied | `[ ]` | |
| 5.10 | AppArmor / SELinux profile applied | `[ ]` | |
| 5.11 | PIDs limit set (`--pids-limit`) | `[ ]` | Prevent fork bombs |
| 5.12 | Container uses its own network namespace | `[ ]` | Not `--net=host` |
| 5.13 | Port exposure minimized (only required ports bound) | `[ ]` | |
| 5.14 | `--restart=on-failure:5` or managed by orchestrator | `[ ]` | |

---

## 5. Docker Compose / Orchestration

| Check | Status | Notes |
|-------|--------|-------|
| Compose files use `secrets` for sensitive values (not `environment:`) | `[ ]` | |
| Networks segmented: frontend, backend, db on separate networks | `[ ]` | |
| No `privileged: true` in compose files | `[ ]` | |
| `read_only: true` on container root filesystem | `[ ]` | |
| `tmpfs` used for writable ephemeral storage | `[ ]` | |
| Compose file stored in version control with secrets stripped | `[ ]` | |
| Image tags pinned (not `latest`) | `[ ]` | |

---

## 6. Registry & Supply Chain

| Check | Status | Notes |
|-------|--------|-------|
| Private registry requires authentication | `[ ]` | |
| Images pulled over HTTPS | `[ ]` | |
| Image provenance verified (SLSA level 2+) | `[ ]` | |
| SBOMs generated for deployed images | `[ ]` | |
| Dependency updates automated (Dependabot / Renovate) | `[ ]` | |

---

## 7. Logging & Monitoring

| Check | Status | Notes |
|-------|--------|-------|
| Container logs forwarded to centralized logging | `[ ]` | |
| Log driver not set to `none` | `[ ]` | |
| Docker events monitored (`docker events`) | `[ ]` | |
| Runtime security monitoring in place (Falco, Sysdig) | `[ ]` | |
| Container exit codes and restarts alerted on | `[ ]` | |

---

## Sign-off

| Auditor | Date | Docker Version | Verdict |
|---------|------|----------------|---------|
| | | | |
