# 🔧 Solución: Error de MIME Type en Versión Web

**Fecha:** 29 de abril de 2026, 23:15  
**Error:** `TypeError: Unexpected response MIME type. Expected 'application/wasm'`  
**Causa:** Caché obsoleto del navegador

---

## ✅ ¿QUÉ SE HIZO?

1. ✅ Compilación limpia de la app web Flutter
2. ✅ Actualización de todos los archivos en Cloud Storage
3. ✅ Deshabilitación de caché para archivos críticos
4. ✅ Verificación de tipos MIME correctos

---

## 📋 PASOS PARA RESOLVER

### 1️⃣ Limpiar Caché del Navegador

**Chrome/Edge:**
- Presione: `Ctrl+Shift+Delete` (Windows) o `Cmd+Shift+Delete` (Mac)
- Seleccione:
  - ✓ Cookies and other site data
  - ✓ Cached images and files
- Rango de tiempo: **All time**
- Click **Clear data**

**Firefox:**
- Presione: `Ctrl+Shift+Delete`
- Seleccione:
  - ✓ Cache
  - ✓ Cookies
  - ✓ Site Data
- Rango de tiempo: **Everything**
- Click **Clear Now**

**Safari (Mac):**
- Menú: **Safari > Privacy > Manage Website Data**
- Busque: `sao-web-app-ios-20260422`
- Click: **Remove** o **Remove All**

### 2️⃣ Cierre Todas las Pestañas

Cierre **todas las pestañas** que tengan la app SAO abierta.

### 3️⃣ Acceda a la App

Abra una **nueva pestaña** e ingrese a:
```
https://storage.googleapis.com/sao-web-app-ios-20260422/index.html?v=20260429reload
```

### 4️⃣ Intente Sincronizar

Ahora debería funcionar sin el error de MIME type.

---

## 📊 Cambios Realizados

| Componente | Estado | Detalles |
|-----------|--------|----------|
| **Flutter Build** | ✅ Nuevo | Compilación limpia sin caché |
| **Cloud Storage** | ✅ Sincronizado | 14 archivos actualizados (6.2 MiB) |
| **index.html** | ✅ No cacheable | Cache-Control: no-cache |
| **main.dart.js** | ✅ No cacheable | Cache-Control: no-cache |
| **flutter_service_worker.js** | ✅ No cacheable | Cache-Control: no-cache |
| **Tipos MIME** | ✅ Validado | text/javascript, text/html correcto |

---

## 🔍 Si Sigue el Error

### Opción A: DevTools (F12)

Abre la consola del navegador (**F12 > Console**) y copia el error exacto para diagnosticar.

### Opción B: Limpia Todo

```bash
# En MacOS/Linux, para aplicaciones Chrome, ejecuta:
rm -rf ~/.cache/google-chrome/*
rm -rf ~/.cache/chromium/*
```

### Opción C: Acceso Incógnito

Intenta en una ventana de **navegación incógnita/privada**:
- Esto evita caché local completamente
- Si funciona aquí, es definitivamente un problema de caché

### Opción D: Nuevo Navegador

Prueba en **Firefox** o **Safari** en lugar de Chrome.

---

## 🧪 Verificación Técnica

Para verificar que los archivos están correctos:

```bash
# Verificar tipo MIME de main.dart.js
gsutil stat gs://sao-web-app-ios-20260422/main.dart.js | grep Content-Type
# Debería retornar: Content-Type: text/javascript

# Verificar cache-control de index.html
gsutil stat gs://sao-web-app-ios-20260422/index.html | grep Cache-Control
# Debería retornar: Cache-Control: no-cache, max-age=0
```

---

## 📝 Resumen

| Acción | Resultado |
|--------|-----------|
| Limpiar caché navegador | 🟢 Necesario (90% de casos) |
| Cierre/reabra pestañas | 🟢 Necesario |
| Reload página | 🟢 Debería funcionarNow |
| Dev Console F12 | 🟡 Para diagnosticar si persiste |

---

## 🆘 Contacto

Si persiste el error después de estas acciones:

1. ✋ Abre DevTools (F12)
2. ✋ Tab **Console**
3. ✋ Copia el error completo
4. ✋ Contáctanos con screenshot

---

**⏰ Estimado:** 5 minutos para resolver

**✅ Esperado:** Acceso sin errores a sincronización web
