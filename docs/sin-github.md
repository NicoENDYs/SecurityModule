# Usar el template sin GitHub

Este template funciona **completamente sin GitHub**. Los scripts locales no dependen de ninguna plataforma de CI/CD. Esta guía cubre tres escenarios:

1. [Solo local (sin CI)](#1-solo-local-sin-ci)
2. [GitLab CI/CD](#2-gitlab-cicd)
3. [Bitbucket Pipelines](#3-bitbucket-pipelines)
4. [Cualquier CI genérico (Jenkins, Drone, Gitea Actions, etc.)](#4-ci-genérico)

---

## 1. Solo local (sin CI)

No necesitas ninguna plataforma. Solo Docker y bash.

### Añadir como submódulo (repositorio Git local o cualquier hosting Git)

```bash
# En cualquier servidor Git (GitLab, Gitea, Bitbucket, Forgejo, servidor propio…)
git submodule add https://gitlab.com/tu-org/security-testing-template security
# o con SSH:
git submodule add git@gitlab.com:tu-org/security-testing-template security
git submodule update --init --recursive
```

### Flujo de trabajo diario sin CI

```bash
# Desde la raíz de tu proyecto:

# 1. Escaneo completo de un proyecto dockerizado
bash security/scripts/scan-full-dockerized.sh \
  --project-root . \
  --url http://localhost:3000 \
  --fail-on-findings

# 2. O pasos individuales
bash security/scripts/scan-trivy.sh fs .
bash security/scripts/scan-trivy.sh image mi-app:latest
bash security/scripts/scan-zap-baseline.sh http://localhost:3000
bash security/scripts/docker-bench.sh
bash security/node-web/audit.sh .
```

### Hook de pre-push (opcional)

Ejecuta el escaneo SAST antes de cada `git push`:

```bash
# .git/hooks/pre-push  (en tu proyecto, no en el submódulo)
#!/usr/bin/env bash
set -euo pipefail
echo "[security] Running SAST checks before push…"
bash security/node-web/audit.sh . || {
  echo "[security] SAST found issues. Fix them or use --no-verify to skip."
  exit 1
}
```

```bash
chmod +x .git/hooks/pre-push
```

---

## 2. GitLab CI/CD

Crea `.gitlab-ci.yml` en la raíz de **tu proyecto**. Los jobs replican lo que hacen los GitHub Actions incluidos en este template.

```yaml
# .gitlab-ci.yml

stages:
  - sast
  - build
  - scan-image
  - dast

variables:
  DOCKER_DRIVER: overlay2
  DOCKER_TLS_CERTDIR: ""
  STAGING_URL: "https://staging.example.com"   # ajusta o pasa como variable CI/CD
  TRIVY_VERSION: "0.61.0"

# ── SAST: npm audit + Semgrep ──────────────────────────────────────────────────
sast:
  stage: sast
  image: docker:27
  services:
    - docker:27-dind
  before_script:
    - git submodule update --init --recursive
  script:
    - bash security/node-web/audit.sh .
  artifacts:
    when: always
    paths:
      - security/templates/reports/npm-audit_*.json
      - security/templates/reports/semgrep_*.json
    expire_in: 7 days
  allow_failure: true   # cambia a false para bloquear en fallos

# ── Build Docker image ────────────────────────────────────────────────────────
build:
  stage: build
  image: docker:27
  services:
    - docker:27-dind
  script:
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA .
    - docker save $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA > image.tar
  artifacts:
    paths:
      - image.tar
    expire_in: 1 hour

# ── Trivy: escaneo de la imagen ────────────────────────────────────────────────
trivy-image:
  stage: scan-image
  image: aquasec/trivy:${TRIVY_VERSION}
  needs: [build]
  script:
    - trivy image
        --exit-code 0
        --severity HIGH,CRITICAL
        --format json
        --output trivy-report.json
        --input image.tar
    - trivy image
        --exit-code 0
        --severity HIGH,CRITICAL
        --format table
        --input image.tar
  artifacts:
    when: always
    reports:
      # GitLab Security Dashboard: usa el formato nativo de Trivy
      container_scanning: trivy-report.json
    paths:
      - trivy-report.json
    expire_in: 7 days
  allow_failure: true

# ── Trivy: filesystem + secrets + IaC ─────────────────────────────────────────
trivy-fs:
  stage: scan-image
  image: aquasec/trivy:${TRIVY_VERSION}
  before_script:
    - git submodule update --init --recursive
  script:
    - trivy fs
        --exit-code 0
        --severity HIGH,CRITICAL
        --scanners vuln,secret,misconfig
        --format json
        --output trivy-fs-report.json
        .
    - trivy fs
        --exit-code 0
        --severity HIGH,CRITICAL
        --scanners vuln,secret,misconfig
        --format table
        .
  artifacts:
    when: always
    paths:
      - trivy-fs-report.json
    expire_in: 7 days
  allow_failure: true

# ── ZAP DAST baseline ─────────────────────────────────────────────────────────
zap-baseline:
  stage: dast
  image: ghcr.io/zaproxy/zaproxy:stable
  variables:
    GIT_STRATEGY: none   # no clona, solo usa la imagen ZAP
  before_script:
    - mkdir -p /zap/wrk
  script:
    - zap-baseline.py
        -t "$STAGING_URL"
        -r zap-report.html
        -J zap-report.json
        -I
  after_script:
    - cp /zap/wrk/zap-report.html . 2>/dev/null || true
    - cp /zap/wrk/zap-report.json . 2>/dev/null || true
  artifacts:
    when: always
    paths:
      - zap-report.html
      - zap-report.json
    expire_in: 7 days
    expose_as: "ZAP DAST Report"
  allow_failure: true
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'   # Solo en main, no en cada MR
    - if: '$CI_PIPELINE_SOURCE == "schedule"'
```

> **GitLab Security Dashboard:** Los jobs `trivy-image` y `trivy-fs` usan `reports: container_scanning` que alimenta el [GitLab Security Dashboard](https://docs.gitlab.com/ee/user/application_security/container_scanning/) directamente (disponible en GitLab Ultimate/Gold).

### Variables de CI/CD de GitLab

Define en tu proyecto GitLab (Settings → CI/CD → Variables):

| Variable | Ejemplo | Descripción |
|----------|---------|-------------|
| `STAGING_URL` | `https://staging.example.com` | URL del entorno de staging |
| `CI_REGISTRY_IMAGE` | `registry.gitlab.com/org/app` | Registry de contenedores |

---

## 3. Bitbucket Pipelines

Crea `bitbucket-pipelines.yml` en la raíz de tu proyecto:

```yaml
# bitbucket-pipelines.yml

image: docker:27

definitions:
  services:
    docker:
      memory: 4096

pipelines:
  default:   # se ejecuta en todos los branches
    - step:
        name: SAST — npm audit + Semgrep
        services: [docker]
        script:
          - git submodule update --init --recursive
          - bash security/node-web/audit.sh .
        artifacts:
          - security/templates/reports/**

    - step:
        name: Build Docker Image
        services: [docker]
        script:
          - docker build -t app:${BITBUCKET_COMMIT:0:7} .
          - docker save app:${BITBUCKET_COMMIT:0:7} > image.tar
        artifacts:
          - image.tar

    - step:
        name: Trivy — Image Scan
        image: aquasec/trivy:0.61.0
        script:
          - trivy image
              --exit-code 0
              --severity HIGH,CRITICAL
              --format json
              --output trivy-report.json
              --input image.tar
          - trivy image --severity HIGH,CRITICAL --format table --input image.tar
        artifacts:
          - trivy-report.json

  branches:
    main:   # solo en main se lanza DAST
      - step:
          name: ZAP DAST Baseline
          image: ghcr.io/zaproxy/zaproxy:stable
          script:
            - zap-baseline.py
                -t "${STAGING_URL}"
                -r zap-report.html
                -J zap-report.json
                -I || true
          artifacts:
            - zap-report.html
            - zap-report.json
```

> Define `STAGING_URL` en Repository Settings → Repository variables.

---

## 4. CI genérico

Cualquier CI que pueda ejecutar shell scripts y tenga Docker disponible puede usar los scripts locales directamente.

### Patrón universal

```bash
#!/usr/bin/env bash
# ci-security.sh — Invocar desde cualquier CI runner con Docker
set -euo pipefail

# Asegura que el submódulo esté inicializado
git submodule update --init --recursive

# Escaneo SAST
bash security/node-web/audit.sh .

# Escaneo de imagen (ajusta el tag a tu pipeline)
IMAGE="${IMAGE_NAME:-mi-app}:${GIT_COMMIT:-latest}"
docker build -t "$IMAGE" .
bash security/scripts/scan-trivy.sh image "$IMAGE"

# DAST (solo si STAGING_URL está definida)
if [[ -n "${STAGING_URL:-}" ]]; then
  bash security/scripts/scan-zap-baseline.sh "$STAGING_URL"
fi

# Código de salida: 0 si no hay fallos críticos
CRITICAL=$(grep -r '"Severity": "CRITICAL"' security/templates/reports/ | wc -l || echo 0)
echo "Critical findings: $CRITICAL"
[[ "$CRITICAL" -eq 0 ]] || exit 1
```

### Jenkins (Declarative Pipeline)

```groovy
// Jenkinsfile
pipeline {
  agent { label 'docker' }

  stages {
    stage('Checkout + Submodule') {
      steps {
        checkout scm
        sh 'git submodule update --init --recursive'
      }
    }

    stage('SAST') {
      steps {
        sh 'bash security/node-web/audit.sh .'
      }
      post {
        always {
          archiveArtifacts artifacts: 'security/templates/reports/*.json', allowEmptyArchive: true
        }
      }
    }

    stage('Build') {
      steps {
        sh "docker build -t app:${env.GIT_COMMIT[0..7]} ."
      }
    }

    stage('Trivy Image') {
      steps {
        sh "bash security/scripts/scan-trivy.sh image app:${env.GIT_COMMIT[0..7]}"
      }
      post {
        always {
          archiveArtifacts artifacts: 'security/templates/reports/trivy-image*.json', allowEmptyArchive: true
        }
      }
    }

    stage('ZAP DAST') {
      when { branch 'main' }
      steps {
        sh "bash security/scripts/scan-zap-baseline.sh ${env.STAGING_URL}"
      }
      post {
        always {
          publishHTML([
            reportDir: 'security/templates/reports',
            reportFiles: 'zap-baseline*.html',
            reportName: 'ZAP DAST Report',
            keepAll: true
          ])
        }
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: 'security/templates/reports/**', allowEmptyArchive: true
    }
  }
}
```

---

## Resumen: qué funciona sin GitHub

| Funcionalidad | Sin GitHub | Con GitHub |
|---------------|-----------|------------|
| `scan-trivy.sh` (local) | ✅ | ✅ |
| `scan-zap-baseline.sh` (local) | ✅ | ✅ |
| `scan-full-dockerized.sh` (orquestador) | ✅ | ✅ |
| `node-web/audit.sh` (npm + Semgrep) | ✅ | ✅ |
| `docker-bench.sh` | ✅ | ✅ |
| Checklists (WSTG, API, Docker) | ✅ | ✅ |
| GitHub Actions (`trivy.yml`, `zap-baseline.yml`) | ❌ | ✅ |
| SARIF → GitHub Security tab | ❌ | ✅ |
| ZAP → GitHub Issues automáticos | ❌ | ✅ |
| GitLab Security Dashboard | ✅ (con `.gitlab-ci.yml`) | ❌ |

---

## Clonar sin submódulos (caso de entorno restringido)

Si no puedes usar `git submodule` (entornos air-gapped, políticas corporativas), copia el contenido directamente:

```bash
# Descarga como ZIP sin necesidad de submódulos
curl -L https://github.com/nicoendys/securitymodule/archive/refs/heads/main.zip \
  -o security-template.zip
unzip security-template.zip -d security/
rm security-template.zip
```

En este caso **no recibirás actualizaciones automáticas** — tendrás que repetir el proceso manualmente.
