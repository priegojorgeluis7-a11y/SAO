# Reglas de Diseño Visual SAO (enforcement)

## Objetivo
Definir reglas obligatorias para que toda la UI sea consistente, accesible y mantenible, evitando hardcodeo visual fuera de los tokens del sistema.

## Regla 1 — Colores
- Prohibido usar colores directos en features UI: `Colors.*`, `Color(0x...)`.
- Permitido:
  - `Theme.of(context).colorScheme.*`
  - Tokens del sistema de diseño centralizados (`SaoColors`) solo dentro de capa de tema/tokens o componentes base.
- Excepción controlada:
  - Render PDF (`pw.*`, `PdfColor`) por ser salida no-Material.

## Regla 2 — Tipografía
- Evitar `TextStyle(fontSize: ...)` en pantallas de negocio.
- Preferir `Theme.of(context).textTheme.*` y ajustar solo peso/overflow cuando sea necesario.
- Si se requiere tamaño especial, definirlo como token tipográfico reutilizable (no inline repetido).

## Regla 3 — Espaciado y radios
- Evitar “números mágicos” repetidos para padding, margin y radios.
- Preferir tokens de spacing/radius del sistema (`SaoSpacing`, `SaoRadii`) o constantes locales semánticas por pantalla.

## Regla 4 — Estados visuales y contraste
- Todo estado semántico (éxito, error, advertencia, info) debe usar color semántico de tema.
- Texto sobre superficies tintadas debe usar color `on*` correspondiente (`onPrimaryContainer`, `onErrorContainer`, etc.).
- Mínimo esperado de contraste: WCAG AA para texto normal.

## Regla 5 — Componentes
- Reutilizar componentes base (`ui/widgets`) antes de construir estilos inline.
- No duplicar estilos visuales en múltiples pantallas.

## Regla 6 — Hardcodeo permitido
- Catálogos de tokens (ejemplo: `ui/theme/sao_colors.dart`) sí pueden contener valores hex, porque son fuente única de verdad.
- Fuera de esa capa, los hex deben considerarse incumplimiento.

## Checklist de PR (obligatorio)
- [ ] Sin `Colors.*` en pantalla de negocio
- [ ] Sin `Color(0x...)` en pantalla de negocio
- [ ] Tipografía basada en `textTheme`
- [ ] Estados visuales con semántica de `colorScheme`
- [ ] Contraste revisado en modo claro/oscuro

## Recomendación de automatización
Agregar validación CI con búsquedas regex por carpeta de features para bloquear:
- `Colors\.`
- `Color\(0x`
- `TextStyle\(\s*fontSize:`

Permitir excepciones explícitas en:
- `lib/ui/theme/**`
- `lib/core/theme/**`
- `lib/features/reporting/pdf_builder/**`
