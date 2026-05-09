# Guía: usar el template en un proyecto Dockerizado

Esta guía cubre el flujo completo de seguridad cuando tu aplicación ya corre en contenedores — ya sea un backend Node.js, una app React con nginx, o un stack multi-servicio con `docker-compose`.

---

## Flujo de escaneo para proyectos Dockerizados

```
Código fuente
     │
     ▼
[1] SAST ──────────────── npm audit + Semgrep → fallos en código/deps
     │
     ▼
[2] docker build
     │
     ▼
[3] Trivy image scan ──── CVEs en la imagen construida
     │
     ▼
[4] docker compose up ─── levanta el stack completo
     │
     ▼
[5] ZAP baseline ──────── escaneo DAST pasivo contra la app en vivo
     │
     ▼
[6] Docker Bench ──────── verificaciones CIS del daemon y contenedores
     │
     ▼
[7] Summary report ─────── summary.txt con PASS/WARN/FAIL por herramienta
```

---

## Opción A — Script orquestador (recomendado)

El script `scripts/scan-full-dockerized.sh` hace todos los pasos anteriores de una sola vez.

### Caso más común: stack con docker-compose

Estructura típica del proyecto:

```
mi-app/
├── docker-compose.yml
├── Dockerfile
├── src/
├── package.json
└── security/          ← este submódulo
```

```bash
# Desde la raíz de mi-app/
bash security/scripts/scan-full-dockerized.sh \
  --project-root . \
  --url http://localhost:3000 \
  --compose-file docker-compose.yml \
  --service app \
  --timeout 90
```

Qué hace internamente:

| Paso | Acción |
|------|--------|
| SAST | `npm audit` + Semgrep en el código fuente |
| Build | `docker compose build app` |
| Trivy | Escanea la imagen construida |
| Compose up | `docker compose up -d` |
| Espera | Hace polling a `http://localhost:3000` hasta que responde (o timeout) |
| ZAP | Baseline scan contra `http://localhost:3000` |
| Bench | Docker Bench for Security |
| Down | `docker compose down` |
| Resumen | Genera `summary.txt` con PASS/WARN/FAIL |

### Con imagen ya construida (omite el build)

```bash
bash security/scripts/scan-full-dockerized.sh \
  --project-root . \
  --image mi-imagen:v1.2.3 \
  --url http://localhost:3000
```

### Modo estricto: falla el proceso si hay hallazgos críticos

```bash
bash security/scripts/scan-full-dockerized.sh \
  --project-root . \
  --url http://localhost:3000 \
  --fail-on-findings
# → exit 1 si Trivy/ZAP/Bench encuentran algo con severidad HIGH/CRITICAL
```

### Saltar pasos individuales

```bash
# Solo imagen + ZAP, sin SAST ni Docker Bench
bash security/scripts/scan-full-dockerized.sh \
  --project-root . \
  --url http://localhost:4000 \
  --skip-sast \
  --skip-bench
```

---

## Opción B — Scripts individuales (control granular)

### 1. Escanear la imagen Docker con Trivy

```bash
# Primero construye la imagen
docker build -t mi-app:dev .

# Luego escanea
bash security/scripts/scan-trivy.sh image mi-app:dev
```

El reporte se guarda en:
- `security/templates/reports/trivy-image_mi-app_dev_YYYYMMDD_HHMMSS.txt`
- `security/templates/reports/trivy-image_mi-app_dev_YYYYMMDD_HHMMSS.json`

### 2. Levantar el stack y escanear con ZAP

```bash
# Levanta el proyecto
docker compose up -d

# Espera a que esté listo (ajusta la URL a tu app)
until curl -sf http://localhost:3000 > /dev/null; do sleep 2; done

# Escanea
bash security/scripts/scan-zap-baseline.sh http://localhost:3000

# Para el stack
docker compose down
```

### 3. Escanear el filesystem del proyecto (dependencias y secrets)

```bash
bash security/scripts/scan-trivy.sh fs .
```

Detecta: CVEs en `node_modules`, secrets en código, misconfiguraciones en `Dockerfile`/`docker-compose.yml`.

### 4. Auditar código fuente con Semgrep

```bash
bash security/node-web/audit.sh .
```

---

## Dónde se guardan los reportes

Todos los reportes van a `security/templates/reports/`. Cada ejecución del script orquestador crea un subdirectorio con timestamp:

```
security/templates/reports/
└── run_20260508_143022/
    ├── summary.txt          ← resumen PASS/WARN/FAIL de todos los pasos
    ├── sast.log             ← salida de npm audit + Semgrep
    ├── trivy-image.json     ← vulnerabilidades en la imagen (JSON)
    ├── trivy-image.txt      ← vulnerabilidades en la imagen (tabla)
    ├── zap-baseline_*.html  ← reporte ZAP navegable en el browser
    ├── zap-baseline_*.json  ← reporte ZAP en JSON (para parsear en CI)
    ├── zap-baseline_*.md    ← reporte ZAP en Markdown
    ├── docker-bench.log     ← salida de Docker Bench for Security
    └── docker-build.log     ← salida del docker build
```

### Ver el reporte HTML de ZAP en el navegador

```bash
# Opción 1: abre directamente (macOS/Linux con GUI)
open security/templates/reports/run_YYYYMMDD_HHMMSS/zap-baseline_*.html

# Opción 2: servidor HTTP embebido del lab
docker compose -f security/docker/docker-compose.yml --profile reports up -d
# Abre http://localhost:8888 en tu navegador
```

### Parsear el resumen para un pipeline propio

```bash
cat security/templates/reports/run_YYYYMMDD_HHMMSS/summary.txt
# Salida ejemplo:
# ══════════════════════════════════════════════════════
#  Security Scan Summary
#  Project : /home/user/mi-app
#  Run at  : Thu May  8 14:30:22 UTC 2026
#  Reports : security/templates/reports/run_20260508_143022
# ══════════════════════════════════════════════════════
#  Tool                Result
# ──────────────────────────────────────────────────────
#  sast               PASS
#  trivy              WARN
#  zap                PASS
#  bench              WARN
# ──────────────────────────────────────────────────────
#  Total critical findings: 3
# ══════════════════════════════════════════════════════
```

---

## Integrar en GitHub Actions (proyecto dockerizado)

Crea `.github/workflows/security.yml` en **tu proyecto**:

```yaml
name: Security — Dockerized App

on:
  pull_request:
  push:
    branches: [main]

jobs:
  # ── SAST + Imagen ──────────────────────────────────────────────────────────
  trivy:
    name: Trivy (source + image)
    uses: nicoendys/securitymodule/.github/workflows/trivy.yml@v1
    with:
      severity: "HIGH,CRITICAL"
      fail-on-findings: false
    permissions:
      contents: read
      security-events: write
      actions: read

  # ── Build y Trivy sobre la imagen real ────────────────────────────────────
  trivy-image:
    name: Trivy — Docker image
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build Docker image
        run: docker build -t app:${{ github.sha }} .

      - name: Scan built image with Trivy
        uses: aquasecurity/trivy-action@0.31.0
        with:
          scan-type: image
          image-ref: app:${{ github.sha }}
          severity: HIGH,CRITICAL
          format: sarif
          output: trivy-image.sarif
          exit-code: "0"

      - name: Upload image scan to Security tab
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: trivy-image.sarif
          category: trivy-docker-image

  # ── DAST contra staging ───────────────────────────────────────────────────
  zap-dast:
    name: ZAP DAST (staging)
    uses: nicoendys/securitymodule/.github/workflows/zap-baseline.yml@v1
    with:
      target-url: ${{ vars.STAGING_URL }}   # ← define STAGING_URL en Settings > Variables
      scan-type: baseline
      fail-on-warnings: false
    if: github.ref == 'refs/heads/main'
    permissions:
      contents: read
      issues: write
      pull-requests: write
```

> **Nota:** Para el DAST necesitas que la app esté desplegada en staging antes de que corra el job de ZAP. Añade `needs: deploy` si tienes un job de despliegue previo.

---

## Preguntas frecuentes para proyectos dockerizados

**¿ZAP puede escanear una app que corre dentro de docker-compose en el mismo host?**  
Sí. El script `scan-full-dockerized.sh` arranca ZAP con `--network host`, por lo que accede a `localhost:PUERTO` del host aunque la app corra en contenedor.

**¿Y si mi app usa HTTPS en local (certificado autofirmado)?**  
Pasa la flag `-k` a ZAP. Edita la línea `zap-baseline.py` en el script y añade `-z "-config connection.sslInsecureConnect=true"`.

**¿Trivy escanea el `docker-compose.yml` además de la imagen?**  
Sí. En el paso de filesystem (`scan-trivy.sh fs .`) Trivy detecta misconfiguraciones en `Dockerfile` y `docker-compose.yml` (imágenes con `latest`, contenedores privilegiados, etc.).

**¿Los reportes se borran entre ejecuciones?**  
No. Cada ejecución del orquestador crea un nuevo directorio `run_TIMESTAMP`. Los reportes se acumulan hasta que los borres manualmente o añadas una rotación.

**¿Cuánto tarda un escaneo completo?**  
Depende del tamaño de la imagen y la app, pero típicamente:
- SAST: 1–3 min
- Trivy image: 2–5 min (más la primera vez por descarga de DB)
- ZAP baseline: 2–10 min
- Docker Bench: < 1 min
- **Total estimado: 8–20 min**
