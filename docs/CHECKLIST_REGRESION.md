# SAO — Checklist de Regresión Manual
**Versión:** 1.0
**Fecha:** 2026-03-04
**Aplica a:** Stack local (localhost:8000 + SQLite + local storage)

Ejecutar este checklist antes de cada release o merge a `main`.
Marcar ✅ cuando pasa, ❌ cuando falla (anotar el error), ⚠️ cuando hay comportamiento inesperado.

---

## Prerrequisitos

```powershell
# Arrancar backend local
cd backend
.\scripts\start_local.ps1        # arranca uvicorn + migrations + seeds

# Verificar backend activo
curl http://localhost:8000/api/v1/health
# → {"status": "ok"}

# Ejecutar suite automática
pytest tests/ -q
# → XX/XX passed

# Ejecutar E2E automatizado
python scripts/e2e_local.py
# → ✅ E2E LOCAL PASSED
```

---

## A. Autenticación

| # | Escenario | Resultado esperado | ✅/❌ |
|---|---|---|---|
| A1 | Login con `admin@sao.mx` / `admin123` | 200 + `access_token` | |
| A2 | Login con contraseña incorrecta | 401 `INVALID_CREDENTIALS` | |
| A3 | Acceder endpoint protegido sin token | 401 `NOT_AUTHENTICATED` | |
| A4 | Acceder con token expirado | 401 `TOKEN_EXPIRED` | |
| A5 | Refresh token válido devuelve nuevo access_token | 200 + nuevo token | |

**Desktop app:**
| # | Escenario | Resultado esperado | ✅/❌ |
|---|---|---|---|
| A6 | Abrir desktop → pantalla de login | Formulario visible, sin error previo | |
| A7 | Login con credenciales locales | Navega a pantalla Operaciones | |
| A8 | Logout → redirige a login | Sesión limpiada | |

---

## B. Actividades (Backend API)

| # | Escenario | Resultado esperado | ✅/❌ |
|---|---|---|---|
| B1 | `POST /activities` crea actividad nueva | 201 + ActivityDTO con `sync_version=0` | |
| B2 | `POST /activities` con UUID existente (idempotente) | 200 + ActivityDTO existente | |
| B3 | `GET /activities/{uuid}` | 200 + ActivityDTO | |
| B4 | `GET /activities/{uuid}` inexistente | 404 | |
| B5 | `PUT /activities/{uuid}` actualiza campos | 200 + `sync_version` incrementado | |
| B6 | `DELETE /activities/{uuid}` soft-delete | 200 + `deleted_at` seteado | |
| B7 | `PATCH /activities/{uuid}/flags` → `gps_mismatch=true` | 200 + `flags.gps_mismatch=true` | |
| B8 | `PATCH /activities/{uuid}/flags` → `catalog_changed=false` | 200 + `flags.catalog_changed=false` | |
| B9 | `GET /activities/{uuid}/timeline` | 200 + lista de entradas de auditoría | |

---

## C. Sync Push/Pull

| # | Escenario | Resultado esperado | ✅/❌ |
|---|---|---|---|
| C1 | `POST /sync/push` con actividad nueva | `results[0].status = CREATED` | |
| C2 | `POST /sync/push` con actividad ya existente | `results[0].status = UPDATED` o `UNCHANGED` | |
| C3 | `POST /sync/pull since_version=0` | 200 + todas las actividades del proyecto | |
| C4 | `POST /sync/pull since_version=N` | Solo actividades con `sync_version > N` | |
| C5 | `POST /sync/pull` después de approve | Actividad aparece con `execution_state=COMPLETADA` | |

---

## D. Evidencias (modo local)

| # | Escenario | Resultado esperado | ✅/❌ |
|---|---|---|---|
| D1 | `POST /evidences/upload-init` | 200 + `upload_url` apunta a `http://localhost:8000/local-upload/...` | |
| D2 | `PUT /local-upload/{evidence_id}` con bytes JPEG | 200 `{"ok": true}` | |
| D3 | `GET /uploads/{path}` después de upload | 200 + bytes del archivo | |
| D4 | `POST /evidences/upload-init` con mime inválido (`text/plain`) | 422 error de validación | |
| D5 | `POST /evidences/upload-init` con `file_size_bytes > 20MB` | 422 error de validación | |

---

## E. Cola de Revisión

| # | Escenario | Resultado esperado | ✅/❌ |
|---|---|---|---|
| E1 | `GET /review/queue?project_id=TMQ` | 200 + lista de actividades `REVISION_PENDIENTE` | |
| E2 | Actividad con `gps_mismatch=true` aparece en cola | Flag visible en item de cola | |
| E3 | `POST /review/activity/{uuid}/decision` APPROVE | 200 `{"ok": true}`, actividad → `COMPLETADA` | |
| E4 | `POST /review/activity/{uuid}/decision` REJECT | 200 `{"ok": true}`, actividad → `REVISION_PENDIENTE` con comentarios | |
| E5 | Aprobar actividad inexistente | 404 | |

---

## F. Eventos

| # | Escenario | Resultado esperado | ✅/❌ |
|---|---|---|---|
| F1 | `POST /events` crea evento nuevo | 201 + EventDTO | |
| F2 | `POST /events` con UUID duplicado (idempotente) | 200 + EventDTO existente | |
| F3 | `GET /events?project_id=TMQ` | 200 + lista paginada | |
| F4 | `PATCH /events/{uuid}` → `resolved_at = now()` | 200 + `resolved_at` seteado | |
| F5 | `GET /events?severity=HIGH` | Solo eventos HIGH | |

---

## G. Catálogo (Backend)

| # | Escenario | Resultado esperado | ✅/❌ |
|---|---|---|---|
| G1 | `GET /catalog/bundle?project_id=TMQ` | 200 + JSON con `schema`, `editor`, `effective` | |
| G2 | `GET /catalog/effective?project_id=TMQ` | 200 + JSON con tipos de actividad activos | |
| G3 | `GET /catalog/version/current?project_id=TMQ` | 200 + `version_id` válido | |
| G4 | `POST /catalog/editor/activities` crea actividad de catálogo | 201 + item creado | |
| G5 | `POST /catalog/validate?project_id=TMQ` | 200 + resultado de validación | |
| G6 | `POST /catalog/publish?project_id=TMQ` | 200 + versión nueva publicada | |

---

## H. App Móvil (Flutter — ejecutar con `flutter run`)

**Configuración:** `--dart-define=SAO_API_BASE=http://localhost:8000/api/v1`

| # | Escenario | Resultado esperado | ✅/❌ |
|---|---|---|---|
| H1 | Arrancar app → pantalla de login | Sin crash, UI correcta | |
| H2 | Login → navega a Inicio | 5 ítems BottomNav visibles | |
| H3 | Inicio → lista de actividades del proyecto | Actividades cargadas desde SQLite local | |
| H4 | Pestaña "Eventos" → lista vacía inicial | Empty state con botón Reportar | |
| H5 | FAB "Reportar" → abre modal 3 pasos | Modal completo, selección de tipo y severidad | |
| H6 | Completar reporte → evento guardado localmente | Evento aparece en lista con badge `LOCAL_PENDING` | |
| H7 | Pestaña "Sincronizar" → push pendientes | SyncIndicator muestra progreso | |
| H8 | Después de sync → evento muestra badge `SYNCED` | Badge cambia de amarillo a verde | |
| H9 | Wizard nueva actividad → seleccionar tipo catálogo | Dropdown poblado con tipos del servidor | |
| H10 | Guardar actividad en wizard → aparece en lista | Actividad con estado `PENDIENTE` | |

---

## I. Desktop Admin (Flutter — ejecutar con `flutter run`)

**Configuración:** `--dart-define=SAO_BACKEND_URL=http://localhost:8000`

| # | Escenario | Resultado esperado | ✅/❌ |
|---|---|---|---|
| I1 | Arrancar desktop → pantalla de login | Sin crash, colores del tema correctos (no `Colors.red.shade*` raw) | |
| I2 | Login → navega a Operaciones | NavigationRail con 7 ítems visibles | |
| I3 | Sección Operaciones → cola de revisión cargada | Actividades REVISION_PENDIENTE visibles | |
| I4 | Seleccionar actividad → panel detalles con 3 tabs | Detalles, Historial, Validación Técnica | |
| I5 | Botón APROBAR (Enter) → actividad desaparece de cola | SnackBar confirmación, cola actualizada | |
| I6 | Botón RECHAZAR → dialog de razón | Dialog con playbook de razones, comentario opcional | |
| I7 | Sección Catálogos → 7 tabs de entidades | Actividades, Subcategorías, etc. | |
| I8 | Crear actividad de catálogo → dialog abre y guarda | Item nuevo aparece en tabla | |
| I9 | Publicar catálogo → confirmación + versión incrementada | SnackBar éxito | |
| I10 | Sección Eventos → lista de eventos del proyecto | Tabla con columnas Tipo/Severidad/Estado | |
| I11 | Marcar evento como "Resolver" → estado cambia a Resuelto | Chip verde "Resuelto" visible | |
| I12 | Sección Usuarios → lista de usuarios | DataTable con roles y estados | |
| I13 | Filtrar por rol "OPERATIVO" → solo operativos | Otros roles filtrados | |
| I14 | Sección Reportes | Página carga sin crash | |
| I15 | F5 → refresca vista activa | Datos recargados | |

---

## J. Pruebas de Regresión de Tests Automáticos

| # | Escenario | Resultado esperado | ✅/❌ |
|---|---|---|---|
| J1 | `pytest backend/tests/ -q` | 98+/98+ passing, 0 failing | |
| J2 | `flutter test desktop_flutter/sao_desktop/test/` | 58+/59 passing (widget_test.dart pre-existente excluido) | |
| J3 | `python scripts/e2e_local.py` (con backend corriendo) | `✅ E2E LOCAL PASSED` | |

---

## K. Verificaciones de Calidad de Código

| # | Escenario | Resultado esperado | ✅/❌ |
|---|---|---|---|
| K1 | `grep -r "Colors\.red\b" desktop_flutter/sao_desktop/lib/features/` | 0 resultados | |
| K2 | `grep -r "Color(0xFF" desktop_flutter/sao_desktop/lib/features/` | 0 resultados | |
| K3 | `grep "hardcode\|TODO\|FIXME" backend/app/api/` | Sin TODOs críticos bloqueantes | |
| K4 | `grep "localhost" backend/app/` (en código no en configs) | 0 resultados en lógica de negocio | |

---

## Firma del Checklist

| Campo | Valor |
|---|---|
| Fecha de ejecución | |
| Ejecutado por | |
| Versión de código (`git log --oneline -1`) | |
| Resultado final | ✅ PASS / ❌ FAIL |
| Notas / Bloqueadores | |

---

## Historial de Ejecuciones

| Fecha | Responsable | Versión | Resultado | Notas |
|---|---|---|---|---|
| 2026-03-04 | (pendiente ejecución manual) | 0.2.2 | — | Primera versión del checklist |
