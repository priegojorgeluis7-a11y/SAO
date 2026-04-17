# Rediseño de la página de inicio - mejora del agrupado por acciones

**Estado**: Documento de diseño, 24 de marzo de 2026  
**Objetivo**: Mejorar la jerarquía visual y la experiencia de uso en la agrupación de actividades por acción siguiente.

---

## 1. Análisis del estado actual

### Estructura existente
- 8 secciones colapsables agrupadas por la propiedad `nextAction`.
- Subagrupación por `frente`.
- Renderizado básico con poca diferenciación visual.

### Gaps identificados
1. No hay indicadores claros de urgencia.
2. Faltan métricas de avance por sección.
3. Las acciones rápidas son limitadas.
4. La jerarquía visual es débil.
5. Los estados vacíos pueden resultar confusos.

---

## 2. Mejoras propuestas

### 2.1 Jerarquía visual por prioridad
Agrupar las acciones en tres niveles:

#### Nivel 1: acción requerida
- `CORREGIR_Y_REENVIAR`
- `REVISAR_ERROR_SYNC`
- `COMPLETAR_WIZARD`

#### Nivel 2: trabajo activo
- `INICIAR_ACTIVIDAD`
- `TERMINAR_ACTIVIDAD`
- `SINCRONIZAR_PENDIENTE`

#### Nivel 3: en espera de decisión
- `ESPERAR_DECISION_COORDINACION`
- `CERRADA_CANCELADA`
- `SIN_ACCION`

### 2.2 Tarjetas enriquecidas por sección
Cada sección debe mostrar:
- icono y nombre de la acción,
- contador visible,
- nivel de prioridad,
- barra de avance,
- botón de expandir o colapsar.

### 2.3 Métricas por sección
Se recomienda exponer:
- total de elementos,
- elementos completados,
- porcentaje de avance,
- tiempo promedio en la sección,
- número de casos críticos o vencidos.

### 2.4 Contenido expandido por actividad
Al abrir una sección, cada actividad debe mostrar:
- título,
- frente,
- PK,
- ubicación,
- indicador de GPS,
- tiempo transcurrido,
- botón de acción contextual.

### 2.5 Manejo de estados vacíos
Cuando una sección no tenga elementos:
- mostrar mensaje positivo,
- usar iconografía de completado,
- colapsar por defecto para reducir ruido visual.

---

## 3. Hoja de ruta de implementación

### Fase 1: ampliar el modelo de datos
Agregar métricas por sección, porcentaje de completitud y conteo de urgencias.

### Fase 2: crear encabezado de sección
Incorporar un widget dedicado para título, badge, progreso y prioridad.

### Fase 3: mejorar la tarjeta de actividad
Añadir acciones rápidas, microindicadores de GPS y sincronización, y tiempo en estado.

### Fase 4: integración en la página de inicio
1. Calcular métricas por sección.
2. Ordenar por prioridad.
3. Expandir automáticamente las secciones críticas.
4. Habilitar acciones rápidas contextuales.

### Fase 5: cobertura de pruebas
- pruebas unitarias de métricas,
- pruebas de widgets,
- pruebas de integración,
- validación E2E del flujo principal.

---

## 4. Codificación visual sugerida

| Nivel | Color sugerido | Uso |
|------|----------------|-----|
| Acción requerida | rojo / ámbar | correcciones, errores, pendientes críticos |
| Trabajo activo | azul / verde | actividades en curso o listas para iniciar |
| En espera | gris / morado | revisión, cierre o espera externa |

---

## 5. Flujos de interacción esperados

### Escenario 1: operativo abre inicio
1. La app carga actividades.
2. Las secciones se ordenan por prioridad.
3. Las secciones críticas aparecen primero.
4. El usuario corrige o sincroniza sin entrar a varias vistas intermedias.

### Escenario 2: coordinación revisa progreso
1. Visualiza conteos y porcentaje por bloque.
2. Identifica cuellos de botella rápido.
3. Entra a la cola de revisión desde la misma agrupación.

### Escenario 3: reanudación tras trabajo offline
1. Las actividades pendientes de sincronización quedan visibles.
2. El usuario ejecuta la acción rápida de sincronizar.
3. Los elementos se mueven a la sección correspondiente al nuevo estado.

---

## 6. Métricas de éxito

- Reducir taps para llegar a la acción principal.
- Facilitar la detección de urgencias en pocos segundos.
- Mejorar la finalización de acciones desde la vista principal.
- Mantener cálculos de métricas por debajo de 500 ms con carga normal.

---

## Files to Create/Modify

### New Files
- `home_section_header.dart` - Enhanced section header widget
- `task_section_metrics.dart` - Metrics data model
- `home_quick_action_button.dart` - Context-aware action buttons
- `home_page_redesign_test.dart` - Widget and metrics tests

### Modified Files
- `home_page.dart` - Integrate metrics + new header
- `home_task_sections.dart` - Add metrics calculation
- `home_task_inbox.dart` - Enhanced activity items with quick actions
- `today_activity.dart` - Add computed properties for metrics

### Test Files
- `home_task_sections_test.dart` - Unit tests for grouping
- `task_section_metrics_test.dart` - Metrics calculation tests
- `home_page_integration_test.dart` - E2E flows

---

## Timeline

| Phase | Effort | Duration |
|-------|--------|----------|
| Data Model + Header | 2h | 1 session |
| Activity Item Enhancement | 2h | 1 session |
| HomePage Integration | 3h | 1.5 sessions |
| Test Coverage | 3h | 1.5 sessions |
| **Total** | **10h** | **3-4 sessions** |

