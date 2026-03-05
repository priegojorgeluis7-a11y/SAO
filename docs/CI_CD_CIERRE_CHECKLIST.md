# SAO - Checklist de habilitacion CI/CD para cierre
**Fecha:** 2026-03-05
**Objetivo:** Completar Fase 1 del plan de cierre con evidencia verificable.

---

## 1) Precondiciones

- [x] Repositorio con workflows activos:
  - [x] `.github/workflows/backend-ci.yml`
  - [x] `.github/workflows/flutter-ci.yml`
- [ ] Rama `main` protegida con checks requeridos (si aplica politica del repo).
- [ ] Permiso para configurar Secrets y Actions en GitHub.

---

## 2) Secrets requeridos (GitHub)

### Backend deploy (Cloud Run)
- [ ] `GCP_PROJECT_ID`
- [ ] `GCP_WORKLOAD_IDENTITY_PROVIDER`
- [ ] `GCP_SERVICE_ACCOUNT`

### Opcionales recomendados
- [ ] `E2E_OPERATIVO_PASSWORD`
- [ ] `E2E_SUPERVISOR_PASSWORD`

---

## 3) Configuracion GCP (WIF)

- [ ] Workload Identity Federation configurada para GitHub Actions.
- [ ] Service Account con permisos minimos para:
  - [ ] Cloud Build
  - [ ] Artifact Registry
  - [ ] Cloud Run Admin
  - [ ] Service Account User
- [ ] Artifact Registry repo `sao` disponible en `us-central1`.

---

## 4) Validacion funcional del pipeline

### 4.1 Backend CI
- [ ] Trigger en PR con cambios en `backend/**`.
- [x] Paso `pytest tests -q` exitoso (evidencia local en este turno).

### 4.2 Deploy automatico
- [ ] Trigger en push a `main` con cambios backend.
- [ ] Build de imagen exitoso.
- [ ] Deploy a Cloud Run exitoso.
- [ ] Smoke test `GET /health` -> HTTP 200.

### 4.3 Flutter CI
- [ ] Trigger en PR/push con cambios en `frontend_flutter/sao_windows/**`.
- [x] `flutter analyze` exitoso (archivo impactado validado en este turno).
- [x] `flutter test` suite completa ejecutada exitosamente en este turno.

---

## 5) Evidencia minima para cierre de Fase 1

- [ ] URL del workflow run exitoso backend.
- [ ] URL del workflow run exitoso flutter.
- [ ] Commit SHA desplegado.
- [ ] Timestamp UTC de ejecucion.
- [ ] Confirmacion de estado de servicio post-deploy (`/health`=200).

Nota de bloqueo externo (2026-03-05):
- Desde este entorno no hay acceso autenticado a GitHub Actions del repo (`gh` no instalado y API REST publica retorna `404`), por lo que no es posible adjuntar URLs/SHA/timestamp de runs de `main` en este momento.
- Estado de Fase 1: tecnicamente preparado y validado localmente; pendiente evidencia remota de ejecucion en `main`.

---

## 6) Actualizacion documental obligatoria

Al completar esta checklist:
- [ ] Actualizar `STATUS.md` (CI/CD automatizado activo = cumplido).
- [ ] Actualizar `docs/AUDIT_REPORT.md` (addendum Fase 1 cerrada).
- [ ] Actualizar `CHANGELOG.md` (entrada de habilitacion CI/CD).
- [ ] Actualizar `docs/PLAN_CIERRE_100_FUNCIONAL.md` (Fase 1 = CERRADA).

---

## Resultado esperado

Fase 1 cerrada cuando exista al menos una corrida automatizada completa y exitosa en `main`, con deploy y smoke test en verde, sin depender de `deploy_to_cloud_run.ps1` como ruta principal.
