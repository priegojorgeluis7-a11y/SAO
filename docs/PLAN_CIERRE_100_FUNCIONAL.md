# SAO - Plan de Cierre al 100% Funcional-Operativo
**Version:** 1.0
**Fecha:** 2026-03-05
**Objetivo:** Cerrar los pendientes criticos para declarar el sistema 100% funcional, operable y auditable.

## Estado de ejecucion del plan

**Inicio formal:** 2026-03-05
**Estado global:** EN CURSO

### Avance por fase

| Fase | Estado | Inicio | Cierre | Observaciones |
|---|---|---|---|---|
| Fase 0 - Freeze y baseline | COMPLETADA | 2026-03-05 | 2026-03-05 | Baseline tecnico confirmado con evidencia de pruebas y E2E staging. |
| Fase 1 - CI/CD end-to-end | EN CURSO (BLOQUEO TECNICO EN PIPELINE) | 2026-03-05 | - | Evidencia remota en `main` ya capturada: Backend CI (`22736601995`) y Flutter CI (`22736601947`) sobre `b7f49a1`; ambos en `failure`, por lo que falta estabilizar workflows para cierre. |
| Fase 2 - Cobertura desktop no-auth | EN CURSO | 2026-03-05 | - | Cobertura ampliada en `catalog` y `reports` (+20 tests acumulados), bug de exportacion cross-platform corregido, suite desktop en verde. |
| Fase 3 - Estabilizacion mobile suite | COMPLETADA | 2026-03-05 | 2026-03-05 | `flutter test` global mobile en verde (`All tests passed`, 223 tests). |
| Fase 4 - Consolidacion documental | PENDIENTE | - | - | Se ejecuta al cerrar Fases 1-3. |
| Fase 5 - Go/No-Go final | PENDIENTE | - | - | Requiere checklist DoD completo. |

### Baseline de evidencia (arranque y actualizacion)

- Backend: `pytest tests -q` en verde (exit code 0).
- Desktop: `flutter test` en verde (exit code 0).
- Mobile: `flutter test` global en verde (exit code 0) en corrida de cierre posterior.
- Staging E2E real: `backend/scripts/e2e_staging_flow.py` exitoso con `execution_state=COMPLETADA`.

### Siguientes acciones inmediatas

1. Ejecutar checklist de habilitacion CI/CD (secrets + permisos + primer run en `main`).
  Documento operativo: `docs/CI_CD_CIERRE_CHECKLIST.md`.
2. Corregir fallos de `Backend CI` y `Flutter CI` en `main` y registrar primera corrida totalmente exitosa (URL run + SHA + timestamp).
3. Completar cobertura desktop no-auth restante y registrar delta por modulo (catalog/review/reports).
4. Revisar diagnostico de cumplimiento contra flujo objetivo:
  `docs/DIAGNOSTICO_FLUJO_100_FUNCIONAL_2026-03-05.md`.
5. Ejecutar plan de fixes auditables por severidad:
  `docs/PLAN_FIX_HALLAZGOS_SEVERIDAD_2026-03-05.md`.

---

## Estado de partida

Ya cerrado:
- E2E real en staging ejecutado y documentado.
- Backend integration tests en verde para review/observations.
- Desktop tests en verde en corrida reportada.

Pendientes para 100%:
- CI/CD automatizado activo (sin ruta principal manual).
- Cobertura desktop ampliada en modulos no-auth (`catalog`, `review`, `reports`).
- Consolidacion documental final (`STATUS.md`, `AUDIT_REPORT.md`, `CHANGELOG.md`) y decision Go/No-Go.

---

## Fases de cierre

## Fase 0 - Freeze y baseline (Dia 0)
**Objetivo:** Congelar alcance y fijar linea base de evidencia.

**Tareas:**
- Definir branch de cierre y owners por frente (Backend, Mobile, Desktop, DevOps).
- Capturar baseline de estado en `STATUS.md`.
- Congelar nuevas features no relacionadas al cierre.

**Entregables:**
- Lista unica de pendientes aprobada.
- Matriz owner -> tarea -> fecha.

**Criterio de salida:**
- Alcance de cierre firmado por responsables.

---

## Fase 1 - CI/CD end-to-end (Dia 1)
**Objetivo:** Dejar deploy automatizado con gates de calidad.

**Tareas:**
- Activar workflow de backend: `test -> build -> deploy -> smoke`.
- Activar workflow flutter: `analyze + tests` (mobile/desktop segun alcance).
- Configurar secretos CI de GCP y permisos de despliegue.
- Eliminar dependencia operativa de `deploy_to_cloud_run.ps1` como ruta principal.

**Entregables:**
- Pipeline en `main` ejecutando automaticamente.
- Evidencia de 1 corrida exitosa de deploy.

**Criterio de salida:**
- Run exitoso con:
  - tests backend en verde,
  - deploy Cloud Run exitoso,
  - smoke `/health` HTTP 200.

**Evidencia minima:**
- URL/ID del workflow run.
- Timestamp y commit SHA desplegado.

---

## Fase 2 - Cobertura desktop no-auth (Dia 2)
**Objetivo:** Aumentar confianza en `catalog`, `review`, `reports`.

**Baseline medido (2026-03-05, `flutter test --coverage`):**
- `catalog`: 6.37% (161/2526 lineas)
- `review`: 74.42% (32/43 lineas)
- `reports`: 10.48% (68/649 lineas)

**Delta medido en este turno:**
- `catalog`: 6.37% -> 10.57% (161/2526 -> 267/2526).
- `reports`: 10.48% -> 36.52% (68/649 -> 237/649).
- `review`: se mantiene en 74.42%.
- Tests nuevos acumulados en este frente: `status_catalog_test` (+6), `roles_catalog_test` (+5), `catalog_bundle_models_test` (+3), `report_entities_test` (+4), `report_context_test` (+2), `report_export_service_test` (+1), `reports_provider_test` (+2).
- Fix funcional en exportacion cross-platform de evidencias (`path.basename`) validado por tests.

**Tareas:**
- Agregar tests unitarios faltantes por modulo.
- Definir meta de cobertura por modulo (baseline + delta).
- Ejecutar suite y generar evidencia de mejora.

**Entregables:**
- Nuevos tests en modulos objetivo.
- Registro de cobertura antes/despues en docs.

**Criterio de salida:**
- `flutter test` desktop en verde.
- Incremento medible de cobertura en los 3 modulos.

**Evidencia minima:**
- Conteo de tests agregados por modulo.
- Reporte baseline vs cierre.

---

## Fase 3 - Estabilizacion mobile test suite (Dia 2-3)
**Objetivo:** Resolver fallo de `flutter test` global en mobile.

**Tareas:**
- Identificar suite(s) fallando y causa raiz.
- Corregir codigo o fixtures inestables.
- Repetir corrida completa hasta obtener estabilidad.

**Entregables:**
- Lista de fallas corregidas.
- Corrida completa en verde.

**Criterio de salida:**
- `Set-Location d:/SAO/frontend_flutter/sao_windows; flutter test` -> exit code 0.

**Evidencia minima:**
- Salida resumida de corrida final en verde.
- Relacion test-fix aplicada.

---

## Fase 4 - Consolidacion documental y auditoria (Dia 3)
**Objetivo:** Cerrar trazabilidad y estatus final de release.

**Tareas:**
- Actualizar `STATUS.md` marcando checklist final en `[x]`.
- Actualizar `docs/AUDIT_REPORT.md` con addendum de cierre total.
- Actualizar `CHANGELOG.md` con cierre de release.

**Entregables:**
- Estado final consistente en todos los documentos de control.

**Criterio de salida:**
- No quedan pendientes operativos abiertos en docs de control.

---

## Fase 5 - Go/No-Go final (Dia 3)
**Objetivo:** Autorizar cierre con evidencia completa.

**Tareas:**
- Validacion final de criterios 100%.
- Decision Go/No-Go con responsables tecnicos.

**Entregables:**
- Acta breve de aprobacion final.

**Criterio de salida:**
- Go aprobado y publicado en `STATUS.md`.

---

## Checklist de cierre (Definition of Done)

- [ ] CI/CD automatizado activo y probado en `main`.
- [ ] Pipeline ejecutado al menos 1 vez con resultado exitoso completo.
- [ ] Cobertura desktop ampliada y validada en `catalog`, `review`, `reports`.
- [x] `flutter test` desktop en verde tras cambios de cobertura.
- [x] `flutter test` mobile global en verde.
- [ ] E2E staging real documentado (ya cumplido).
- [ ] `STATUS.md` actualizado con todos los criterios en `[x]`.
- [ ] `docs/AUDIT_REPORT.md` actualizado con cierre total.
- [ ] `CHANGELOG.md` actualizado con evidencia de cierre.

---

## Riesgos y mitigacion

1. Riesgo: Falla por secretos/permisos GCP en CI.
Mitigacion: Validar auth federada y secrets antes del primer merge de cierre.

2. Riesgo: Regresiones por ampliar cobertura desktop.
Mitigacion: Cambios atomicos por modulo y smoke manual de pantallas clave.

3. Riesgo: Inestabilidad intermitente en tests mobile.
Mitigacion: Aislar flaky tests, corregir fixtures y repetir corrida completa.

---

## Secuencia recomendada de ejecucion

1. Fase 0
2. Fase 1
3. Fase 2 y Fase 3 en paralelo (si hay capacidad)
4. Fase 4
5. Fase 5

Con esta secuencia se minimiza retrabajo y se cierra primero el riesgo operativo mayor (CI/CD), luego calidad (cobertura + estabilidad), y finalmente auditoria formal.
