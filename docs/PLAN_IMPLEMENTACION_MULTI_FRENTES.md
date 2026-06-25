# Plan de Implementación: Selección Múltiple de Frentes en Asignación de Actividades

## Resumen
Permitir que al crear una asignación de actividad, el usuario pueda seleccionar:
1. **Múltiples frentes específicos** - seleccionando IDs de frentes de una lista
2. **Todos los frentes** - usando una bandera `all_fronts=true`

---

## Backend (Completado ✅)

### 1. Schema `AssignmentCreate` (`backend/app/schemas/assignment.py`)
```python
class AssignmentCreate(BaseModel):
    # ... campos existentes ...
    
    # Single front (backward compatibility)
    front_id: UUID | None = None
    front_ref: str | None = None
    
    # Multiple fronts selection (NUEVO)
    front_ids: list[UUID] = Field(
        default_factory=list,
        description="Lista de IDs de frentes a asignar. Si 'all_fronts' es true, este campo se ignora."
    )
    all_fronts: bool = Field(
        default=False,
        description="Si true, se crea una asignación por cada frente del proyecto."
    )
```

### 2. Endpoint `POST /assignments` (`backend/app/api/v1/assignments.py`)
- Nueva función `_resolve_front_ids_to_assign()` que determina qué frentes asignar
- El endpoint ahora retorna `list[AssignmentListItem]` en lugar de un solo item
- Lógica para crear una actividad por frente seleccionado
- Cada actividad tiene `activity_group_id` para agruparlas lógicamente
- Campo `is_primary_responsible` para identificar la actividad principal del grupo

---

## Frontend (Pendiente)

### Archivos a Modificar

#### 1. Repository/Provider de Asignaciones
- **Ubicación**: `desktop_flutter/sao_desktop/lib/data/repositories/assignment_repository.dart` o similar
- **Cambios**:
  - Actualizar método `createAssignment()` para aceptar `List<String> frontIds` y `bool allFronts`
  - El payload enviado al backend debe incluir `front_ids` o `all_fronts`

#### 2. Modelo de Asignación (Flutter)
- **Ubicación**: `desktop_flutter/sao_desktop/lib/domain/models/` o `lib/data/models/`
- **Cambios**:
  - Agregar campos `frontIds` y `allFronts` al modelo de creación

#### 3. UI de Creación de Asignación
- **Ubicación**: Widget de formulario de creación (ej: `AssignmentForm` o similar)
- **Cambios**:
  - Agregar selector de frentes múltiples (ej: `CheckboxListTile` o `MultiSelect`)
  - Agregar opción "Todos los frentes" con checkbox
  - Mostrar indicador visual cuando `all_fronts=true`

---

## Ejemplo de Payload API

### Selección de frentes específicos:
```json
POST /api/v1/assignments
{
  "project_id": "TMQ",
  "assignee_user_id": "uuid-del-usuario",
  "activity_type_code": "REUNION",
  "front_ids": ["uuid-frente-1", "uuid-frente-2", "uuid-frente-3"],
  "all_fronts": false,
  "start_at": "2026-06-20T09:00:00Z",
  "end_at": "2026-06-20T10:00:00Z"
}
```

### Todos los frentes:
```json
POST /api/v1/assignments
{
  "project_id": "TMQ",
  "assignee_user_id": "uuid-del-usuario",
  "activity_type_code": "REUNION",
  "front_ids": [],
  "all_fronts": true,
  "start_at": "2026-06-20T09:00:00Z",
  "end_at": "2026-06-20T10:00:00Z"
}
```

---

## Comportamiento Esperado

1. **Sin frentes seleccionados**: Error `ASSIGNMENT_FRONT_REQUIRED`
2. **`front_ids` vacío + `all_fronts=false`**: Error `ASSIGNMENT_FRONT_REQUIRED`
3. **`all_fronts=true`**: El backend consulta la colección `fronts` y crea una actividad por cada frente del proyecto
4. **`front_ids` con valores**: El backend resuelve los nombres de frente y crea una actividad por cada ID
5. **Compatibilidad hacia atrás**: Si solo se usa `front_id` (singular), funciona como antes

---

## Frontend - Guía de Implementación

### Archivo: `desktop_flutter/sao_desktop/lib/features/planning/planning_page.dart`

#### Ubicación del diálogo de creación: `_CreateAssignmentDialog` (~línea 1878)

#### Campos a agregar/modificar:

1. **Estado del widget** - Agregar campos:
```dart
// NUEVO: Para selección múltiple de frentes
List<String> _selectedFrontIds = [];  // Lista de IDs seleccionados
bool _allFronts = false;             // Flag para todos los frentes
```

2. **En `_loadFrontsAndCoverage()`** - Ya carga los frentes en `_fronts`

3. **En `createAssignment()` (línea 1878)** - Modificar llamada:
```dart
await repo.createAssignment(
  // ... campos existentes ...
  frontId: _frontId,  // Mantener para backward compatibility
  // NUEVO: Pasar múltiples frentes
  frontIds: _selectedFrontIds,  // Lista de frentes seleccionados
  allFronts: _allFronts,        // Flag para todos
);
```

4. **Selector de frentes** - Reemplazar `DropdownButtonFormField` por `CheckboxListTile` con:
   - Opción "Todos los frentes" (checkbox)
   - Lista de frentes con checkboxes individuales

### Ejemplo de UI sugerida:

```dart
// Reemplazar el DropdownButtonFormField existente por:
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    // Opción "Todos"
    CheckboxListTile(
      title: const Text('Todos los frentes'),
      value: _allFronts,
      onChanged: (value) {
        setState(() {
          _allFronts = value ?? false;
          if (_allFronts) {
            _selectedFrontIds = _fronts.map((f) => f.id).toList();
          }
        });
      },
    ),
    const Divider(),
    // Lista de frentes
    Expanded(
      child: ListView.builder(
        itemCount: _fronts.length,
        itemBuilder: (context, index) {
          final front = _fronts[index];
          return CheckboxListTile(
            title: Text(front.name),
            value: _selectedFrontIds.contains(front.id),
            onChanged: (selected) {
              setState(() {
                if (selected == true) {
                  _selectedFrontIds.add(front.id);
                } else {
                  _selectedFrontIds.remove(front.id);
                }
              });
            },
          );
        },
      ),
    ),
  ],
)
```

### Cambios en la validación:

```dart
bool _canProceedToNextStep() {
  // Modificar validación de frente
  final hasFronts = _allFronts || 
                    (_selectedFrontIds.isNotEmpty) ||
                    (_frontId != null && _frontId!.isNotEmpty);
  if (!hasFronts) {
    return 'Selecciona al menos un frente o marca "Todos".';
  }
  // ... resto de validaciones
}
```

---

## Resumen de Archivos Modificados

| Archivo | Tipo de Cambio | Estado |
|---------|---------------|--------|
| `backend/app/schemas/assignment.py` | Schema con `front_ids`, `all_fronts` | ✅ Completado |
| `backend/app/api/v1/assignments.py` | Endpoint con lógica multi-frente | ✅ Completado |
| `desktop_flutter/.../assignments_repository.dart` | Repository con nuevos params | ✅ Completado |
| `desktop_flutter/.../planning_page.dart` | UI selector múltiple frentes | ⏳ Pendiente |

---

## Pruebas Recomendadas

1. **Single front** (backward compatibility): Crear asignación con un frente
2. **Multiple fronts**: Seleccionar 2-3 frentes específicos
3. **All fronts**: Marcar "Todos los frentes" y verificar que se crean N actividades
4. **Verificar notifications**: Cada actividad creada debe generar notificación al responsable
5. **Verificar grouping**: Las actividades múltiples deben tener el mismo `activity_group_id`
