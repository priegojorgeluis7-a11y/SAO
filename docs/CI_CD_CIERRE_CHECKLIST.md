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

Evidencia remota verificada (2026-03-05):
- Repositorio: `priegojorgeluis7-a11y/SAO`
- Branch: `main`
- Commit evaluado por CI: `b7f49a1d43ef140630e014a0cffefb4b1eb1069e`
- Backend CI run: `https://github.com/priegojorgeluis7-a11y/SAO/actions/runs/22736601995`
  - Job `test`: `failure`
  - Job `Deploy to Cloud Run`: `skipped` (bloqueado por fallo previo)
- Flutter CI run: `https://github.com/priegojorgeluis7-a11y/SAO/actions/runs/22736601947`
  - Job `analyze-and-test`: `failure`

Conclusión Fase 1 al corte:
- Bloqueo de acceso a Actions: RESUELTO.
- Bloqueo actual: TECNICO (workflows en `failure`), pendiente corregir errores de pipeline para marcar Fase 1 como cerrada.

Actualización posterior (2026-03-05, commit `b4bc8f14d8b65362184d94016233ce448973e92a`):
- Flutter CI run: `https://github.com/priegojorgeluis7-a11y/SAO/actions/runs/22737110957` -> `success`.
- Backend CI run: `https://github.com/priegojorgeluis7-a11y/SAO/actions/runs/22737110964` -> `failure`.
  - Job `test`: `success`.
  - Job `Deploy to Cloud Run`: `failure`.
  - Causa exacta en step `Authenticate to Google Cloud`:
    `google-github-actions/auth failed with: the GitHub Action workflow must specify exactly one of workload_identity_provider or credentials_json`.

Estado actual Fase 1 (2026-03-09):
- Validación de tests CI: OK (backend + flutter).
- Workflow actualizado para soportar dos métodos de auth:
  - Opción A (recomendada): Workload Identity Federation — secrets `GCP_WORKLOAD_IDENTITY_PROVIDER` + `GCP_SERVICE_ACCOUNT` + `GCP_PROJECT_ID`
  - Opción B: Service Account Key JSON — secret `GCP_SA_KEY`
- Bloqueo remanente: configurar en GitHub -> Settings -> Secrets -> Actions UNO de los dos métodos de auth del repositorio.
  - Para desbloqueo inmediato (Opción A):
    - `GCP_WORKLOAD_IDENTITY_PROVIDER` = URI del pool WIF en GCP.
    - `GCP_SERVICE_ACCOUNT` = `sao-ci@sao-prod-488416.iam.gserviceaccount.com`.
    - `GCP_PROJECT_ID` = `sao-prod-488416`.
- Workflow falla con mensaje diagnóstico claro si ningún secret está configurado.

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
