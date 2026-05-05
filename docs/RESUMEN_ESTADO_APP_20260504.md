# Resumen Estado de la App — SAO en Producción
**Fecha:** 4 de mayo de 2026  
**Fuente:** Consulta directa a Firestore (`sao-prod-488416`)  
**Backend:** Cloud Run — `https://sao-api-fjzra25vya-uc.a.run.app`  
**Nota:** Este resumen excluye actividades con estado `CANCELED` y actividades eliminadas (soft delete).

---

## Proyectos Activos (7 proyectos)

| ID | Proyecto | Estado |
|----|----------|--------|
| **TAP** | Tren AIFA-Pachuca | `active` |
| **TMQ** | Tren México-Querétaro | `active` |
| **TQI** | Tren Querétaro-Irapuato | `active` |
| **TQSL** | Tren Querétaro-San Luis Potosí | `active` |
| **TSLS** | Tren San Luis Potosí-Saltillo | `active` |
| **TSNL** | Tren Saltillo-Nuevo Laredo | `active` |
| PROJECT_0 | Catálogo Base | sistema |

> TQSL y TSLS están activos pero **sin actividades registradas** aún.

---

## Actividades por Proyecto (33 activas en Firestore)

> No se incluyen actividades canceladas ni eliminadas (soft delete).

| Proyecto | Total activas | PENDIENTE | COMPLETADA |
|----------|:-------------:|:---------:|:----------:|
| **TSNL** | 23 | 12 | 11 |
| **TAP** | 5 | 5 | 0 |
| **TMQ** | 3 | 1 | 2 |
| **TQI** | 2 | 2 | 0 |
| **TQSL** | 0 | — | — |
| **TSLS** | 0 | — | — |
| **TOTAL** | **33** | **20** | **13** |

---

## Actividad Reciente

| Periodo | Actividades activas creadas | Proyectos con actividad |
|---------|:---------------------------:|------------------------|
| Últimos 7 días | **28** | TSNL (21), TAP (4), TQI (2), TMQ (1) |
| Últimos 30 días | **33** | TSNL (23), TAP (5), TMQ (3), TQI (2) |

> El 100% de las 33 actividades activas se crearon en los últimos 30 días — la app lleva menos de un mes en uso de campo real.

### Actividades más recientes (últimos 7 días)

| Proyecto | Actividad | Estado | Fecha |
|----------|-----------|--------|-------|
| TSNL | Caminamiento para marcaje de afectación de propiedad social… | PENDIENTE | 2026-05-07 |
| TSNL | Marcaje parcelas 50 y 58 | PENDIENTE | 2026-05-06 |
| TSNL | Planeacion de Acercamiento | PENDIENTE | 2026-05-05 |
| TSNL | Acercamiento Transparque Interpuerto | PENDIENTE | 2026-05-05 |
| TSNL | Acompañamiento SEDATU | PENDIENTE | 2026-05-04 |
| TSNL | Solicitud de Anuencia para Acceso al predio | PENDIENTE | 2026-05-04 |
| TAP | huitzila Caminamiento y reunión con cruces | PENDIENTE | 2026-05-04 |
| TQI | Avaluo Predios Estacion de Irapuato | PENDIENTE | 2026-05-04 |
| TSNL | Capacitación compañero segmentos 18 al 20 | PENDIENTE | 2026-05-04 |

---

## Usuarios

| Métrica | Valor |
|---------|:-----:|
| Usuarios registrados en total | **35** |
| Asignados a TMQ | 8 |
| Asignados a TQI | 8 |
| Asignados a TAP | 7 |
| Asignados a TSNL | 7 |
| Asignados a TQSL | 1 |
| Asignados a TSLS | 1 |

---

## Evidencias y Revisiones

| Métrica | Valor |
|---------|:-----:|
| Evidencias subidas | **56** |
| — TMQ | 42 |
| — TSNL | 13 |
| — TAP | 1 |
| Observaciones registradas | **22** |
| Decisiones de revisión totales | **54** |
| — APPROVE | 32 |
| — REJECT | 22 |

---

## Observaciones Clave

1. **Flujo de revisión activo:** 54 decisiones registradas (APPROVE/REJECT), aunque el campo `review_status` en los documentos de actividad aparece `null` — las decisiones se almacenan en la colección `review_decisions` separada (comportamiento correcto del sistema).

2. **TSNL es el proyecto más activo esta semana:** 20+ actividades en los últimos 7 días, incluyendo caminamientos, reuniones con autoridades y acciones de avalúo.

3. **TMQ acumula la mayor cantidad histórica** (40 actividades, 36 eliminadas — posiblemente datos de prueba o actividades reorganizadas durante arranque).

4. **TQI tiene actividad reciente** — 2 actividades, incluyendo el caso de sincronización del usuario omarcqro@gmail.com resuelto el 29/04/2026.

5. **TQSL y TSLS sin actividades** — proyectos en etapa inicial, usuarios asignados pero sin operación de campo registrada aún.

---

## Estado de Infraestructura

| Componente | Estado |
|------------|--------|
| Backend FastAPI (Cloud Run) | ✅ Operativo |
| Firestore (sao-prod-488416) | ✅ Operativo |
| App Móvil Flutter | ✅ Operativa |
| Desktop Admin Flutter | ✅ Funcional |
| Autenticación Firebase | ✅ Operativa |

---

*Documento generado mediante consulta directa a Firestore. Para actualizar, ejecutar el script de diagnóstico o consultar el endpoint `/api/v1/sync/admin/diagnostics`.*
