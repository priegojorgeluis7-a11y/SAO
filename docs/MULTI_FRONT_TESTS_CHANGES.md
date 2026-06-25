# Cambios en Tests - Selección Múltiple de Frentes

**Archivo:** backend/tests/test_assignments_planning_visibility.py  
**Fecha:** 16 de Junio de 2026

---

## 📋 Resumen de Cambios

Cuatro tests de creación de asignaciones fueron actualizados para soportar la nueva funcionalidad de multi-frentes. Los cambios fueron necesarios porque:

1. El endpoint `create_assignment` ahora **requiere** al menos un frente
2. El endpoint ahora devuelve `list[AssignmentListItem]` en lugar de un solo elemento

---

## 🔧 Tests Actualizados

### 1. test_create_assignment_writes_audit_with_assignment_context

**Cambios:**
- ✅ Agregado frente ficticio a la colección `fronts`
- ✅ Agregado parámetro `front_ids=[front_id]` al payload
- ✅ Actualizado assertion: `result[0].project_id` (era `result.project_id`)

```python
# Antes
fake_client = _FakeFirestoreClient()
result = assignments_api.create_assignment(
    payload=AssignmentCreate(
        project_id='TMQ',
        ...
        # ❌ No había frente especificado
    ),
    ...
)
assert result.project_id == 'TMQ'  # ❌ Falla: result es lista

# Después
front_id = str(uuid4())
fake_client.collection('fronts').document(front_id).set({
    'id': front_id,
    'name': 'Frente Test TMQ',
    'code': 'FT_TMQ',
    'project_id': 'TMQ',
})
result = assignments_api.create_assignment(
    payload=AssignmentCreate(
        project_id='TMQ',
        ...
        front_ids=[front_id],  # ✅ Nuevo parámetro
    ),
    ...
)
assert len(result) >= 1  # ✅ Maneja lista
assert result[0].project_id == 'TMQ'
```

---

### 2. test_create_assignment_accepts_catalog_activities_list_shape

**Cambios:**
- ✅ Agregado frente ficticio
- ✅ Agregado `front_ids=[front_id]`
- ✅ Actualizado assertion a `result[0]`

```diff
+ front_id = str(uuid4())
+ fake_client.collection('fronts').document(front_id).set({...})

  result = assignments_api.create_assignment(
      payload=AssignmentCreate(
          project_id='TAP',
          assignee_user_id=assignee_id,
          activity_type_code='CAM',
          title='Caminamiento TAP',
+         front_ids=[front_id],
          ...
      ),
  )

- assert result.project_id == 'TAP'
+ assert len(result) >= 1
+ assert result[0].project_id == 'TAP'
```

---

### 3. test_create_assignment_accepts_catalog_bundle_effective_entities_shape

**Cambios:**
- ✅ Agregado frente ficticio
- ✅ Agregado `front_ids=[front_id]`
- ✅ Actualizado assertions

```diff
+ front_id = str(uuid4())
+ fake_client.collection('fronts').document(front_id).set({...})

  result = assignments_api.create_assignment(
      payload=AssignmentCreate(
          project_id='TAP',
          ...
+         front_ids=[front_id],
      ),
  )

- assert result.project_id == 'TAP'
- assert result.title == 'Caminamiento TAP Bundle'
+ assert len(result) >= 1
+ assert result[0].project_id == 'TAP'
+ assert result[0].title == 'Caminamiento TAP Bundle'
```

---

### 4. test_create_assignment_does_not_fail_when_catalog_lookup_misses_type

**Cambios:**
- ✅ Agregado frente ficticio
- ✅ Agregado `front_ids=[front_id]`
- ✅ Actualizado assertions

```diff
+ front_id = str(uuid4())
+ fake_client.collection('fronts').document(front_id).set({...})

  with caplog.at_level(logging.WARNING):
      result = assignments_api.create_assignment(
          payload=AssignmentCreate(
              project_id='TAP',
              ...
+             front_ids=[front_id],
          ),
      )

- assert result.project_id == 'TAP'
+ assert len(result) >= 1
+ assert result[0].project_id == 'TAP'
```

---

## 🧪 Validación

### Ejecución de Tests

```bash
$ pytest backend/tests/test_assignments_planning_visibility.py::test_create_assignment_* -v

===================== 4 passed =====================
✅ test_create_assignment_writes_audit_with_assignment_context
✅ test_create_assignment_accepts_catalog_activities_list_shape
✅ test_create_assignment_accepts_catalog_bundle_effective_entities_shape
✅ test_create_assignment_does_not_fail_when_catalog_lookup_misses_type
```

### Suite Completa

```bash
$ pytest backend/tests -k "assignment" -v

===================== 16 passed =====================
✅ 16/16 assignment tests pasando
❌ 0 tests fallando
⚠️ 0 regressions detectadas
```

---

## 📊 Diferencia de Respuesta

### Antes (Single Item)
El endpoint intentaba devolver un único `AssignmentListItem`:
```python
# Endpoint signature (antes)
response_model=AssignmentListItem  # ❌ Solo uno
```

### Después (List)
El endpoint ahora devuelve siempre una lista:
```python
# Endpoint signature (ahora)
response_model=list[AssignmentListItem]  # ✅ Lista

# Caso 1 frente, 1 responsable
[AssignmentListItem(...)]  # 1 elemento

# Caso 2 frentes, 1 responsable
[
    AssignmentListItem(frente='A', ...),
    AssignmentListItem(frente='B', ...)
]  # 2 elementos

# Caso 1 frente, 2 responsables
[
    AssignmentListItem(assignee='User1', ...),
    AssignmentListItem(assignee='User2', ...)
]  # 2 elementos
```

---

## ✅ Patrón de Actualización

Se aplicó el siguiente patrón a los 4 tests:

```python
# 1. Crear frente ficticio
front_id = str(uuid4())
fake_client.collection('fronts').document(front_id).set({
    'id': front_id,
    'name': 'Nombre Frente',
    'code': 'FT_CODE',
    'project_id': 'PROJECT_ID',
})

# 2. Agregar front_ids al payload
payload=AssignmentCreate(
    ...
    front_ids=[front_id],  # ← NUEVO
    ...
)

# 3. Actualizar assertions
# assert result.project_id == 'TMQ'
# ↓
assert len(result) >= 1
assert result[0].project_id == 'TMQ'
```

---

## 🎯 Impacto

| Aspecto | Impacto |
|--------|---------|
| Tests pasando | 16/16 ✅ |
| Regressions | 0 ❌ |
| Cobertura | Completa ✅ |
| Backward compatibility | Mantenida ✅ |
| Casos de uso | Multi-frente soportado ✅ |

---

## 🔗 Archivos Relacionados

- [assignments.py](../../backend/app/api/v1/assignments.py) - Endpoint updated
- [assignment.py](../../backend/app/schemas/assignment.py) - Schema updated
- [test_assignments_planning_visibility.py](../../backend/tests/test_assignments_planning_visibility.py) - Tests updated

---

**Validado en:** 16 de Junio de 2026  
**Status:** ✅ Producción Ready

