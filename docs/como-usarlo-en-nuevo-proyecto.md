# Cómo usar `security-testing-template` en un nuevo proyecto

Esta guía explica paso a paso cómo integrar este repositorio como **submódulo de Git** en cualquier proyecto Node.js o React, y cómo invocar los flujos de GitHub Actions desde el repositorio principal.

---

## Requisitos previos

| Herramienta | Versión mínima | Uso |
|-------------|----------------|-----|
| Git | 2.28+ | Gestión del submódulo |
| Docker | 24+ | Ejecutar escaneos locales (Trivy, ZAP, Semgrep) |
| bash | 4+ | Scripts de escaneo |

> No es necesario instalar Trivy, ZAP ni Semgrep directamente en el host.

---

## Paso 1 — Añadir el submódulo

Desde la raíz de tu proyecto:

```bash
git submodule add https://github.com/nicoendys/securitymodule security
git submodule update --init --recursive
```

Esto crea:

```
tu-proyecto/
├── .gitmodules           ← referencia al submódulo añadida automáticamente
└── security/             ← contenido de este repositorio
```

El archivo `.gitmodules` tendrá este aspecto:

```ini
[submodule "security"]
    path = security
    url = https://github.com/nicoendys/securitymodule
    branch = main
```

Haz commit de estos cambios:

```bash
git add .gitmodules security
git commit -m "chore: add security-testing-template submodule"
```

---

## Paso 2 — Clonar un proyecto que ya tiene el submódulo

Cuando alguien clona el repositorio por primera vez:

```bash
git clone --recurse-submodules https://github.com/tu-org/tu-proyecto
```

O si ya tenías el repositorio clonado sin `--recurse-submodules`:

```bash
git submodule update --init --recursive
```

---

## Paso 3 — Ejecutar escaneos locales

Todos los scripts se ejecutan desde la **raíz de tu proyecto**, pasando la ruta del submódulo.

### 3.1 Escaneo de dependencias y código fuente (SAST)

```bash
# npm audit + Semgrep (JS/TS/React)
bash security/node-web/audit.sh .
```

Los reportes se guardan en `security/templates/reports/`.

### 3.2 Escaneo de vulnerabilidades en contenedores (Trivy)

```bash
# Escaneo del sistema de archivos del proyecto
bash security/scripts/scan-trivy.sh fs .

# Escaneo de una imagen Docker
bash security/scripts/scan-trivy.sh image tu-imagen:tag

# Escaneo de un repositorio remoto
bash security/scripts/scan-trivy.sh repo https://github.com/org/repo
```

### 3.3 Escaneo DAST contra entorno de staging (ZAP)

```bash
# Escaneo pasivo (baseline) — recomendado para CI/CD
bash security/scripts/scan-zap-baseline.sh https://staging.tu-app.com

# Escaneo activo (más intrusivo, usar solo en entornos controlados)
bash security/scripts/scan-zap-baseline.sh https://staging.tu-app.com ajax
```

### 3.4 Auditoría de configuración Docker

```bash
bash security/scripts/docker-bench.sh
```

### 3.5 Ver reportes en el navegador

```bash
docker compose -f security/docker/docker-compose.yml --profile reports up -d
# Abre http://localhost:8888 en tu navegador
```

---

## Paso 4 — Integrar los flujos de GitHub Actions

Los workflows de este submódulo están diseñados para `workflow_call`, lo que significa que son **llamados desde los workflows de tu propio repositorio**, no ejecutados directamente.

### 4.1 Crear el workflow de seguridad en tu proyecto

Crea el archivo `.github/workflows/security.yml` en la raíz de **tu proyecto**:

```yaml
name: Security Scans

on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [main]
  schedule:
    - cron: "0 7 * * 1"  # Cada lunes a las 07:00 UTC

jobs:
  # ── Trivy: escaneo de dependencias, filesystem e IaC ──────────────────────
  trivy:
    name: Trivy Vulnerability Scan
    uses: nicoendys/securitymodule/.github/workflows/trivy.yml@main
    with:
      severity: "HIGH,CRITICAL"
      fail-on-findings: false
    permissions:
      contents: read
      security-events: write
      actions: read

  # ── ZAP: DAST contra staging (se activa manualmente o en schedule) ────────
  zap-dast:
    name: ZAP DAST Baseline
    uses: nicoendys/securitymodule/.github/workflows/zap-baseline.yml@main
    with:
      target-url: "https://staging.tu-app.com"
      scan-type: "baseline"
      fail-on-warnings: false
    permissions:
      contents: read
      issues: write
      pull-requests: write
    # Solo ejecutar en pushes a main o manualmente, no en cada PR
    if: github.event_name == 'push' || github.event_name == 'schedule'
```

### 4.2 Escaneo de imagen Docker en CI/CD

Si tu proyecto construye una imagen Docker, añade esta variante de Trivy al workflow anterior:

```yaml
  trivy-image:
    name: Trivy Image Scan
    needs: build          # asume que tienes un job 'build' que hace docker build
    uses: nicoendys/securitymodule/.github/workflows/trivy.yml@main
    with:
      image-ref: "ghcr.io/tu-org/tu-imagen:${{ github.sha }}"
      severity: "HIGH,CRITICAL"
      fail-on-findings: true
    permissions:
      contents: read
      security-events: write
      actions: read
```

### 4.3 ZAP full scan (activo) — solo en rama de release

```yaml
  zap-full:
    name: ZAP Full Scan (active)
    uses: nicoendys/securitymodule/.github/workflows/zap-baseline.yml@main
    with:
      target-url: "https://staging.tu-app.com"
      scan-type: "full"
      fail-on-warnings: true
    if: startsWith(github.ref, 'refs/heads/release/')
    permissions:
      contents: read
      issues: write
      pull-requests: write
```

---

## Paso 5 — Ver resultados en GitHub

| Herramienta | Dónde ver los resultados |
|-------------|--------------------------|
| Trivy (SARIF) | Security → Code scanning alerts en tu repositorio |
| ZAP | Actions → artifacts del workflow + GitHub Issues creados automáticamente |
| npm audit | Dependabot alerts (si está habilitado) |

Para activar **Code Scanning** en tu repositorio: Settings → Security → Code security and analysis → Enable Code scanning.

---

## Paso 6 — Actualizar el submódulo

Cuando este repositorio publique nuevas reglas o workflows:

```bash
# Desde la raíz de tu proyecto
git submodule update --remote --merge security
git add security
git commit -m "chore(security): update security-testing-template submodule"
```

Para fijar el submódulo a un commit o tag específico:

```bash
cd security
git checkout v1.2.0
cd ..
git add security
git commit -m "chore(security): pin submodule to v1.2.0"
```

---

## Paso 7 — Completar los checklists

Antes de cada release significativo, revisa los checklists manualmente:

```bash
# Abre en tu editor
code security/checklists/owasp-wstg-web.md
code security/checklists/api-security.md
code security/checklists/docker-hardening.md
```

Marca cada ítem con `[x]` y guarda una copia del checklist completado (por ejemplo en `docs/security/review-YYYYMMDD.md`).

---

## Estructura de archivos recomendada en tu proyecto

```text
tu-proyecto/
├── .github/
│   └── workflows/
│       ├── ci.yml                 # Tu workflow de CI/CD principal
│       └── security.yml          # Llama a los workflows del submódulo
├── security/                     # Este submódulo (no editar aquí)
│   └── ...
├── .gitmodules
└── ...
```

---

## Preguntas frecuentes

**¿Los reportes se suben a GitHub?**  
No por defecto. Los scripts locales guardan los reportes en `security/templates/reports/` (directorio ignorado por git). En CI, los workflows de GitHub Actions suben los reportes como artifacts de la acción (disponibles 30 días).

**¿Puedo personalizar las reglas de ZAP?**  
Sí. Edita `security/templates/zap/rules.tsv` para ajustar qué alertas se ignoran, advierten o fallan. Los cambios se aplican tanto en los scripts locales como en el workflow de GitHub Actions.

**¿Puedo añadir mis propias reglas de Semgrep?**  
Sí. Añade nuevas entradas al archivo `security/node-web/semgrep.yml` siguiendo el mismo formato YAML. También puedes crear un archivo adicional `semgrep-custom.yml` en tu proyecto y pasarlo al script con `--config`.

**¿El submódulo funciona en Windows?**  
Los scripts `.sh` requieren bash (WSL2 o Git Bash). Los workflows de GitHub Actions corren en `ubuntu-latest` y funcionan en todos los sistemas operativos en el lado del CI.
