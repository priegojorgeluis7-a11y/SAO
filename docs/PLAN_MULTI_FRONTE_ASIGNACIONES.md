# Plan de Implementación: Selección Múltiple de Frentes en Asignación de Actividades

## Resumen Ejecutivo

Permitir que al crear una asignación de actividad, el usuario pueda seleccionar **más de un frente** o **todos los frentes** del proyecto, generando una actividad por cada frente seleccionado.

---

## 1. Estado Actual del Sistema

### 1.1 Backend (Python/FastAPI)

**Archivo**: `backend/app/schemas/assignment.py`
```python
class AssignmentCreate(BaseModel):
    front_id: UUID | None = None
    front_ref: str | None = Field(default=None, max_length=255)
    # ... otros campos
```

**Archivo**: `backend/app/api/v1/assignments.py`
- `create_assignment()` → Crea UNA actividad por llamada
- El campo `frente` se guarda directamente en el documento de actividad

### 1.2 Frontend (Flutter)

**Archivo**: `planning_page.dart` (línea ~507)
```dart
String? _frontId;  // Solo un frente
```

**UI de selección** (línea ~1232):
```dart
DropdownButtonFormField<String>(
    initialValue: _frontId,
    // ... dropdown simple de un solo valor
)
```

---

## 2. Arquitectura Propuesta

### Decisión de Diseño Clave

**Opción elegida**: Crear **MÚLTIPLES asignaciones** (una por cada frente seleccionado)

**Razón**: El modelo de datos actual tiene `frente` como campo desnormalizado en cada documento de actividad. Mantener este patrón asegura:
- Consistencia con queries existentes (filtrar por `frente`)
- Compatibilidad con reportes y vistas
- Simplicidad en la lógica de negocio

---

## 3. Plan de Implementación

### Fase 1: Backend

#### 3.1.1 Actualizar Schema de Assignment

**Archivo**: `backend/app/schemas/assignment.py`

```python
class AssignmentCreate(BaseModel):
    # ... campos existentes ...
    
    # NUEVOS CAMPOS PARA SELECCIÓN MÚLTIPLE
    front_ids: list[UUID] = Field(
        default_factory=list,
        description="Lista de IDs de frentes a asignar. Si 'all_fronts' es true, este campo se ignora."
    )
    all_fronts: bool = Field(
        default=False,
        description="Si true, se crea una asignación por cada frente del proyecto."
    )
    
    # Mantener para backward compatibility (deprecated)
    front_id: UUID | None = None
    
    @field_validator('front_ids')
    @classmethod
    def validate_front_ids(cls, v, info):
        if not v:
            return v
        # Validar que no haya duplicados
        return list(set(v))
```

#### 3.1.2 Modificar Endpoint de Creación

**Archivo**: `backend/app/api/v1/assignments.py`

```python
@router.post("", response_model=list[AssignmentListItem], status_code=status.HTTP_201_CREATED)
async def create_assignment(
    payload: AssignmentCreate,
    current_user = Depends(require_assignment_manager),
):
    # ... validación existente ...
    
    # NUEVA LÓGICA: Determinar frentes a asignar
    front_ids_to_assign = []
    
    if payload.all_fronts:
        # Query todos los frentes del proyecto
        fronts_docs = client.collection("fronts")\
            .where("project_id", "==", project_id)\
            .stream()
        front_ids_to_assign = [doc.id for doc in fronts_docs]
    elif payload.front_ids:
        # Usar los frentes seleccionados
        front_ids_to_assign = [str(fid) for fid in payload.front_ids]
    elif payload.front_id:
        # Backward compatibility: frente único legacy
        front_ids_to_assign = [str(payload.front_id)]
    else:
        raise api_error("FRONT_REQUIRED", "Selecciona al menos un frente.")
    
    # Crear UNA asignación por cada frente
    created_assignments = []
    for front_id in front_ids_to_assign:
        assignment = await _create_single_assignment(
            client=client,
            project_id=project_id,
            front_id=front_id,
            # ... otros parámetros comunes
        )
        created_assignments.append(assignment)
    
    return created_assignments
```

#### 3.1.3 Función Auxiliar para Crear Asignación Individual

```python
async def _create_single_assignment(
    client,
    project_id: str,
    front_id: str,
    activity_type_code: str,
    start_at: datetime,
    end_at: datetime,
    assignee_user_ids: list[str],
    # ... otros parámetros
) -> AssignmentListItem:
    """Crea una única asignación vinculada a un frente específico."""
    
    # Obtener nombre del frente
    front_doc = client.collection("fronts").document(front_id).get()
    front_name = front_doc.get("name", "") if front_doc.exists else ""
    
    # ... lógica existente de creación ...
    
    return AssignmentListItem(
        frente=front_name,
        # ... otros campos
    )
```

#### 3.1.4 Actualizar Notificaciones

```python
# Enviar notificación a cada assignee por cada frente
for front_id in front_ids_to_assign:
    for participant_id in assignee_user_ids:
        await notify_new_assignment(
            project_id=project_id,
            recipient_user_id=participant_id,
            activity_id=str(p_uuid),
            activity_title=title,
            frente=front_names_map.get(front_id, ""),
            start_at=start_at.isoformat(),
        )
```

---

### Fase 2: Frontend (Flutter)

#### 3.2.1 Actualizar Modelo de Datos

**Archivo**: `lib/data/repositories/assignments_repository.dart`

```dart
// Agregar método para crear múltiples asignaciones
Future<List<AssignmentItem>> createBulkAssignments({
  required String projectId,
  required List<String> assigneeUserIds,
  required String activityTypeCode,
  required DateTime startAt,
  required DateTime endAt,
  String? title,
  required List<String> frontIds,      // NUEVO: lista de frentes
  bool allFronts = false,               // NUEVO: opción "todos"
  String? estado,
  String? municipio,
  String? colonia,
  int pk = 0,
  String risk = 'bajo',
  double? latitude,
  double? longitude,
}) async {
  final decoded = await _client.postJson('/api/v1/assignments', {
    'project_id': projectId,
    'assignee_user_ids': assigneeUserIds,
    'activity_type_code': activityTypeCode,
    'start_at': startAt.toUtc().toIso8601String(),
    'end_at': endAt.toUtc().toIso8601String(),
    if (title != null) 'title': title,
    'front_ids': frontIds,
    'all_fronts': allFronts,
    if (estado != null) 'estado': estado,
    if (municipio != null) 'municipio': municipio,
    if (colonia != null) 'colonia': colonia,
    'pk': pk,
    'risk': risk,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
  });
  
  // El backend devuelve lista de asignaciones creadas
  if (decoded is List) {
    return decoded
        .map((e) => AssignmentItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
  return [AssignmentItem.fromJson((decoded as Map).cast<String, dynamic>())];
}
```

#### 3.2.2 Actualizar Estado del Diálogo

**Archivo**: `lib/features/planning/planning_page.dart`

```dart
class _CreateAssignmentDialogState extends ConsumerState<_CreateAssignmentDialog> {
  // CAMBIAR de:
  // String? _frontId;
  
  // A:
  List<String> _selectedFrontIds = [];  // Lista de frentes seleccionados
  
  // NUEVO: Bandera para "todos los frentes"
  bool _assignToAllFronts = false;
  
  // ... resto del código ...
}
```

#### 3.2.3 Nueva UI de Selección Múltiple de Frentes

**Reemplazar el DropdownButtonFormField actual** (línea ~1232) con:

```dart
Widget _buildFrontSelection() {
  final selectedCount = _assignToAllFronts 
      ? _fronts.length 
      : _selectedFrontIds.length;
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Header con opción "Todos"
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _assignToAllFronts 
              ? SaoColors.primary.withValues(alpha: 0.1) 
              : null,
          border: Border(
            bottom: BorderSide(
              color: SaoColors.border,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: _assignToAllFronts,
              onChanged: (value) {
                setState(() {
                  _assignToAllFronts = value ?? false;
                  if (_assignToAllFronts) {
                    _selectedFrontIds = [];
                  }
                });
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _assignToAllFronts 
                    ? 'Todos los frentes (${_fronts.length})'
                    : 'Seleccionar frentes específicos',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _assignToAllFronts 
                      ? SaoColors.primary 
                      : SaoColors.textFor(context),
                ),
              ),
            ),
            if (!_assignToAllFronts)
              Text(
                '$selectedCount seleccionado${selectedCount == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 12,
                  color: SaoColors.textMutedFor(context),
                ),
              ),
          ],
        ),
      ),
      
      // Lista de frentes (solo si NO está "todos")
      if (!_assignToAllFronts)
        SizedBox(
          height: 200,
          child: _fronts.isEmpty
              ? Center(
                  child: Text(
                    'No hay frentes disponibles',
                    style: TextStyle(color: SaoColors.gray500),
                  ),
                )
              : ListView.builder(
                  itemCount: _fronts.length,
                  itemBuilder: (context, index) {
                    final front = _fronts[index];
                    final isSelected = _selectedFrontIds.contains(front.id);
                    
                    return CheckboxListTile(
                      value: isSelected,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(front.name),
                      subtitle: front.code.isNotEmpty
                          ? Text(
                              front.code,
                              style: TextStyle(
                                fontSize: 11,
                                color: SaoColors.gray500,
                              ),
                            )
                          : null,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            if (!_selectedFrontIds.contains(front.id)) {
                              _selectedFrontIds.add(front.id);
                            }
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
  );
}
```

#### 3.2.4 Sincronizar Cobertura para Múltiples Frentes

```dart
void _syncCoverageForMultipleFronts() {
  if (_assignToAllFronts) {
    // Mergear cobertura de TODOS los frentes
    final allEstados = <String>{};
    final allMunicipios = <String, Set<String>>{};
    
    for (final frontId in _fronts.map((f) => f.id)) {
      final coverage = _coverageForFront(frontId);
      for (final item in coverage) {
        allEstados.add(item.estado);
        allMunicipios.putIfAbsent(item.estado, () => {});
        allMunicipios[item.estado]!.add(item.municipio);
      }
    }
    
    _estadoOptions = allEstados.toList()..sort();
    _municipioOptions = _municipioOptions = _selectedEstado != null
        ? (allMunicipios[_selectedEstado]?.toList() ?? [])..sort()
        : [];
        
  } else if (_selectedFrontIds.isNotEmpty) {
    // Mergear cobertura de frentes seleccionados
    final mergedEstados = <String>{};
    final mergedMunicipios = <String, Set<String>>{};
    
    for (final frontId in _selectedFrontIds) {
      final coverage = _coverageForFront(frontId);
      for (final item in coverage) {
        mergedEstados.add(item.estado);
        mergedMunicipios.putIfAbsent(item.estado, () => {});
        mergedMunicipios[item.estado]!.add(item.municipio);
      }
    }
    
    _estadoOptions = mergedEstados.toList()..sort();
    _municipioOptions = _selectedEstado != null
        ? (mergedMunicipios[_selectedEstado]?.toList() ?? [])..sort()
        : [];
  } else {
    _estadoOptions = [];
    _municipioOptions = [];
  }
}
```

#### 3.2.5 Actualizar Validación

```dart
bool _canProceedToNextStep() {
  switch (_currentStep) {
    case 1:
      // ... otras validaciones ...
      
      // NUEVA validación de frentes
      final hasFronts = _assignToAllFronts || _selectedFrontIds.isNotEmpty;
      if (!hasFronts) {
        return false;
      }
      
      return hasActivityType && hasFronts && hasPk && hasEstado && hasMunicipio;
    // ...
  }
}

String _requiredErrorForCurrentStep() {
  switch (_currentStep) {
    case 1:
      // ... otras validaciones ...
      if (!_assignToAllFronts && _selectedFrontIds.isEmpty) {
        return 'Selecciona ${frontTerminology(widget.projectId)} o marca "Todos".';
      }
    // ...
  }
}
```

#### 3.2.6 Actualizar Submit

```dart
Future<void> _submit() async {
  // ... validaciones previas ...
  
  try {
    final repo = ref.read(assignmentsRepositoryProvider);
    
    final results = await repo.createBulkAssignments(
      projectId: widget.projectId,
      assigneeUserIds: _assigneeIds,
      activityTypeCode: effectiveActivityTypeCode,
      startAt: startAt,
      endAt: endAt,
      title: effectiveTitle,
      frontIds: _assignToAllFronts ? [] : _selectedFrontIds,  // Lista vacía + flag
      allFronts: _assignToAllFronts,  // Bandera para backend
      estado: _selectedEstado,
      municipio: _selectedMunicipio,
      colonia: _coloniaController.text.trim().isNotEmpty 
          ? _coloniaController.text.trim() 
          : null,
      pk: effectivePk,
      risk: 'bajo',
      latitude: _lat,
      longitude: _lon,
    );
    
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  } catch (e) {
    // manejo de errores...
  }
}
```

---

### Fase 3: Pruebas

#### 3.3.1 Backend Tests

```python
# tests/test_assignments_multi_front.py

def test_create_assignment_with_multiple_fronts():
    """Debe crear una asignación por cada frente seleccionado."""
    # Arrange
    front1_id = str(uuid4())
    front2_id = str(uuid4())
    
    # Act
    results = create_assignment(
        payload=AssignmentCreate(
            front_ids=[front1_id, front2_id],
            # ... otros campos
        )
    )
    
    # Assert
    assert len(results) == 2
    assert results[0].frente != results[1].frente

def test_create_assignment_all_fronts():
    """Debe crear una asignación por cada frente del proyecto."""
    # Arrange
    project_id = "TMQ"
    
    # Act
    results = create_assignment(
        payload=AssignmentCreate(
            all_fronts=True,
            # ... otros campos
        )
    )
    
    # Assert
    # Verificar que se creó una asignación por cada frente del proyecto
```

#### 3.3.2 UI Tests

```dart
testWidgets('permite seleccionar múltiples frentes', (tester) async {
  await tester.pumpWidget(createTestWidget());
  
  // Abrir diálogo de asignación
  await tester.tap(find.text('Asignar actividad'));
  await tester.pumpAndSettle();
  
  // Verificar que existe la opción "Todos los frentes"
  expect(find.text('Todos los frentes'), findsOneWidget);
  
  // Seleccionar frente individual
  await tester.tap(find.text('Frente 1'));
  await tester.pumpAndSettle();
  
  // Verificar que se actualizó el contador
  expect(find.text('1 seleccionado'), findsOneWidget);
});
```

---

## 4. Diagramas de Flujo

### 4.1 Flujo de Creación de Asignación

```
┌─────────────────────────────────────────────────────────────┐
│                    CREAR ASIGNACIÓN                         │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  ¿Usuario selecciona "Todos los frentes"?                  │
└─────────────────────────────────────────────────────────────┘
                    │                     │
                   SÍ                    NO
                    │                     │
                    ▼                     ▼
┌──────────────────────────┐  ┌────────────────────────────────┐
│ Query: fronts del proyecto│  │ Usar front_ids seleccionados  │
└──────────────────────────┘  └────────────────────────────────┘
                    │                     │
                    └──────────┬──────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│           Para cada frente en la lista:                    │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  1. Obtener nombre del frente                        │  │
│  │  2. Crear documento en /activities                   │  │
│  │  3. Establecer campo 'frente' = nombre_del_frente   │  │
│  │  4. Enviar notificaciones                            │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│  Devolver lista de AssignmentListItem creadas             │
└─────────────────────────────────────────────────────────────┘
```

---

## 5. Consideraciones Adicionales

### 5.1 Backward Compatibility
- Mantener `front_id` como campo opcional
- Si viene `front_id` (sin `front_ids` ni `all_fronts`), comportarse como antes

### 5.2 Permisos
- Verificar que el usuario tenga permisos de asignación
- Para "todos los frentes", requerir rol de supervisor/coordinador

### 5.3 Performance
- El endpoint crea N documentos secuencialmente
- Para proyectos con muchos frentes, considerar batch operations
- Las notificaciones se envían en paralelo

### 5.4 Impacto en Migraciones
- No requiere migración de datos existentes
- Los documentos actuales mantienen su `frente` individual

---

## 6. Historias de Usuario

### HU-1: Selección Individual de Frentes
> Como supervisor, quiero poder seleccionar 2 o más frentes específicos al crear una asignación, para no repetir la misma actividad manualmente.

**Criterios de Aceptación**:
- [ ] Puedo seleccionar frentes individuales con checkboxes
- [ ] El contador muestra "N frentes seleccionados"
- [ ] La cobertura se合并 correctamente
- [ ] Se crean N asignaciones, una por cada frente

### HU-2: Asignar a Todos los Frentes
> Como coordinador, quiero marcar "todos los frentes" con un solo clic, para asignar la actividad a todo el proyecto.

**Criterios de Aceptación**:
- [ ] Hay un checkbox para "Todos los frentes"
- [ ] Al marcar, se limpian las selecciones individuales
- [ ] El badge muestra "Todos los frentes (N)"
- [ ] Se crea una asignación por cada frente del proyecto

---

## 7. Estimación de Esfuerzo

| Fase | Componente | Estimación |
|------|-----------|------------|
| 1.1 | Schema + Tests | 2 horas |
| 1.2 | Endpoint + Lógica | 4 horas |
| 2.1 | Repository | 1 hora |
| 2.2 | Estado Dialog | 1 hora |
| 2.3 | UI Múltiple Selección | 4 horas |
| 2.4 | Submit + Validación | 2 horas |
| 3 | Pruebas | 3 horas |
| **TOTAL** | | **~17 horas** |

---

## 8. Archivos a Modificar

### Backend
- `backend/app/schemas/assignment.py`
- `backend/app/api/v1/assignments.py`
- `backend/tests/test_assignments_multi_front.py` (nuevo)

### Frontend
- `lib/data/repositories/assignments_repository.dart`
- `lib/features/planning/planning_page.dart`
- `test/features/planning/planning_page_test.dart` (nuevo/actualizar)

---

*Documento generado: $(date)*
*Versión: 1.0*
