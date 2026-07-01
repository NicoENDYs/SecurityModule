# Guía para principiantes 🚀

> ¿Nunca has usado herramientas de seguridad? Empieza **aquí**. Esta guía asume
> cero conocimientos previos y usa el mínimo de jerga posible. Si algo no se
> entiende, revisa el [glosario](#glosario-sin-tecnicismos) al final.

Este módulo es una **caja de herramientas de seguridad lista para usar**. La
añades a tu proyecto una sola vez y, a partir de ahí, puedes escanear tu código
en busca de fallos de seguridad con un solo comando —sin instalar nada más que
Docker.

---

## Índice

1. [¿Qué hace exactamente?](#1-qué-hace-exactamente)
2. [Lo único que necesitas instalar](#2-lo-único-que-necesitas-instalar)
3. [Instalación en 3 pasos](#3-instalación-en-3-pasos)
4. [Tu primer escaneo (2 minutos)](#4-tu-primer-escaneo-2-minutos)
5. [El escaneo completo con un solo comando](#5-el-escaneo-completo-con-un-solo-comando)
6. [Cómo leer los resultados](#6-cómo-leer-los-resultados)
7. [Activar los escaneos automáticos en GitHub](#7-activar-los-escaneos-automáticos-en-github)
8. [Solución de problemas](#8-solución-de-problemas)
9. [Preguntas frecuentes](#9-preguntas-frecuentes)
10. [Glosario sin tecnicismos](#glosario-sin-tecnicismos)
11. [Chuleta de comandos](#chuleta-de-comandos)

---

## 1. ¿Qué hace exactamente?

Revisa tu proyecto desde **cuatro ángulos** distintos. No hace falta que
entiendas los detalles todavía; solo quédate con la idea general:

| # | Herramienta | Pregunta que responde | En una frase |
|---|-------------|-----------------------|--------------|
| 1 | **Semgrep** (SAST) | ¿Hay patrones peligrosos en **mi código**? | Lee tu código JS/TS/React buscando fallos como inyecciones o contraseñas escritas a mano. |
| 2 | **Trivy** (SCA + IaC) | ¿Tengo **librerías o configuraciones** vulnerables? | Revisa tus dependencias y tus archivos Docker en busca de vulnerabilidades conocidas. |
| 3 | **Gitleaks** (secretos) | ¿He subido **contraseñas o claves** por error? | Busca secretos filtrados en todo el historial de tu repositorio. |
| 4 | **OWASP ZAP** (DAST) | ¿Mi **app en marcha** tiene agujeros? | Ataca de forma controlada tu aplicación ya desplegada y reporta lo que encuentra. |

> 💡 **No necesitas usarlas todas de golpe.** Puedes empezar por una (por
> ejemplo, escanear tu código con Semgrep) e ir añadiendo el resto cuando te
> sientas cómodo.

---

## 2. Lo único que necesitas instalar

Solo **dos** cosas en tu ordenador:

| Herramienta | ¿Para qué? | Cómo comprobar que la tienes |
|-------------|-----------|------------------------------|
| **Docker** | Ejecuta todas las herramientas de seguridad dentro de contenedores, así no tienes que instalar Trivy, ZAP, etc. | `docker --version` |
| **Git + bash** | Descargar el módulo y ejecutar los scripts. En Windows usa **WSL2** o **Git Bash**. | `git --version` y `bash --version` |

- ¿No tienes Docker? Instálalo desde <https://docs.docker.com/get-docker/>.
- **Importante:** Docker tiene que estar **abierto y en ejecución** cuando lances
  un escaneo. En Windows/Mac eso significa que la app "Docker Desktop" debe estar
  encendida (icono de la ballena activo).

> ✅ **Comprobación rápida:** si este comando imprime información y no un error,
> estás listo:
> ```bash
> docker info
> ```

---

## 3. Instalación en 3 pasos

Vas a añadir este módulo a tu proyecto como un **submódulo de Git** (una carpeta
`security/` que apunta a este repositorio). Desde la **raíz de tu proyecto**:

```bash
# Paso 1 — Añadir el módulo dentro de una carpeta llamada "security"
git submodule add https://github.com/nicoendys/securitymodule security

# Paso 2 — Descargar su contenido
git submodule update --init --recursive

# Paso 3 — Guardar el cambio en tu proyecto
git add .gitmodules security
git commit -m "chore: añadir módulo de seguridad"
```

¡Listo! Ahora tienes una carpeta `security/` con todas las herramientas.

> 🧭 **¿Qué es un submódulo?** Es una forma de incluir *otro* repositorio Git
> dentro del tuyo sin copiar y pegar. Cuando el módulo se actualice, tú decides
> cuándo traer esos cambios (ver [FAQ](#9-preguntas-frecuentes)).

---

## 4. Tu primer escaneo (2 minutos)

El escaneo más sencillo y rápido: **revisar tu código y tus dependencias**. No
necesitas tener la app corriendo ni Docker Compose.

```bash
# Desde la raíz de tu proyecto
bash security/node-web/audit.sh .
```

Esto ejecuta dos comprobaciones:
- `npm audit` → dependencias con vulnerabilidades conocidas.
- **Semgrep** → patrones peligrosos en tu código (JS/TS/React).

Al terminar verás un resumen en la terminal y los reportes completos se guardan
en `security/templates/reports/`.

> 🎉 **¡Felicidades!** Acabas de correr tu primer escaneo de seguridad.

¿Quieres revisar solo las vulnerabilidades del sistema de archivos?

```bash
bash security/scripts/scan-trivy.sh fs .
```

---

## 5. El escaneo completo con un solo comando

Cuando tu app está **dockerizada** (tiene un `Dockerfile` o `docker-compose.yml`),
puedes lanzar **todo el pipeline de detección** con un único comando:

```bash
bash security/scripts/scan-full-dockerized.sh \
  --project-root . \
  --url http://localhost:3000
```

Este comando, en orden y de forma automática:

```
[1] Revisa tu código y dependencias (SAST)
[2] Construye tu imagen Docker
[3] Escanea la imagen en busca de vulnerabilidades (Trivy)
[4] Levanta tu app con Docker Compose
[5] Ataca la app en marcha de forma segura (ZAP)
[6] Audita la configuración de Docker (Docker Bench)
[7] Genera un resumen final con PASS / WARN / FAIL por herramienta
```

> 🔧 **¿Tu app corre en otro puerto?** Cambia `--url http://localhost:3000` por
> el puerto correcto. ¿La app tarda en arrancar? Añade `--timeout 120`.
> ¿Responde en `/api/health` en vez de `/`? Añade `--health-path /api/health`.

Para ver **todas las opciones**:

```bash
bash security/scripts/scan-full-dockerized.sh --help
```

---

## 6. Cómo leer los resultados

### Dónde están los reportes

Todo se guarda en `security/templates/reports/`. El escaneo completo crea una
subcarpeta con fecha y hora, por ejemplo `run_20260701_143022/`, que contiene:

| Archivo | Qué es |
|---------|--------|
| `summary.txt` | **Empieza por aquí.** Resumen PASS/WARN/FAIL de todas las herramientas. |
| `sast.log` | Salida de npm audit + Semgrep. |
| `trivy-image.txt` | Vulnerabilidades de la imagen, en tabla legible. |
| `zap-baseline_*.html` | Reporte de ZAP navegable en el navegador. |
| `docker-bench.log` | Auditoría de configuración de Docker. |

### Qué significan PASS / WARN / FAIL

| Resultado | Significado | ¿Qué hago? |
|-----------|-------------|------------|
| 🟢 **PASS** | No se encontraron problemas relevantes. | Nada, ¡bien hecho! |
| 🟡 **WARN** | Se encontraron hallazgos que conviene revisar. | Abre el reporte de esa herramienta y valóralos. |
| ⚪ **SKIP** | Esa comprobación no se ejecutó. | Normal si usaste `--skip-...` o falta un archivo. |
| 🔴 **FAIL** | El proceso terminó en error (solo con `--fail-on-findings`). | Corrige los hallazgos críticos antes de continuar. |

> 📖 **Ver el reporte HTML de ZAP en el navegador:**
> ```bash
> docker compose -f security/docker/docker-compose.yml --profile reports up -d
> # Abre http://localhost:8888
> ```

---

## 7. Activar los escaneos automáticos en GitHub

Lo mejor es que estos escaneos se ejecuten **solos** cada vez que abres un Pull
Request o haces push. Para ello, crea **un único archivo** en tu proyecto:
`.github/workflows/security.yml`. Copia y pega esto tal cual:

```yaml
name: Seguridad

on:
  pull_request:
  push:
    branches: [main]

jobs:
  # 1) Semgrep — revisa TU código (SAST)
  sast:
    uses: nicoendys/securitymodule/.github/workflows/semgrep.yml@v1
    permissions:
      contents: read
      security-events: write
      actions: read

  # 2) Trivy — dependencias, filesystem e IaC (SCA + misconfig)
  trivy:
    uses: nicoendys/securitymodule/.github/workflows/trivy.yml@v1
    with:
      severity: "HIGH,CRITICAL"
      fail-on-findings: false
    permissions:
      contents: read
      security-events: write
      actions: read

  # 3) Gitleaks + Checkov — secretos filtrados e IaC
  secret-iac:
    uses: nicoendys/securitymodule/.github/workflows/secret-iac.yml@v1
    permissions:
      contents: read
      security-events: write
      actions: read
```

> ✅ **Eso es todo.** Con estos tres bloques, cada PR se escanea con Semgrep,
> Trivy, Gitleaks y Checkov automáticamente. **No necesitas configurar tokens ni
> secretos**: usan el `GITHUB_TOKEN` que GitHub provee por defecto.

### ¿Y el escaneo ZAP de la app en marcha?

ZAP necesita una **URL de tu app ya desplegada** (por ejemplo, un entorno de
staging). Añade este bloque solo si tienes una:

```yaml
  dast:
    uses: nicoendys/securitymodule/.github/workflows/zap-baseline.yml@v1
    with:
      target-url: "https://staging.tu-app.com"
      scan-type: "baseline"
    if: github.event_name == 'push'   # solo en push a main, no en cada PR
    permissions:
      contents: read
      issues: write
      pull-requests: write
```

### Dónde ver los resultados en GitHub

- Ve a la pestaña **Actions** de tu repositorio → abre el workflow "Seguridad".
  Cada ejecución muestra un **resumen** con el número de hallazgos por herramienta.
- Ve a **Security → Code scanning alerts** para la lista detallada de cada fallo,
  con el archivo y la línea exactos.

> 🔐 La primera vez, activa el escaneo en:
> **Settings → Advanced Security → Code scanning** (o **Code security and
> analysis**, según tu versión de GitHub).

---

## 8. Solución de problemas

| Síntoma | Causa probable | Solución |
|---------|----------------|----------|
| `Docker daemon is not running` | Docker no está encendido. | Abre Docker Desktop y espera a que arranque; reintenta. |
| `Docker is not installed or not in PATH` | Falta Docker o el terminal no lo encuentra. | Instálalo desde el [enlace oficial](https://docs.docker.com/get-docker/) y reabre la terminal. |
| La carpeta `security/` está vacía | El submódulo no se descargó. | Ejecuta `git submodule update --init --recursive`. |
| `Timed out waiting for ...` en el escaneo completo | La app tarda en arrancar o el puerto/ruta no coincide. | Aumenta el tiempo con `--timeout 120` y verifica `--url` y `--health-path`. |
| ZAP tarda muchísimo | Es normal: el escaneo activo puede tardar minutos. | Usa el modo `baseline` (por defecto) para CI; el activo solo en entornos propios. |
| `Permission denied` al ejecutar un script | El script no tiene permiso de ejecución. | Ejecútalo con `bash security/scripts/...sh` (con `bash` delante) o corre `bash security/setup.sh`. |
| En Windows "command not found" | Estás en CMD/PowerShell, no en bash. | Usa **WSL2** o **Git Bash**. |
| El escaneo de secretos no encuentra nada en el historial | Tu clon es superficial (`--depth=1`). | Ejecuta `git fetch --unshallow` antes del escaneo de secretos. |

> 🆘 **¿La herramienta encontró un hallazgo que no entiendes?** Cada hallazgo
> incluye un identificador (CWE, ID de regla o alerta). Búscalo en la web o
> revisa los [checklists](../checklists/) para entender el riesgo y cómo
> mitigarlo.

---

## 9. Preguntas frecuentes

**¿Tengo que saber de seguridad para usar esto?**
No. Ejecuta los comandos, lee el `summary.txt` y empieza por los hallazgos
marcados como críticos. Los reportes te dicen qué está mal y, en muchos casos,
cómo arreglarlo.

**¿Esto sube mi código o mis reportes a algún sitio?**
No. Todo corre en **tu** máquina (o en **tu** CI). Los reportes locales se
guardan en `security/templates/reports/`, una carpeta ignorada por git. En
GitHub, los resultados solo van a la pestaña Security de **tu** repositorio.

**¿Rompe mi build si encuentra algo?**
Por defecto **no** (solo avisa). Si quieres que falle ante hallazgos críticos,
añade `--fail-on-findings` en local o `fail-on-findings: true` en los workflows.

**¿Funciona sin GitHub (GitLab, Jenkins, etc.)?**
Sí. Consulta [`sin-github.md`](sin-github.md).

**¿Cómo actualizo el módulo cuando salga una versión nueva?**
```bash
git submodule update --remote --merge security
git add security && git commit -m "chore(security): actualizar módulo"
```

**¿Puedo añadir mis propias reglas de Semgrep?**
Sí. Edita `security/node-web/semgrep.yml` siguiendo el mismo formato, o crea tu
propio archivo y pásalo con `--config`.

---

## Glosario sin tecnicismos

| Término | Qué significa, en cristiano |
|---------|-----------------------------|
| **SAST** | "Análisis estático": leer el código **sin ejecutarlo** para encontrar fallos. |
| **DAST** | "Análisis dinámico": probar la app **mientras corre**, como lo haría un atacante. |
| **SCA** | Revisar las **librerías de terceros** que usas por si tienen fallos conocidos. |
| **IaC** | "Infraestructura como código": tus archivos de configuración (Dockerfile, Compose, Terraform…). |
| **CVE** | Un identificador público de una vulnerabilidad conocida (ej. `CVE-2024-1234`). |
| **CWE** | Una categoría de tipo de fallo (ej. `CWE-79` = XSS). |
| **Secreto** | Una contraseña, token o clave de API. **Nunca** deben estar escritos en el código. |
| **SARIF** | El formato estándar de reporte que GitHub entiende para mostrar alertas. |
| **Trivy** | Herramienta que busca vulnerabilidades en dependencias, imágenes y configuraciones. |
| **Semgrep** | Herramienta que busca patrones peligrosos en tu código fuente. |
| **Gitleaks** | Herramienta que busca secretos filtrados en tu repositorio. |
| **OWASP ZAP** | Herramienta que prueba tu app en marcha buscando vulnerabilidades web. |
| **Checkov** | Herramienta que revisa configuraciones (IaC) contra buenas prácticas. |
| **Docker Bench** | Auditoría de la configuración de Docker según el estándar CIS. |
| **Submódulo** | Un repositorio Git incluido dentro de otro repositorio Git. |

---

## Chuleta de comandos

```bash
# ── Instalación (una sola vez) ────────────────────────────────────────────────
git submodule add https://github.com/nicoendys/securitymodule security
git submodule update --init --recursive

# ── Escaneos locales ──────────────────────────────────────────────────────────
bash security/node-web/audit.sh .                     # código + dependencias (rápido)
bash security/scripts/scan-trivy.sh fs .              # vulnerabilidades del filesystem
bash security/scripts/scan-trivy.sh image mi-app:tag  # vulnerabilidades de una imagen
bash security/scripts/scan-secrets.sh git .           # secretos en el historial git
bash security/scripts/scan-zap-baseline.sh https://staging.tu-app.com   # DAST pasivo
bash security/scripts/docker-bench.sh                 # auditoría de Docker

# ── Todo de una vez (proyecto dockerizado) ────────────────────────────────────
bash security/scripts/scan-full-dockerized.sh --project-root . --url http://localhost:3000

# ── Ayuda y mantenimiento ─────────────────────────────────────────────────────
bash security/scripts/scan-full-dockerized.sh --help  # todas las opciones
bash security/scripts/cleanup-reports.sh --keep-last 7 # borrar reportes viejos

# ── Ver reportes HTML en el navegador ─────────────────────────────────────────
docker compose -f security/docker/docker-compose.yml --profile reports up -d
# Abre http://localhost:8888
```

---

### ¿Y ahora qué?

- Para la guía completa de integración → [`como-usarlo-en-nuevo-proyecto.md`](como-usarlo-en-nuevo-proyecto.md)
- Para proyectos dockerizados en detalle → [`proyecto-dockerizado.md`](proyecto-dockerizado.md)
- Para usar sin GitHub (GitLab, Jenkins…) → [`sin-github.md`](sin-github.md)
- Para revisar la seguridad a mano → [`../checklists/`](../checklists/)
