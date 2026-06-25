# Guía: Selección Múltiple de Frentes al Asignar Actividades

**Versión:** 1.0  
**Fecha:** Junio 2026  
**Estado:** ✅ Implementado y probado  
**Plataformas:** Desktop (primario), móvil (pendiente)

---

## Descripción

La funcionalidad de **selección múltiple de frentes** permite asignar una actividad a **múltiples frentes simultáneamente** o a **todos los frentes del proyecto**, en lugar de limitarse a un único frente.

Cuando se crea una asignación con múltiples frentes, el backend genera **una actividad por cada frente y participante**, garantizando que cada responsable tenga su propia línea de seguimiento para cada frente.

---

## Flujo de Uso (Desktop)

### Paso 1: Abrir Diálogo de Asignación
1. En la pantalla de **Planeación** (Planning), haz clic en el botón **"+ Asignar"**
2. Se abre el diálogo de creación de asignación

### Paso 2: Seleccionar Responsables (Paso 1/3)
- Selecciona uno o más responsables (operativos)
- Puedes agregar co-responsables usando el botón **"Agregar co-responsable"**

### Paso 3: Configurar Detalles (Paso 2/3)

#### Opción A: Asignar a UN Frente Específico
- **Deja desmarcado** el checkbox "Todos los frentes"
- Selecciona UN frente de la lista
- La cobertura (estado/municipio) se autosinconiza con ese frente

#### Opción B: Asignar a MÚLTIPLES Frentes Específicos
- **Deja desmarcado** el checkbox "Todos los frentes"
- Marca los checkboxes de los frentes que deseas
- La cobertura se sincroniza con el **primer frente seleccionado**
- Puedes seleccionar varios frentes en la lista scrollable

#### Opción C: Asignar a TODOS los Frentes
- Marca el checkbox **"Todos los frentes"**
- Se deseleccionarán los frentes individuales automáticamente
- Se generará una actividad por cada frente del proyecto
- No necesitas especificar cobertura (se obtiene del frente)

### Paso 4: Configurar Ubicación
- **PK** (puntual, tramo)
- **Lugar** (referencia de ubicación)
- Cargar cobertura manualmente si es necesario

### Paso 5: Completar Asignación (Paso 3/3)
- Define horarios de inicio y fin
- Especifica nivel de riesgo
- Haz clic en **"Asignar"**

---

## Resultado: Qué Sucede en el Backend

### Caso 1: Un Frente, Un Responsable
```
Entrada: front_ids=[UUID_A], all_fronts=false
Resultado: 1 actividad creada
├── Frente A → Responsable 1
```

### Caso 2: Múltiples Frentes, Un Responsable
```
Entrada: front_ids=[UUID_A, UUID_B, UUID_C], all_fronts=false
Resultado: 3 actividades creadas
├── Frente A → Responsable 1
├── Frente B → Responsable 1
└── Frente C → Responsable 1
```

### Caso 3: Todos los Frentes, Un Responsable
```
Entrada: all_fronts=true
Resultado: N actividades (N = cantidad de frentes en el proyecto)
├── Frente 1 → Responsable 1
├── Frente 2 → Responsable 1
├── Frente 3 → Responsable 1
└── ... (todos los frentes del proyecto)
```

### Caso 4: Múltiples Frentes, Múltiples Responsables
```
Entrada: front_ids=[UUID_A, UUID_B], assignee_user_ids=[ID_1, ID_2]
Resultado: 4 actividades creadas (2 frentes × 2 responsables)
├── Frente A → Responsable 1
├── Frente A → Responsable 2 (co-responsable)
├── Frente B → Responsable 1
└── Frente B → Responsable 2 (co-responsable)
```

---

## Características Clave

### ✅ Sincronización de Cobertura
- Al cambiar de frente, el estado/municipio se actualiza automáticamente
- Usa la cobertura del **primer frente seleccionado**
- Permite geocodificación automática

### ✅ Validación Inteligente
- Requiere al menos 1 frente
- Valida que estado/municipio sean válidos para el frente
- Detecta conflictos de horario

### ✅ Auditoría Completa
- Cada actividad registra los frentes asignados
- Historial de cambios de frentes disponible
- Trazabilidad por participante

### ✅ Notificaciones
- Cada participante recibe notificación **por cada frente asignado**
- Notificación de co-responsable si aplica
- Diferenciación entre responsable principal y co-responsables

---

## API Backend

### Endpoint POST `/api/v1/assignments`

#### Payload

```json
{
  "project_id": "TMQ",
  "assignee_user_id": "uuid-responsable-principal",
  "assignee_user_ids": ["uuid-responsable", "uuid-co-responsable"],
  "activity_type_code": "INSP_CIVIL",
  "title": "Inspección Civil",
  "front_ids": ["uuid-frente-1", "uuid-frente-2"],
  "all_fronts": false,
  "estado": "Durango",
  "municipio": "Durango",
  "pk": 5000,
  "start_at": "2026-06-20T09:00:00Z",
  "end_at": "2026-06-20T11:00:00Z",
  "risk": "bajo"
}
```

#### Parámetros

| Campo | Tipo | Obligatorio | Descripción |
|-------|------|-----------|-------------|
| `project_id` | string | ✅ | ID del proyecto (TMQ, TAP, etc.) |
| `assignee_user_id` | UUID | ✅ | ID del responsable principal |
| `assignee_user_ids` | UUID[] | ❌ | IDs de co-responsables |
| `activity_type_code` | string | ✅ | Código del tipo de actividad (INSP_CIVIL, REU, etc.) |
| `title` | string | ❌ | Título personalizado |
| **`front_ids`** | UUID[] | ❌ | **IDs de frentes específicos** |
| **`all_fronts`** | bool | ❌ | **Si true, asigna a TODOS los frentes** |
| `front_id` | UUID | ❌ | Legado: único frente (deprecated) |
| `front_ref` | string | ❌ | Legado: referencia de frente (deprecated) |
| `estado` | string | ❌ | Estado (sincronizado con frente) |
| `municipio` | string | ❌ | Municipio (sincronizado con frente) |
| `pk` | int | ❌ | Punto kilométrico |
| `start_at` | datetime | ✅ | Hora de inicio |
| `end_at` | datetime | ✅ | Hora de fin |
| `risk` | string | ❌ | Nivel de riesgo (bajo/medio/alto) |

#### Respuesta

```json
[
  {
    "id": "uuid-actividad-1",
    "project_id": "TMQ",
    "assignee_user_id": "uuid-responsable",
    "title": "Inspección Civil",
    "frente": "Frente Sur",
    "estado": "Durango",
    "municipio": "Durango",
    "pk": 5000,
    "start_at": "2026-06-20T09:00:00Z",
    "end_at": "2026-06-20T11:00:00Z",
    "status": "PROGRAMADA",
    "risk": "bajo"
  },
  {
    "id": "uuid-actividad-2",
    "project_id": "TMQ",
    "assignee_user_id": "uuid-responsable",
    "title": "Inspección Civil",
    "frente": "Frente Centro",
    "estado": "Durango",
    "municipio": "Durango",
    "pk": 5000,
    "start_at": "2026-06-20T09:00:00Z",
    "end_at": "2026-06-20T11:00:00Z",
    "status": "PROGRAMADA",
    "risk": "bajo"
  }
]
```

---

## Casos de Uso Comunes

### 🏗️ Inspección de Toda la Carretera
```
Supervisor crea inspección civil:
- Selecciona: "Todos los frentes"
- Resultado: Una actividad de inspección por cada frente
- Beneficio: Visibilidad de avance por frente
```

### 👥 Actividad Regional Multi-Frente
```
Inspector debe atender 3 sectores:
- Selecciona: Frente 1, Frente 2, Frente 3
- Co-responsable: Peón regional
- Resultado: 6 actividades (3 frentes × 2 responsables)
- Beneficio: Seguimiento individual sin perder contexto regional
```

### 📋 Reunión de Coordinación Multi-Frente
```
Coordinador convoca reunión con supervisores de 2 frentes:
- Selecciona: Frente A, Frente B
- Participantes: Supervisor A, Supervisor B
- Resultado: 4 actividades (2 frentes × 2 supervisores)
- Beneficio: Cada supervisor ve la reunión en su frente
```

---

## Consideraciones de Diseño

### 📌 Grouping de Actividades
- Múltiples actividades vinculadas por `activity_group_id`
- Permite rastrear actividades relacionadas
- Útil para reportes y análisis

### 🔄 Sincronización de Estado
- Cambios en UNA actividad NO afectan otras del mismo grupo
- Cada frente tiene su propio estado de ejecución
- Auditoría independiente por actividad

### 📊 Reporting
- Se puede filtrar/agrupar por `activity_group_id`
- Campos de frente siempre disponibles
- Logs de auditoría con detalles de multi-frentes

---

## Limitaciones y Futuro

### ✅ Implementado
- [x] Desktop UI con selección múltiple
- [x] Backend: creación de múltiples actividades
- [x] Validación de frentes
- [x] Auditoría y notificaciones

### 📋 Planeado (Futuro)
- [ ] Móvil: soporte para multi-frentes (actualmente solo `front_ref` texto)
- [ ] Filtro por frentes en vistas de actividades
- [ ] Reportes consolidados por frente
- [ ] Edición grupal de frentes asignados

---

## Preguntas Frecuentes

### P: ¿Se puede cambiar de frente después de asignar?
**R:** No. Cada actividad es independiente. Para cambiar, cancela y crea una nueva asignación.

### P: ¿Qué pasa con la auditoría?
**R:** Se registra en entrada: `details.num_fronts_assigned` y `activity_group_id`.

### P: ¿Se puede asignar a 0 frentes?
**R:** No. El backend rechaza: "At least one front is required".

### P: ¿El "Todos los frentes" incluye frentes futuros?
**R:** No. Solo los frentes del proyecto **en ese momento**. Frentes creados después no se incluyen.

### P: ¿Puedo mezclar "Todos" con frentes específicos?
**R:** No. Si marcas "Todos los frentes", se ignoran los frentes específicos.

---

## Validación Técnica

### Tests Pasando
- ✅ 16/16 tests de assignment
- ✅ Creación multi-frente
- ✅ Validación de frentes
- ✅ Auditoría correcta
- ✅ Notificaciones generadas

### URLs Referencias
- [Endpoint POST `/assignments`](../backend/app/api/v1/assignments.py#L771)
- [Schema AssignmentCreate](../backend/app/schemas/assignment.py)
- [Planning Dialog Desktop](../desktop_flutter/sao_desktop/lib/features/planning/planning_page.dart)

