# Guía de Solución de Problemas de Sincronización

## Error "INVALID: Unexpected error processing item"

Cuando un usuario no puede subir sus actividades y recibe el error "Unexpected error processing item — check server logs", el problema está en el backend durante el procesamiento del sync push.

### Diagnóstico

#### 1. Obtener UUID exacto de la actividad fallida
Pídele al usuario que capture la actividad que falla. El UUID generalmente aparece en los logs de la aplicación o en el snackbar de error.

#### 2. Revisar logs del servidor
```bash
# Obtener logs recientes del API
gcloud run services logs read sao-api \
  --platform managed \
  --region us-central1 \
  --project sao-prod-488416 \
  --limit 100 | grep -A10 "PUSH_ITEM_UNEXPECTED_ERROR"
```

Los logs registran:
- `uuid`: identificador único de la actividad
- `project_id`: proyecto (TMQ, TSNL, TQI, etc.)
- `sync_version`: versión de sincronización
- `activity_type_code`: tipo de actividad (INSP_CIVIL, etc.)
- `execution_state`: estado de ejecución (PENDIENTE, EN_CURSO, COMPLETADA, etc.)
- `error`: descripción del error (p.ej. excepción de Python)

#### 3. Causas frecuentes
- **Código de actividad inválido**: `activity_type_code` no existe en el catálogo actual
- **Estado de ejecución inválido**: `execution_state` no es un valor permitido (PENDIENTE, EN_CURSO, REVISION_PENDIENTE, COMPLETADA, CANCELED)
- **Participante_user_ids inválido**: contiene UUIDs mal formados o nulos
- **Payload malformado**: wizard_payload tiene estructura incorrecta o campos incoercibles

### Monitoreo de Pushes

Se registra un resumen de cada push con estado de éxito/fallo:
```bash
gcloud run services logs read sao-api \
  --platform managed \
  --region us-central1 \
  --project sao-prod-488416 \
  --limit 50 | grep "SYNC_PUSH_SUMMARY"
```

Esto muestra:
- `total_items`: actividades procesadas
- `created`: creadas exitosamente
- `updated`: actualizadas exitosamente
- `failed`: con error

### Soluciones Comunes

#### Catálogo desactualizado en cliente
Si `activity_type_code` no existe en el catálogo:
1. Confirmar que el catálogo en el dispositivo está sincronizado: `/api/v1/catalog/version/current`
2. Pedir al usuario que cierre y reabra la app para refrescar el catálogo

#### Actividad cancelada
Actividades con `execution_state: CANCELED` o `deleted_at` no nulo ya no se pueden subir. El backend las rechaza con estado `UNCHANGED`.

#### Conflicto de versión de sincronización
Si el cliente envía `sync_version` menor que el servidor, se rechaza el push a menos que `force_override: true` esté activo.

### Escalación

Si el error persiste después de estos pasos:
1. Obtener el UUID exacto
2. Obtener timestamp del intento fallido
3. Ejecutar: `gcloud run services logs read sao-api --project sao-prod-488416 --limit 200 | grep <UUID>`
4. Revisar el stack trace completo del error
5. Abrir un ticket con la salida de logs y reproducir si es posible en local
