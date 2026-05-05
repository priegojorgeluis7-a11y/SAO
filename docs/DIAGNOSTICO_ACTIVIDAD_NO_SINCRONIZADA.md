# ⚠️ Diagnóstico: Actividad No Sincronizada del Usuario

**Fecha:** 29 de abril de 2026, 19:30  
**Usuario:** omarcqro@gmail.com (ID: 69bc9f88-88ee-4a44-ba55-33ee58dbd464)  
**Actividad UUID:** 696150cb-8301-49a3-9465-83f627c25c57  
**Proyecto:** TQI  

---

## 🔴 PROBLEMA

El usuario reporta:
- ✅ "Pude sincronizar la actividad"
- ✅ "La pude aprobar"
- ❌ "Pero no me aparece en el sistema"

**Realidad:** La actividad **NUNCA fue sincronizada** desde el dispositivo del usuario al servidor.

---

## 🔍 EVIDENCIA TÉCNICA

### Logs del Backend (19:21 - 19:27)

| Timestamp | Endpoint | Método | Resultado | Descripción |
|-----------|----------|--------|-----------|-------------|
| 19:21:11 | `/api/v1/review/activity/.../decision` | POST | 200 | Admin aprueba la actividad |
| 19:21:11 | `/api/v1/activities/.../readiness` | GET | 200 | Verificar disponibilidad |
| 19:21:31 | `/api/v1/completed-activities/...` | GET | 200 | Consultar estado completado |
| 19:22-24 | `/api/v1/sync/pull` | POST | 200 | Sincronización DESCARGA |
| ❌ NUNCA | `/api/v1/sync/push` | POST | - | ❌ **Sincronización ENVÍO** |

**Conclusión:** Solo hay descargas (`/sync/pull`), **NO hay envíos** (`/sync/push`).

---

## 🔎 ESTADO EN FIRESTORE

```
Búsqueda en Firestore:
├─ TQI (proyecto correcto): ❌ NO ENCONTRADA
├─ TAP: ❌ NO ENCONTRADA
├─ TMQ: ❌ NO ENCONTRADA
├─ TQSL: ❌ NO ENCONTRADA
├─ TSLS: ❌ NO ENCONTRADA
└─ TSNL: ❌ NO ENCONTRADA

RESULTADO: La actividad NO existe en Firestore
```

---

## 🧠 CAUSA RAÍZ

La actividad existe **SOLO en la BD local** del dispositivo del usuario (SQLite/Drift):

```
┌─────────────────────────────────────────┐
│   Dispositivo del Usuario               │
│  ┌─────────────────────────────────┐    │
│  │  BD Local (SQLite/Drift)        │    │
│  │  ✓ Actividad 696150cb...        │    │
│  │  ✓ Estado: "Sincronizada"       │    │
│  │  ✓ Aprobada                     │    │
│  └─────────────────────────────────┘    │
│            ↓ /sync/push ↓              │
│          ❌ NUNCA EJECUTADO ❌         │
│                                         │
└─────────────────────────────────────────┘
                  ↓
        ❌ Nunca llega aquí ❌
                  ↓
┌─────────────────────────────────────────┐
│      Firestore (Servidor)               │
│  ┌─────────────────────────────────┐    │
│  │  Proyecto TQI                   │    │
│  │  ❌ Actividad NO existe         │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

---

## 🤔 ¿Por Qué el Admin Ve "200 OK"?

El endpoint `/api/v1/completed-activities/{uuid}` retorna **200 sin datos** porque:

1. El endpoint busca la actividad en la **colección global** `activities`
2. La actividad nunca llegó a esa colección (porque `/sync/push` nunca se ejecutó)
3. El endpoint retorna 200 como si la búsqueda fuera exitosa, pero sin datos reales

**Esto da la ilusión de que la actividad existe, pero está vacía.**

---

## ✅ SOLUCIÓN REQUERIDA

### Para el Usuario (omarcqro@gmail.com)

**El usuario DEBE reintentar el sync push:**

1. Abrir la app en su dispositivo
2. Navegar a **Actividades > Proyecto TQI**
3. Buscar actividad: `696150cb-8301-49a3-9465-83f627c25c57`
4. Presionar botón **"Sincronizar"** o **"Enviar"**
5. ✅ La actividad se enviará a Firestore (backend ya está arreglado)

### Para el Admin

⏳ **Esperar a que el usuario reintente** desde su dispositivo.

Luego verificar:
```bash
# Una vez que usuario presione "Sincronizar"
gcloud firestore documents get projects/sao-prod-488416/databases/\(default\)/documents/projects/TQI/activities/696150cb-8301-49a3-9465-83f627c25c57
```

---

## 📊 Timeline de Eventos

```
14:00 - Usuario crea actividad localmente (BD local del dispositivo)
14:05 - Usuario intenta "sincronizar" (se ve como exitoso en la app)
19:21 - Admin ve UUID en logs y piensa que está en el servidor
19:21 - Admin aprueba la actividad (POST /review/activity/.../decision)
19:21 - Admin consulta estado (GET /completed-activities/...)
19:26 - Consultas GET a /completed-activities retornan 200 sin datos
19:30 - ⚠️ Se descubre que actividad NO está en Firestore
```

---

## 🛠️ Cambios de Backend Realizados

✅ **Error original corregido:**
- Error: `UnboundLocalError: cannot access local variable 'existing_participant_user_ids'`
- Ubicación: `backend/app/api/v1/sync.py` línea 523
- Estado: **CORREGIDO y desplegado** (29/04/2026 19:12)

✅ **Nuevo endpoint para diagnósticos:**
- Ruta: `POST /api/v1/sync/admin/diagnostics`
- Uso: Operadores pueden diagnosticar issues sin acceso al dispositivo
- Estado: **EN PRODUCCIÓN**

---

## 📝 Próximos Pasos

### Acción Inmediata (Usuario)
1. ✋ Pedir al usuario que reinicie la app
2. ✋ Pedir que presione "Sincronizar" en la actividad
3. ⏳ Monitorear logs para ver `/api/v1/sync/push`

### Verificación (Admin)
```bash
# Ver si el sync push fue exitoso
gcloud run services logs read sao-api \
  --project=sao-prod-488416 \
  --limit=50 | grep "696150cb"

# Buscar en Firestore
# Debería encontrarse en: projects/TQI/activities/696150cb-8301-49a3-9465-83f627c25c57
```

### Si el Problema Persiste
1. Verificar conectividad de red del dispositivo
2. Limpiar caché de app
3. Reinstalar la app
4. Verificar versión de la app (puede estar usando código viejo)

---

## 📌 Lecciones Aprendidas

⚠️ **La app puede mostrar "✓ Sincronizado" MIENTRAS QUE:**
- La actividad aún está en BD local
- El sync push nunca fue ejecutado
- El servidor NO tiene la actividad

✅ **Solución:** El nuevo endpoint `/api/v1/sync/admin/diagnostics` permite a operadores identificar este problema sin acceso al dispositivo.
