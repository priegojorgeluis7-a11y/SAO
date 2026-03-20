# SAO - Historico Documental

## Objetivo
Concentrar documentos de auditoria, diagnostico y planes fechados que ya no son la referencia operativa principal, pero deben conservarse para trazabilidad.

## Estructura
- `docs/historico/auditorias/` - auditorias y revisiones puntuales.
- `docs/historico/planes/` - planes de mitigacion y diagnosticos historicos.

## Indice por periodo

### 2026-03

#### Auditorias
- `docs/historico/auditorias/AUDITORIA_FIX_CATALOGOS_MULTIPROYECTO.md`
- `docs/historico/auditorias/AUDITORIA_MOVIL_2026-03-05.md`
- `docs/historico/auditorias/CODE_AUDIT_2026-03-09.md`
- `docs/historico/auditorias/SETTINGS_VIEW_REVIEW_2026-03-09.md`
- `docs/historico/auditorias/UI_VISUAL_AUDIT_2026-03-02.md`

#### Planes y diagnosticos
- `docs/historico/planes/DIAGNOSTICO_FLUJO_100_FUNCIONAL_2026-03-05.md`
- `docs/historico/planes/PLAN_FIX_HALLAZGOS_SEVERIDAD_2026-03-05.md`

## Regla de archivado
Mover a `historico` cuando el documento:
- tenga fecha en el nombre y su contenido sea una fotografia de estado,
- haya sido reemplazado por una fuente canonica mas reciente,
- o sirva solo como evidencia historica.

Antes de mover:
1. Actualizar enlaces en `docs/README.md` y, si aplica, en `docs/DOCUMENTO_MAESTRO_SISTEMA.md`.
2. Verificar que no queden referencias rotas.
