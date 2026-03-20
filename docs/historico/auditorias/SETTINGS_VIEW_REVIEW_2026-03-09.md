# Settings View Review - 2026-03-09

## Scope
- `frontend_flutter/sao_windows/lib/features/settings/settings_page.dart`
- `frontend_flutter/sao_windows/lib/features/auth/data/auth_provider.dart`
- `frontend_flutter/sao_windows/lib/features/auth/data/auth_repository.dart`
- `frontend_flutter/sao_windows/lib/features/auth/application/auth_providers.dart`
- `frontend_flutter/sao_windows/lib/features/auth/application/auth_controller.dart`
- `frontend_flutter/sao_windows/lib/core/catalog/state/catalog_providers.dart`

## Cambios Aplicados En Esta Iteracion
- Se cambio la fuente principal de estado visual de usuario a `authControllerProvider` en la vista (`settings_page.dart:204`).
- Se completo la unificacion de acciones de seguridad (contrasena + biometria) a traves de `authControllerProvider` (`settings_page.dart:64`, `settings_page.dart:708`).
- Se extendio capa app/data de auth con casos de uso faltantes:
  - `AuthController`: `changePassword`, `canUseBiometrics`, `isBiometricEnabled`, `setBiometricEnabled`.
  - `AuthRepository`: `changePassword`, `isBiometricEnabled`, `setBiometricEnabled`.
  - Inyeccion de `BiometricService` y `SharedPreferences` en providers de auth.
- Se agrego hardening de inicial de avatar con fallback seguro (`settings_page.dart:42`, `settings_page.dart:268`).
- Se reemplazo `withOpacity` por `withValues(alpha: ...)` en los puntos detectados (`settings_page.dart:292`, `settings_page.dart:301`, `settings_page.dart:313`).
- Se reemplazo falla silenciosa en biometria por estados visibles de `loading/error/reintento` (`settings_page.dart:675`, `settings_page.dart:685`).
- Se reemplazo falla silenciosa en catalogo por estados visibles de `loading/error/reintento` (`settings_page.dart:729`, `settings_page.dart:734`, `settings_page.dart:759`).
- Validacion estatica del archivo: sin errores reportados.

## Como Funciona Actualmente

### 1. Cabecera y contexto de usuario
- La pantalla toma estado visual de autenticacion desde `authControllerProvider` (`settings_page.dart:204`).
- Si hay usuario, muestra tarjeta clickeable hacia perfil (`settings_page.dart:250`).
- Si viene en modo tutorial (`?tutorial=1`), muestra banner informativo (`settings_page.dart:200-236`).

### 2. Seguridad
- Cambio de contrasena con dialogo y validaciones basicas (requerido, minimo 8, confirmacion) (`settings_page.dart:44`, `settings_page.dart:828`).
- La operacion llama `authControllerProvider.notifier.changePassword(...)` (`settings_page.dart:64`).
- Biometria con tile reactivo (`_BiometricTile`) que:
  - consulta disponibilidad y estado (`settings_page.dart:24`, `settings_page.dart:662`)
  - activa/desactiva via `authControllerProvider.notifier.setBiometricEnabled(...)` (`settings_page.dart:708`)

### 3. Configuracion de aplicacion
- Permite cambiar backend base URL en runtime con validacion de URL (`settings_page.dart:96-178`).
- Persiste override en `SharedPreferences` (`_apiBaseUrlKey`) y actualiza `ApiClient` (`settings_page.dart:172`, `settings_page.dart:182`).
- Muestra estado de catalogo por proyecto con providers de catalogo (`settings_page.dart:692`, `catalog_providers.dart:36`, `catalog_providers.dart:43`).
- Permite sincronizar catalogo desde el tile de version (`settings_page.dart:751-759`).
- Navega a centro de sincronizacion (`settings_page.dart:370-373`).

### 4. Bloque debug
- En `kDebugMode` muestra acciones de smoke test para sync y catalogos (`settings_page.dart:378`).
- Incluye pruebas manuales de pull/sync y persistencia de catalogo.

### 5. Cierre de sesion
- Confirmacion por dialogo y logout via `authControllerProvider` (`settings_page.dart:639`).
- Invalida providers de auth y redirige a `/auth/login` (`settings_page.dart:640-646`).

---

## Hallazgos De Revision (Priorizados)

### 1) High - Mezcla de dos sistemas de estado de auth en la misma pantalla
- Evidencia:
  - La vista usa `authControllerProvider` para estado visual, seguridad y logout (`settings_page.dart:204`, `settings_page.dart:64`, `settings_page.dart:708`, `settings_page.dart:639`).
  - Existen dos `AuthState` distintos en el codigo:
    - `auth_provider.dart:61`
    - `auth_controller.dart:9`
- Riesgo:
  - Mitigado para la vista de Ajustes. La dualidad arquitectonica global sigue existiendo en el codigo, pero esta pantalla ya no mezcla providers.
- Recomendacion:
  - Mantener `authControllerProvider` como unica via en pantallas nuevas y planear retiro progresivo de `authProvider` legacy.

### 2) Medium - Errores ocultos en tiles reactivos (falla silenciosa)
- Evidencia:
  - Se corrigio: ahora ambos tiles muestran estados de carga/error y boton de reintento (`settings_page.dart:675`, `settings_page.dart:685`, `settings_page.dart:734`, `settings_page.dart:759`).
- Riesgo:
  - Mitigado.
- Recomendacion:
  - Mantener este patron en otras vistas reactivas del modulo.

### 3) Medium - Potencial crash por indice de nombre sin validar
- Evidencia:
  - Se corrigio con helper defensivo `_safeInitial(...)` (`settings_page.dart:42`, `settings_page.dart:268`).
- Riesgo:
  - Mitigado.
- Recomendacion:
  - Reutilizar helper equivalente en otras tarjetas de usuario.

### 4) Low - Deuda tecnica por APIs de color deprecadas
- Evidencia:
  - Se corrigio en los puntos auditados (`settings_page.dart:292`, `settings_page.dart:301`, `settings_page.dart:313`).
- Riesgo:
  - Mitigado para esta vista.
- Recomendacion:
  - Extender migracion al resto del modulo (`settings` relacionado) para eliminar warnings similares.

### 5) Low - Cambio de backend disponible desde Ajustes sin guardrails de entorno
- Evidencia:
  - Opcion visible para cambiar endpoint (`settings_page.dart:362`, `settings_page.dart:365`).
- Riesgo:
  - Errores operativos en produccion (endpoint incorrecto, confusion de entorno).
- Recomendacion:
  - Restringir a perfiles admin/dev o build flavor no-produccion.
  - Agregar confirmacion explicita y prueba de salud (`/health`) antes de guardar.

---

## Cambios Que Haria (Propuesta)

### Fase 1 - Quick wins (bajo riesgo)
1. Unificar consumo de auth en Settings a `authControllerProvider`. (Completado)
2. Reemplazar `SizedBox.shrink()` en errores por tiles de estado con reintento.
3. Hardening de avatar inicial para `fullName` vacio.
4. Migrar `withOpacity` -> `withValues`.

### Fase 2 - UX y robustez
1. Backend URL:
   - Selector por entorno (`Dev`, `Staging`, `Prod`) + opcion custom.
   - Verificacion de conectividad previa a guardar.
2. Biometria:
   - Mensaje de error visible cuando `setBiometricEnabled` falla.
   - Indicador temporal de progreso durante activacion/desactivacion.
3. Catalogo:
   - Mostrar ultima fecha de sync y version completa en detalle expandible.

### Fase 3 - Arquitectura
1. Extraer logica de settings a `SettingsController`/`SettingsViewModel`.
2. Evitar llamadas de red directas desde la vista para mejorar testeabilidad.
3. Crear pruebas de widget para:
   - cambio de contrasena (success/error)
   - backend override (validacion/guardado/reset)
   - estados de `_BiometricTile` y `_CatalogVersionTile`.

---

## Resumen Ejecutivo
- La vista de ajustes actualmente cubre bien los casos funcionales principales (seguridad, backend, catalogo, sync, logout).
- El principal riesgo tecnico inicial (mezcla de dos capas de auth en Ajustes) quedo mitigado con la unificacion en `authControllerProvider`.
- Las mejoras recomendadas priorizan consistencia de estado, visibilidad de errores y seguridad operativa al cambiar endpoint.
