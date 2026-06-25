# Guía de Implementación: Selección Múltiple de Frentes

## Resumen

Permite seleccionar **más de un frente** o **todos los frentes** al crear una asignación de actividad, en lugar del dropdown único anterior.

---

## Cambios Realizados

### 1. Frontend Flutter — `planning_page.dart`

#### Campos de estado agregados
```dart
List<String> _selectedFrontIds = [];  // Frentes seleccionados individually
bool _allFronts = false;              // Flag "todos los frentes"
```

#### UI del selector múltiple
- **Checkbox "Todos los frentes"** en la parte superior
- **Lista de checkboxes** para cada frente individual (altura 160px, scrollable)
- Al seleccionar un frente individual, se sincroniza la cobertura (estado/municipio) del primer frente seleccionado

#### Validación actualizada (`_canProceedToNextStep`)
```dart
final hasFront = _allFronts || _selectedFrontIds.isNotEmpty || (_frontId != null && _frontId!.trim().isNotEmpty);
```

#### Mensaje de error actualizado
```dart
'Selecciona al menos un ${frontTerminology(widget.projectId)} o marca "Todos".'
```

#### Llamada al repository (`_submit`)
```dart
await repo.createAssignment(
  ...
  frontIds: _selectedFrontIds,  // NUEVO
  allFronts: _allFronts,         // NUEVO
  ...
);
```

---

### 2. Frontend Flutter — `assignments_repository.dart`

#### Firma del método actualizada
```dart
Future<void> createAssignment({
  ...
  List<String>? frontIds,
  bool? allFronts,
  ...
})
```

#### Payload enviado al backend
```dart
payload['front_ids'] = frontIds ?? [];
payload['all_fronts'] = allFronts ?? false;
```

---

### 3. Backend Python — `assignments.py`

#### Schema `AssignmentCreate` actualizado
```python
class AssignmentCreate(BaseModel):
    ...
    front_ids: Optional[List[str]] = Field(default=[], description="Lista de IDs de frentes")
    all_fronts: bool = Field(default=False, description="Si True, asigna a todos los frentes")
```

#### Endpoint POST `/assignments` actualizado
```python
@router.post("/assignments", response_model=...)
async def create_assignment(...):
    # Si all_fronts=True, obtener todos los frentes del proyecto
    # Si front_ids tiene valores, usar esos frentes específicos
    # Crear una actividad por cada frente seleccionado
    # (o una sola actividad con front_ids populated)
```

---

## Comportamiento Esperado

| Escenario | Resultado |
|-----------|-----------|
| Checkbox "Todos" marcado | `_allFronts=true`, `_selectedFrontIds=[]` |
| 1+ frentes seleccionados | `_allFronts=false`, `_selectedFrontIds=[...]` |
| Solo `_frontId` legacy | Compatibilidad hacia atrás, `frontIds=[_frontId]`, `allFronts=false` |
| Ningún frente seleccionado | Error de validación |

---

## Próximos Pasos (pendientes)

1. **Backend**: Modificar lógica de negocio para crear actividades por cada frente cuando hay múltiples frentes
2. **Frontend**: Mostrar todos los frentes asignados en la vista de detalle de la actividad
3. **Filtros**: Permitir filtrar actividades por frente en la vista de planeación
4. **Reports**: Incluir `front_ids` en la generación de reportes

---

## Notas

- La funcionalidad de **crear múltiples actividades** (una por frente) en el backend aún no está implementada
- El dropdown de frente individual (`_frontId`) se mantiene para compatibilidad pero está oculto tras el nuevo selector múltiple
- La cobertura de estado/municipio se sincroniza con el **primer frente seleccionado** de `_selectedFrontIds`
