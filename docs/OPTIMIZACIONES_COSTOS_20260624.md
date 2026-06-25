# Optimizaciones de Costos Cloud Run/Firestore

**Fecha:** 24 de junio de 2026  
**Problema:** Costos de App Engine/Cloud Run disparados después de última publicación

---

## Resumen de Cambios

### 1. Índices de Firestore Actualizados ✅
**Archivo:** `firestore.indexes.json`

Nuevos índices compuestos agregados:
- `(project_id ASC, created_at DESC)` - Para queries de reportes
- `(project_id ASC, execution_state ASC, created_at DESC)` - Para filtros de estado
- `(project_id ASC, review_decision ASC, created_at DESC)` - Para cola de revisión
- `(project_id ASC, front_id ASC, created_at DESC)` - Para filtros de frente
- `(activity_group_id ASC, sync_version ASC)` - Para queries de grupos

### 2. Endpoint `/reports/activities` Optimizado ✅
**Archivo:** `backend/app/api/v1/reports.py`

**Antes:**
```python
docs = [d.to_dict() or {} for d in query.stream()]  # FULL SCAN
```

**Después:**
```python
query = query.where("project_id", "==", project_filter)
if date_from:
    query = query.where("created_at", ">=", date_from)
if date_to:
    query = query.where("created_at", "<=", date_to)
query = query.order_by("created_at", direction="DESCENDING")
query = query.limit(page_size).offset(offset)
```

### 3. Endpoint `/assignments` Optimizado ✅
**Archivo:** `backend/app/api/v1/assignments.py`

**Antes:**
```python
# Full table scan como fallback
for doc in client.collection("activities").stream():
    # Escanear TODOS los documentos
```

**Después:**
```python
# Solo consulta indexada con límite
query = client.collection("activities").where("project_id", "==", normalized_project_id)
query = query.limit(limit)  # Límite de 1000 documentos
```

### 4. Módulo de Caché Implementado ✅
**Archivo:** `backend/app/core/cache.py`

- Caché en memoria con TTL (Time-To-Live)
- LRU eviction para prevenir memory leaks
- Índices separados: usuarios (60s), catálogos (5min), proyectos (5min)

### 5. Servicio de Usuarios con Caché ✅
**Archivo:** `backend/app/services/firestore_identity_service.py`

Ya tenía `lru_cache` implementado para `list_firestore_users()`.

---

## Pasos para Desplegar

### 1. Desplegar Índices de Firestore

```bash
# Opción 1: Usar el script
./scripts/deploy_firestore_indexes.sh sao-prod-488416

# Opción 2: Manual
gcloud config set project sao-prod-488416
gcloud firestore indexes import firestore.indexes.json
```

### 2. Desplegar Backend

```bash
cd backend
gcloud run deploy sao-api \
  --source . \
  --region=us-central1 \
  --project=sao-prod-488416
```

### 3. Verificar en GCP Console

- **Cloud Run:** https://console.cloud.google.com/run/detail/us-central1/sao-api
- **Firestore:** https://console.cloud.google.com/firestore/indexes
- **Costos:** https://console.cloud.google.com/billing

---

## Impacto Esperado

| Métrica | Antes | Después |
|---------|-------|---------|
| Reads por request `/reports/activities` | ~500-1000 docs | ~50-200 docs |
| Reads por request `/assignments` | ~500-1000 docs | ~10-50 docs |
| Full table scans | Frecuentes | Eliminados |
| Reads repetidos de usuarios | Cada request | Cada 60 segundos |

---

## Recomendaciones Adicionales

1. **Monitorear uso:** Revisar logs de Cloud Run después del despliegue
2. **Redis externo:** Para producción a gran escala, considerar Redis Cloud
3. **Client Desktop:** Revisar que no esté haciendo requests excesivos
4. **Rate Limiting:** Considerar implementar para endpoints costosos

---

*Documento generado automáticamente para resolver incidente de costos elevados.*
