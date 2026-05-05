# 📲 Instrucciones para Reintentar Sincronización

**Usuario:** omarcqro@gmail.com (Omar Cobian)  
**Proyecto:** TQI (Tren Querétaro-Irapuato)  
**Actividad UUID:** 696150cb-8301-49a3-9465-83f627c25c57  
**Fecha:** 29 de abril de 2026  

---

## ⚠️ Situación Actual

La actividad se ve como "sincronizada" en la app del usuario, pero **NO llegó al servidor**. 

- ✅ Existe en la app (BD local)
- ✅ Usuario la aprobó desde el panel admin
- ❌ **NO ESTÁ en Firestore** (servidor)

---

## ✅ PASOS A SEGUIR

### 1️⃣ Abrir la App SAO

En el dispositivo del usuario (Android/iPhone/Tablet):
- Abra la aplicación **SAO - Sistema de Administración de Obras**
- Inicie sesión con: `omarcqro@gmail.com`

### 2️⃣ Navegar a la Actividad

Dentro de la app:
```
Inicio
  ↓
Actividades
  ↓
Proyecto: TQI (seleccionar)
  ↓
Buscar actividad
```

Busque por uno de estos criterios:
- **UUID:** `696150cb-8301-49a3-9465-83f627c25c57`
- Descripción o nombre que recuerde

### 3️⃣ Localizar el Botón de Sincronización

Una vez encuentre la actividad, busque:

**Opción A - Si ve un botón "Sincronizar":**
- Presione el botón ⬆️ **Sincronizar**
- O presione ⬆️ **Enviar**

**Opción B - Si ve un ícono de nube:**
- ☁️ Presione el ícono de nube
- O ↔️ Ícono de flechas (sincronizar)

**Opción C - Menú de opciones:**
- Presione el botón ⋮ (tres puntos)
- Seleccione **Sincronizar** o **Enviar**

### 4️⃣ Confirmar la Sincronización

La app mostrará:
- ⏳ "Sincronizando..." (puede tomar 5-10 segundos)
- ✅ "Sincronizado correctamente" 
- O mensaje de estado

**Espere a que termine completamente.**

### 5️⃣ Verificar en el Panel Admin

Una vez que el usuario presione sincronizar:

**Desde el admin (usted):**
1. Abra el panel administrativo de SAO
2. Navegue a **Actividades**
3. Busque el UUID: `696150cb-8301-49a3-9465-83f627c25c57`
4. ✅ Debería aparecer la actividad

---

## 🔍 ¿Si No Aparece?

Si después de 2 minutos la actividad aún no aparece:

### Intente 1: Refrescar la Página

- Presione F5 o botón actualizar del navegador
- O cierre y reabra el panel admin
- Espere 10 segundos

### Intente 2: Limpiar Caché

En el dispositivo del usuario:
1. Ir a **Configuración > Apps > SAO**
2. Presionar **Limpiar caché**
3. Abrir la app nuevamente
4. Reintentar sincronización

### Intente 3: Reinstalar la App

Si sigue sin funcionar:
1. Desinstalar SAO
2. Reinstalar desde Play Store (Android) o App Store (iOS)
3. Iniciar sesión
4. Buscar la actividad nuevamente
5. Presionar sincronizar

---

## ✅ Señales de Éxito

Cuando el sync sea exitoso verá:

En la app:
- ✅ Icono de checkmark ✓
- ✅ Estado: "Sincronizada"
- ✅ Timestamp actualizado

En el panel admin:
- ✅ La actividad aparece en la lista
- ✅ Estado: PENDIENTE (o status correcto)
- ✅ Todos los datos visibles

---

## 🆘 Si Hay Error

**Error:** "No hay conexión a internet"
- ✅ Verificar WiFi o datos móviles
- ✅ Reintentar sincronización

**Error:** "Error al sincronizar"
- ✅ El backend ya está arreglado (29/04/2026 19:12)
- ✅ Intente nuevamente en 1 minuto
- ✅ Si persiste, contacte al soporte

**Error:** "Actividad no encontrada"
- ✅ Verificar que está en proyecto correcto (TQI)
- ✅ Verificar que la actividad no fue eliminada
- ✅ Contactar al soporte

---

## 📊 Monitoreo en Tiempo Real

**Para el administrador - verificar que el sync está sucediendo:**

```bash
# Ejecutar en la terminal después que usuario presione sincronizar
gcloud run services logs read sao-api \
  --project=sao-prod-488416 \
  --region=us-central1 \
  --limit=100 | grep -E "696150cb|sync/push|69bc9f88"
```

Debería ver logs como:
```
POST /api/v1/sync/push HTTP/1.1" 200 OK
SYNC_PUSH_SUMMARY: created=1 updated=0 unchanged=0 failed=0
```

---

## ⏰ Tiempo Estimado

- Abrir app: 30 segundos
- Navegar a actividad: 1-2 minutos
- Presionar sincronizar: 10 segundos
- Sync procesándose: 5-10 segundos
- **TOTAL: ~2 minutos**

---

## 📞 Soporte

Si después de seguir estos pasos la actividad aún no aparece:

1. ✅ Recopile:
   - Nombre de usuario: omarcqro@gmail.com
   - UUID de actividad: 696150cb-8301-49a3-9465-83f627c25c57
   - Proyecto: TQI
   - Screenshot del error (si lo hay)

2. ✅ Contacte al equipo técnico con esta información

3. ✅ Mencione que el error de backend ya fue corregido (29/04/2026)

---

**IMPORTANTE:** El error del backend fue arreglado. Si ahora el usuario presiona sincronizar, la actividad **DEBE** llegar al servidor exitosamente.
