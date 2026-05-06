# Notificaciones Push Remotas a Usuarios

## Propósito

Permite a operadores con rol privilegiado enviar una notificación push a todos los dispositivos registrados de un usuario específico, sin necesidad de acceder al dispositivo. El caso de uso principal es solicitar que el usuario abra la app y sincronice cuando se detectan actividades bloqueadas.

---

## Endpoint

```
POST /api/v1/notifications/admin/push-user
```

**Autenticación:** JWT requerido. Roles permitidos: `ADMIN`, `COORD`, `SUPERVISOR`, `DESARROLLADOR`.

### Body (JSON)

| Campo | Tipo | Requerido | Descripción |
|---|---|---|---|
| `user_id` | string (UUID) | ✅ | UUID del usuario destino |
| `title` | string (1–100) | ✅ | Título de la notificación |
| `body` | string (1–300) | ✅ | Cuerpo del mensaje |
| `type` | string | — | Tipo FCM (ver tabla abajo). Default: `admin_message` |
| `project_id` | string | — | Limita el envío a tokens del proyecto indicado |

### Respuesta exitosa (`200 OK`)

```json
{
  "sent": 2,
  "failed": 0,
  "invalidated": 0
}
```

- `sent`: dispositivos que recibieron el push
- `failed`: dispositivos que fallaron (token válido pero error de entrega)
- `invalidated`: tokens desactivados por ser inválidos/expirados

---

## Tipos FCM y comportamiento en la app

El campo `type` se incluye en el `data` del mensaje FCM. La app móvil reacciona así:

| `type` | Comportamiento en la app |
|---|---|
| `activity_update` | Refresca actividades en el home, muestra banner |
| `assignment_update` | Refresca agenda del usuario, muestra banner |
| `review_approved` | Refresca actividades, muestra banner de aprobación |
| `review_changes_required` | Refresca actividades, muestra banner de corrección |
| `catalog_update` | Descarga el catálogo más reciente del proyecto |
| `admin_message` | Muestra la notificación sin acción automática (default) |

Para solicitar que el usuario sincronice: usar `"type": "activity_update"`.

---

## Ejemplo: forzar sincronización de usuario con actividades pendientes

```bash
curl -X POST "https://sao-api-97150883570.us-central1.run.app/api/v1/notifications/admin/push-user" \
  -H "Authorization: Bearer <ADMIN_JWT>" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "3be0649d-b804-423d-ac9c-a1a1374370b0",
    "title": "Por favor sincroniza la app",
    "body": "Tienes actividades pendientes de enviar al servidor.",
    "type": "activity_update",
    "project_id": "TAP"
  }'
```

---

## Flujo técnico

```
Admin invoca endpoint
       ↓
Backend consulta device_push_tokens (Firestore)
  WHERE user_id = <target> AND enabled = true
  [WHERE project_id = <project>]  ← opcional
       ↓
FCM MulticastMessage → dispositivos registrados
       ↓
App recibe mensaje → reacciona según data.type
```

Si el usuario no tiene tokens registrados (nunca abrió la app, desinstalación, etc.), el endpoint responde con `{"sent": 0, ...}` y registra una advertencia en Cloud Logging con tag `NOTIFY_USER_NO_TOKENS`.

---

## Implementación

| Componente | Archivo |
|---|---|
| Lógica de envío | `backend/app/services/push_notification_service.py` → `notify_user()` |
| Endpoint HTTP | `backend/app/api/v1/notifications.py` → `POST /admin/push-user` |
| Manejo en app | `frontend_flutter/sao_windows/lib/features/home/home_page.dart` → `_setupPushNotificationsBridge()` |
| Tipos reconocidos | `frontend_flutter/sao_windows/lib/features/home/home_push_refresh_policy.dart` |

---

## Notas

- Si `project_id` se omite, se usan **todos** los tokens del usuario, independientemente del proyecto.
- Los tokens inválidos se desactivan automáticamente en Firestore durante el envío.
- El endpoint requiere que FCM esté habilitado en producción (`FCM_ENABLED=true`). Si no está configurado, devuelve `{"sent": 0, ...}` sin error.
- Ver diagnóstico de dispositivo sin tokens: `POST /api/v1/sync/admin/diagnostics`.
