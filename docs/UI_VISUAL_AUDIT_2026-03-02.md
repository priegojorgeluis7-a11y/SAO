# Auditoría visual rápida — 2026-03-02

## Alcance
- Desktop Flutter: `desktop_flutter/sao_desktop/lib/**`
- Frontend Flutter (lote wizard): `frontend_flutter/sao_windows/lib/features/activities/wizard/**`
- Enfoque: hardcodeo visual y contraste

## Hallazgos
1. Módulo Catálogos
- Estado: corregido en esta sesión.
- Acciones aplicadas:
  - Reemplazo de colores directos por `Theme.of(context).colorScheme.*`.
  - Ajuste de chips de cabecera para contraste (`surfaceContainerHighest` + `onSurfaceVariant`).
  - Mensajes de advertencia con color semántico de error.
  - Tipografía principal migrada a `textTheme` en títulos clave.

2. Workspace UI general (desktop)
- Se detectan múltiples coincidencias de `Colors.*` y `Color(...)` en el código.
- Nota: una parte significativa está en capas de tema y catálogos de tokens (`ui/theme`, `core/theme`), lo cual sí es válido.
- Hay pendientes en features/pantallas y widgets que todavía usan valores directos o no-semánticos.

## Clasificación de cumplimiento
- Cumple:
  - `desktop_flutter/sao_desktop/lib/features/catalogs/catalogs_page.dart`
  - `desktop_flutter/sao_desktop/lib/features/operations/validation_page.dart`
  - `desktop_flutter/sao_desktop/lib/features/operations/validation_page_new_design.dart`
  - `desktop_flutter/sao_desktop/lib/features/operations/ui/operations_validation_view_simple.dart`
  - `desktop_flutter/sao_desktop/lib/features/operations/widgets/caption_editor_widget.dart`
  - `desktop_flutter/sao_desktop/lib/features/operations/widgets/gps_validation_banner.dart`
  - `desktop_flutter/sao_desktop/lib/features/operations/widgets/custom_drag_controller.dart`
  - `desktop_flutter/sao_desktop/lib/features/operations/widgets/evidence_gallery_panel_pro.dart`
  - `desktop_flutter/sao_desktop/lib/features/operations/widgets/catalog_substitution_modal.dart`
  - `desktop_flutter/sao_desktop/lib/features/operations/widgets/activity_form_panel.dart`
  - `desktop_flutter/sao_desktop/lib/features/operations/ui/operations_validation_view_simple.dart` (fase tipografía aplicada)
  - `desktop_flutter/sao_desktop/lib/features/operations/validation_page.dart` (chips tipográficos normalizados)
  - `desktop_flutter/sao_desktop/lib/features/operations/validation_page_new_design.dart` (chips/atajos tipográficos normalizados)
  - `desktop_flutter/sao_desktop/lib/features/operations/widgets/caption_editor_widget.dart` (tipografía base normalizada)
  - `desktop_flutter/sao_desktop/lib/features/operations/widgets/activity_details_panel_pro.dart` (timeline tipográfica normalizada)
  - `desktop_flutter/sao_desktop/lib/features/reports/reports_page.dart`
  - Reglas de contraste para elementos recientes de Catálogos.
- Pendiente (requiere fase 2):
  - `desktop_flutter/sao_desktop/lib/features/reports/reports_provider.dart` mantiene tipografía PDF en constantes dedicadas (`pw.TextStyle`).
  - Unificación adicional hacia `textTheme` + `colorScheme` en componentes heredados.

## Plan recomendado (fase 2)
1. Barrido por lotes (features críticos primero):
- `features/operations/**`
- `features/reports/**`
- `features/planning/**`

2. Criterio técnico por archivo:
- Eliminar `Colors.*` en capas de pantalla.
- Eliminar `Color(0x...)` fuera de tema/tokens.
- Sustituir tamaños tipográficos repetidos por `textTheme`.

3. Gate de calidad
- Agregar chequeo CI con regex y allowlist de carpetas de tema/PDF.

## Resultado actual
- Catálogos y Operations/Reports activos quedan alineados a reglas de contraste y sin hardcodeo visual crítico en color.
- Búsqueda `\bColors\.` en `features/operations/**/*.dart`: sólo quedan coincidencias en archivo `backup`.
- Tipografía (`fontSize` inline) y color (`Colors.*`) quedan normalizados en `features/operations/**` (incluyendo backups).
- Lote frontend wizard normalizado: búsqueda `\bColors\.|fontSize\s*:` en `frontend_flutter/sao_windows/lib/features/activities/wizard/**/*.dart` queda sin coincidencias de hardcode visual (excepto `Color` como tipo en firmas de funciones).
- Se establece documento normativo para aplicar de forma transversal en el repo.
