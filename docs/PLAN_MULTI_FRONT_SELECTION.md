# PLAN: Selección Múltiple de Frentes en Asignación de Actividades

## Objetivo

Permitir que al crear una asignación de actividad se pueda seleccionar **más de un frente** o **todos los frentes** disponibles, en lugar de un único frente.

---

## Estado Actual

- Frontend: Dropdown único para seleccionar un solo frente
- Backend: Schema `AssignmentCreate` ya soporta `front_ids: List[str]` y `all_fronts: bool`

---

## Arquitectura Propuesta

### Modelo de Datos

```python
# Schema AssignmentCreate (backend/app/api/v1/assignments.py)
class AssignmentCreate(BaseModel):
    front_ids: Optional[List[str]] = Field(default=[], description="Lista de IDs de frentes")
    all_fronts: bool = Field(default=False, description="Si True, asigna a todos los frentes del proyecto")
```

### Payload del Frontend

```json
// POST /api/v1/assignments
{
  "project_id": "TMQ",
  "assignee_user_ids": ["user_001", "user_002"],
  "activity_type_code": "CAMINAMIENTO",
  "front_ids": ["frente_A", "frente_B"],
  "all_fronts": false,
  "estado": "Querétaro",
  "municipio": "Querétaro",
  "pk": 5000,
  "start_at": "2026-06-16T08:00:00Z",
  "end_at": "2026-06-16T09:00:00Z"
}
```

---

## Fases de Implementación

### Fase 1: Frontend - UI del Selector (CRÍTICO)

**Archivos a modificar:**
- `desktop_flutter/sao_desktop/lib/features/planning/planning_page.dart`

**Cambios:**
1. Agregar campos de estado:
   - `List<String> _selectedFrontIds = []`
   - `bool _allFronts = false`

2. Reemplazar `DropdownButtonFormField<String>` por:
   - Checkbox "Todos los frentes" 
   - Lista de CheckboxListTile para frentes individuales
   - Scroll si hay más de 5 frentes

3. Actualizar validación `_canProceedToNextStep`:
   ```dart
   final hasFront = _allFronts || _selectedFrontIds.isNotEmpty;
   ```

4. Sincronizar cobertura (estado/municipio) con el primer frente seleccionado

**Complejidad:** Media

---

### Fase 2: Frontend - Repository (CRÍTICO)

**Archivos a modificar:**
- `desktop_flutter/sao_desktop/lib/data/repositories/assignments_repository.dart`

**Cambios:**
```dart
Future<void> createAssignment({
  ...
  List<String>? frontIds,
  bool? allFronts,
  ...
}) async {
  ...
  payload['front_ids'] = frontIds ?? [];
  payload['all_fronts'] = allFronts ?? false;
}
```

**Complejidad:** Baja

---

### Fase 3: Backend - Endpoint POST /assignments (CRÍTICO)

**Archivos a modificar:**
- `backend/app/api/v1/assignments.py`

**Lógica requerida:**
```python
@router.post("/assignments")
async def create_assignment(data: AssignmentCreate, ...):
    # 1. Si all_fronts=True, obtener todos los frentes del proyecto
    # 2. Si front_ids tiene valores, usar esos frentes específicos
    # 3. Por cada frente:
    #    - Crear documento en Firestore con frente_id
    #    - O crear una actividad con front_ids array (según decisión arquitectónica)
```

**Decisión arquitectónica a tomar:**
- Opción A: Crear **una actividad** con array `front_ids` (más simple)
- Opción B: Crear **N actividades**, una por cada frente (más granular)

**Complejidad:** Media-Alta

---

### Fase 4: Frontend - Vista de Detalle (OPCIONAL)

**Mejora futura:**
- Mostrar todos los frentes asignados en el card de actividad
- Mostrar badge "Multi-frente" cuando hay más de 1

---

### Fase 5: Frontend - Filtros (OPCIONAL)

**Mejora futura:**
- Permitir filtrar actividades por frente en la vista de planeación
- Checkbox "Ver actividades multi-frente"

---

## Impacto en Funcionalidades Existentes

| Funcionalidad | Impacto | Notas |
|--------------|---------|-------|
| Crear asignación | MODIFICADO | Requiere actualización de UI |
| Ver asignación | COMPATIBLE | Muestra primer frente, ignorando resto |
| Reportes | COMPATIBLE | Ignora front_ids por ahora |
| Sincronización | COMPATIBLE | Campos opcionales |

---

## Casos de Uso

### Caso 1: Seleccionar frentes específicos
```
Usuario marca: [ ] Frente A, [x] Frente B, [x] Frente C
Resultado: _selectedFrontIds = ["frente_B", "frente_C"], _allFronts = false
```

### Caso 2: Seleccionar todos los frentes
```
Usuario marca: [x] Todos los frentes
Resultado: _selectedFrontIds = [], _allFronts = true
```

### Caso 3: Compatibilidad hacia atrás
```
Usuario legacy (sin cambios): _frontId = "frente_A"
Resultado: _selectedFrontIds = ["frente_A"], _allFronts = false
```

---

## Riesgos y Mitigaciones

| Riesgo | Mitigación |
|--------|------------|
| Campos opcionales rompen backend legacy | Mantener backward compatibility con `front_id` único |
| UI compleja con muchos frentes | Limitar altura del listado y agregar scroll |
| Performance con N actividades | Batch insert en Firestore |

---

## Tiempo Estimado

- Fase 1 (UI): 2-3 horas
- Fase 2 (Repository): 30 minutos
- Fase 3 (Backend): 3-4 horas
- Total: ~6-7 horas

---

## Archivos a Modificar

### Frontend Flutter
- [ ] `desktop_flutter/sao_desktop/lib/features/planning/planning_page.dart`
- [ ] `desktop_flutter/sao_desktop/lib/data/repositories/assignments_repository.dart`

### Backend Python
- [ ] `backend/app/api/v1/assignments.py`

### Documentación
- [ ] `docs/PLAN_MULTI_FRONT_SELECTION.md` (este archivo)
- [ ] Actualizar `docs/CHANGELOG.md` al implementar

---

## Decisiones Pendientes

1. **Arquitectura de almacenamiento:**
   - ¿Una actividad con array de frentes?
   - ¿Una actividad por cada frente?

2. **Visualización:**
   - ¿Mostrar todos los frentes en el card?
   - ¿Agrupar por frente en la vista de planeación?

3. **Comportamiento de "Todos":**
   - ¿Resolver en frontend o backend?
   - ¿Cachear la lista de frentes?
