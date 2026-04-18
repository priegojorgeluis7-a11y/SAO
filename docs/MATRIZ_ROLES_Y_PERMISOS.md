# Matriz de roles y permisos de SAO

**Fecha:** 2026-04-17  
**Estado:** Vigente  
**Fuente canónica:** backend actual en modo Firestore

## Objetivo
Este documento resume qué puede hacer cada rol en SAO y cuáles son sus permisos base según la configuración vigente del backend.

## Fuentes de verdad
La definición base de permisos y su asignación por rol vive en:

- `backend/app/core/permission_catalog.py`
- `backend/app/api/deps.py`
- `docs/WORKFLOW.md`

> Nota: además del rol, el backend puede restringir acceso por proyecto y por permisos directos tipo `allow` o `deny` en `permission_scopes`.

## Roles vigentes
Los roles activos del sistema son:

- **ADMIN** — administración total de la plataforma
- **COORD** — coordinación operativa y revisión
- **SUPERVISOR** — supervisión y validación de campo
- **OPERATIVO** — captura y ejecución en campo
- **LECTOR** — consulta de información en modo solo lectura

---

## Permisos canónicos del sistema
Los permisos base actualmente contemplados por el backend son:

1. Ver actividades
2. Crear actividades
3. Editar actividades
4. Eliminar actividades
5. Aprobar actividades
6. Rechazar actividades
7. Crear eventos
8. Editar eventos
9. Ver eventos
10. Ver catálogo
11. Editar catálogo
12. Publicar catálogo
13. Crear usuarios
14. Editar usuarios
15. Ver usuarios
16. Ver reportes
17. Exportar reportes
18. Administrar asignaciones
19. Administrar proyectos
20. Aprobar excepciones de flujo

---

## Matriz resumida por rol

| Permiso / capacidad | ADMIN | COORD | SUPERVISOR | OPERATIVO | LECTOR |
|---|---|---|---|---|---|
| Ver actividades | ✅ | ✅ | ✅ | ✅ | ✅ |
| Crear actividades | ✅ | ✅ | ✅ | ✅ | ❌ |
| Editar actividades | ✅ | ✅ | ✅ | ✅ | ❌ |
| Eliminar actividades | ✅ | ✅ | ❌ | ❌ | ❌ |
| Aprobar actividades | ✅ | ✅ | ✅ | ❌ | ❌ |
| Rechazar actividades | ✅ | ✅ | ✅ | ❌ | ❌ |
| Crear eventos | ✅ | ✅ | ✅ | ✅ | ❌ |
| Editar eventos | ✅ | ✅ | ✅ | ❌ | ❌ |
| Ver eventos | ✅ | ✅ | ✅ | ✅ | ✅ |
| Ver catálogo | ✅ | ✅ | ✅ | ✅ | ✅ |
| Editar catálogo | ✅ | ✅ | ✅ | ❌ | ❌ |
| Publicar catálogo | ✅ | ❌ | ✅ | ❌ | ❌ |
| Crear usuarios | ✅ | ❌ | ❌ | ❌ | ❌ |
| Editar usuarios | ✅ | ❌ | ❌ | ❌ | ❌ |
| Ver usuarios | ✅ | ✅ | ❌ | ❌ | ✅ |
| Ver reportes | ✅ | ✅ | ✅ | ❌ | ✅ |
| Exportar reportes | ✅ | ✅ | ✅ | ❌ | ❌ |
| Administrar asignaciones | ✅ | ✅ | ✅ | ❌ | ❌ |
| Administrar proyectos | ✅ | ❌ | ✅ | ❌ | ❌ |
| Aprobar excepciones de flujo | ✅ | ❌ | ❌ | ❌ | ❌ |

---

## Qué puede hacer cada rol

### ADMIN
Puede administrar el sistema completo:

- crear, editar, aprobar, rechazar y eliminar actividades
- crear y editar eventos
- ver, editar y publicar catálogos
- crear, editar y consultar usuarios
- administrar asignaciones y proyectos
- consultar y exportar reportes
- aprobar excepciones de flujo
- acceder a vistas administrativas y auditoría

### COORD
Puede coordinar la operación diaria y validar trabajo:

- ver, crear, editar y eliminar actividades
- aprobar o rechazar actividades en revisión
- crear y editar eventos
- consultar y editar catálogo
- ver usuarios
- consultar y exportar reportes
- administrar asignaciones
- operar dashboard y flujos de revisión

No tiene permisos base para crear o editar usuarios, administrar proyectos, publicar catálogo ni aprobar excepciones de flujo.

### SUPERVISOR
Puede supervisar y validar expedientes:

- ver, crear y editar actividades
- aprobar o rechazar actividades
- crear, editar y consultar eventos
- ver, editar y publicar catálogo
- consultar y exportar reportes operativos
- administrar asignaciones y proyectos
- acceder a paneles de revisión, seguimiento y control

No tiene permisos base para usuarios, eliminar actividades ni aprobar excepciones de flujo.

### OPERATIVO
Es el rol de ejecución en campo:

- ver, crear y editar actividades propias o visibles por su alcance
- capturar eventos
- consultar eventos
- consultar catálogo necesario para la operación
- cargar evidencias, observaciones y datos del flujo operativo

No puede aprobar, rechazar ni administrar usuarios, proyectos o reportes.

### LECTOR
Es un perfil de consulta:

- ver actividades
- ver eventos
- consultar catálogo
- ver usuarios
- ver reportes
- entrar a pantallas de lectura y seguimiento sin modificar información

No puede crear, editar, aprobar o rechazar registros.

---

## Reglas importantes de alcance

### 1. El proyecto también limita el acceso
Tener un rol no garantiza acceso a todos los proyectos. El backend valida `project_id` y puede bloquear la operación si el usuario no está asignado a ese proyecto.

### 2. Puede haber excepciones por permiso directo
Además del rol, un usuario puede traer `permission_scopes` con reglas explícitas de:

- **allow** — concede un permiso adicional
- **deny** — bloquea un permiso aunque el rol normalmente lo tenga

### 3. La revisión tiene reglas especiales
En el flujo de revisión:

- **ADMIN**, **COORD** y **SUPERVISOR** son los roles normales de decisión
- la aprobación excepcional queda reservada a **ADMIN**
- **LECTOR** entra en consulta, no en decisión

---

## Recomendación operativa
Si se necesita explicar rápidamente el sistema a negocio o QA, usar esta lectura resumida:

- **ADMIN:** controla todo
- **COORD:** coordina y decide
- **SUPERVISOR:** supervisa y valida
- **OPERATIVO:** ejecuta y captura
- **LECTOR:** consulta y monitorea
