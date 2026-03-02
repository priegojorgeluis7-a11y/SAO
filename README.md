# 🚂 SAO - Sistema de Administración Operativa

Sistema enterprise para gestión de operaciones de campo en proyectos de infraestructura ferroviaria.

[![License](https://img.shields.io/badge/license-Proprietary-red.svg)]()
[![Flutter](https://img.shields.io/badge/Flutter-3.24+-blue.svg)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115+-green.svg)](https://fastapi.tiangolo.com/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16+-blue.svg)](https://www.postgresql.org/)

---

## 📖 Descripción

**SAO** es un sistema de gestión operativa diseñado para proyectos de infraestructura ferroviaria como el Tren México-Querétaro (TMQ). Permite a equipos de campo registrar actividades, eventos, evidencias y flujos de trabajo completos con **operación offline-first** y sincronización incremental.

### 🎯 Características Principales

- ✅ **100% Catalog-Driven**: Todo el comportamiento (formularios, workflows, permisos, evidencias) es configurable por catálogos
- ✅ **Offline-First**: Operación completa sin conectividad, sincronización automática al recuperar red
- ✅ **Multi-Tenant**: Soporte para múltiples proyectos (TMQ, TAP, SNL, QIR) con aislamiento de datos
- ✅ **RBAC + Scopes**: Permisos granulares por rol con alcances (proyecto/frente/municipio)
- ✅ **Versionado Inmutable**: Catálogos con flujo Draft → Publish → Deprecated
- ✅ **Workflow Configurable**: Máquinas de estado definidas por catálogo con validaciones por rol
- ✅ **Form Builder**: Formularios dinámicos renderizados desde catálogo (no hardcoded)
- ✅ **Auditoría Completa**: Registro detallado de cada acción con trazabilidad

---

## 🏗️ Arquitectura

```
┌────────────────────────────────────────────────────────┐
│                  BACKEND (FastAPI)                     │
│  PostgreSQL • SQLAlchemy • JWT Auth • MinIO/S3        │
└──────────────┬───────────────────┬─────────────────────┘
               │                   │
     ┌─────────▼────────┐  ┌──────▼─────────┐
     │   APP MÓVIL      │  │   ESCRITORIO   │
     │   (Flutter)      │  │   ADMIN        │
     │                  │  │   (Flutter)    │
     │ • Drift SQLite   │  │ • Catalog CRUD │
     │ • Offline-First  │  │ • Form Builder │
     │ • Riverpod       │  │ • Workflow Ed. │
     │ • GoRouter       │  │ • User Admin   │
     └──────────────────┘  └────────────────┘
```

### Stack Tecnológico

| Componente | Tecnología |
|------------|------------|
| **Backend** | FastAPI 0.115, PostgreSQL 16, SQLAlchemy 2.0, Alembic |
| **Móvil** | Flutter 3.24+, Drift, Riverpod 2.6, go_router |
| **Desktop** | Flutter Windows, fluent_ui |
| **Storage** | MinIO / AWS S3 (evidencias) |
| **Auth** | JWT (access + refresh tokens) |
| **Offline Auth** | PIN + Biometría (flutter_secure_storage) |

---

## 📂 Estructura del Proyecto

```
SAO/
├── backend/                    # FastAPI Backend
│   ├── alembic/               # Migraciones DB
│   ├── app/
│   │   ├── api/               # Endpoints REST
│   │   ├── models/            # SQLAlchemy models
│   │   ├── schemas/           # Pydantic DTOs
│   │   ├── services/          # Lógica de negocio
│   │   └── core/              # Config, auth, RBAC
│   └── tests/
│
├── mobile/                     # App Flutter Móvil
│   └── sao_windows/
│       ├── lib/
│       │   ├── features/      # Home, Activities, Agenda, etc.
│       │   ├── core/          # DI, routing, theme
│       │   └── data/          # Repositories, Drift DB
│       └── test/
│
├── desktop/                    # Admin Flutter Windows
│   └── lib/
│       └── features/
│           ├── catalog_admin/ # CRUD catálogos
│           ├── form_builder/  # Constructor visual
│           └── user_admin/    # Gestión usuarios
│
├── docs/                       # Documentación
│   ├── API.md
│   ├── CATALOG_SPEC.md
│   └── WORKFLOW.md
│
├── ARCHITECTURE.md            # Arquitectura detallada
├── IMPLEMENTATION_PLAN.md     # Plan por fases
└── README.md                  # Este archivo
```

---

## 🚀 Quick Start

### Requisitos Previos

- **Python 3.11+** (backend)
- **Flutter 3.24+** (móvil + desktop)
- **PostgreSQL 16+** (database)
- **Docker** (opcional, para desarrollo local)

### 1. Backend

```bash
cd backend

# Crear virtualenv
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Instalar dependencias
pip install -r requirements.txt

# Configurar BD
cp .env.example .env
# Editar .env con tu DATABASE_URL

# Ejecutar migraciones
alembic upgrade head

# Ejecutar seeds iniciales
python -m app.seeds.initial_data

# Iniciar servidor
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

**API disponible en:** `http://localhost:8000` (local) o `http://192.168.1.100:8000` (red)  
**Docs interactivas:** `http://192.168.1.100:8000/docs`

### 2. App Móvil

```bash
cd mobile/sao_windows

# Obtener dependencias
flutter pub get

# Generar código Drift
dart run build_runner build --delete-conflicting-outputs

# Ejecutar en Android
flutter run

# O Google Chrome (para desarrollo)
flutter run -d chrome
```

### 3. Escritorio Admin

```bash
cd desktop

flutter pub get
flutter run -d windows
```

---

## 📱 Capturas de Pantalla

### App Móvil

| Home (Dashboard) | Wizard Registro | Agenda Coordinador |
|------------------|-----------------|-------------------|
| ![Home](docs/screenshots/home.png) | ![Wizard](docs/screenshots/wizard.png) | ![Agenda](docs/screenshots/agenda.png) |

### Desktop Admin

| Catalog Manager | Form Builder | Workflow Editor |
|----------------|--------------|-----------------|
| ![Catalog](docs/screenshots/catalog_admin.png) | ![Form](docs/screenshots/form_builder.png) | ![Workflow](docs/screenshots/workflow_editor.png) |

---

## 🎓 Conceptos Clave

### 1. Catalog-Driven Architecture

**TODO** en SAO es configurable por catálogos:

- **Tipos de Actividad/Evento**: Definidos en `CAT_ActivityType`, `CAT_EventType`
- **Formularios**: Campos dinámicos en `CAT_FormField` (no hardcoded)
- **Workflows**: Estados y transiciones en `CAT_WorkflowState` + `CAT_WorkflowTransition`
- **Permisos**: Roles y permisos en `Role`, `Permission`, `UserRoleScope`
- **Evidencias**: Reglas en `CAT_EvidenceRule` (min fotos, GPS requerido, etc.)

**Ejemplo de Form Field:**
```json
{
  "key": "num_asistentes",
  "label": "Número de Asistentes",
  "widget": "number",
  "required": true,
  "validation_regex": "^[0-9]+$",
  "visible_when": {"field": "tipo", "op": "==", "value": "ASAMBLEA"}
}
```

El móvil **renderiza widgets dinámicamente** desde estos catálogos, sin código hardcoded.

### 2. Offline-First + Sync

- **Outbox Pattern**: Todas las operaciones (create/update/delete) van primero a `sync_queue`
- **Push Sync**: Se envían cambios en lotes al backend cuando hay conectividad
- **Pull Sync**: Se descargan cambios incrementales desde `last_sync_at`
- **Conflict Resolution**: Last-write-wins con UI para resolución manual

### 3. RBAC + Scopes

Los usuarios tienen **múltiples roles con alcances**:

```
Usuario: Juan Pérez
├── Rol: SUPERVISOR en Proyecto TMQ/Frente F1
├── Rol: OPERATIVO en Proyecto TMQ/Frente F2
└── Rol: LECTOR en Proyecto TAP (todos los frentes)
```

Cada query filtra datos según los scopes del usuario actual.

### 4. Versionado de Catálogos

```
DRAFT → (validación) → PUBLISHED → (nuevo publish) → DEPRECATED
```

- **DRAFT**: Solo visible para admins, editable
- **PUBLISHED**: Usado por móvil, inmutable
- **DEPRECATED**: Archivado, no se usa en nuevas actividades
- **Hash SHA256**: Para verificar integridad del paquete

---

## 📚 Documentación

- [**ARCHITECTURE.md**](ARCHITECTURE.md): Arquitectura detallada del sistema
- [**IMPLEMENTATION_PLAN.md**](IMPLEMENTATION_PLAN.md): Plan de implementación por fases
- [**API.md**](docs/API.md): Especificación de endpoints REST
- [**CATALOG_SPEC.md**](docs/CATALOG_SPEC.md): Estructura del paquete de catálogos
- [**WORKFLOW.md**](docs/WORKFLOW.md): Diseño del workflow engine

---

## 🧪 Testing

### Backend
```bash
cd backend
pytest tests/ --cov=app
```

### Móvil
```bash
cd mobile/sao_windows
flutter test --coverage
```

### Desktop
```bash
cd desktop
flutter test
```

---

## 🌟 Roadmap

### ✅ Fase 1: Fundamentos (Semana 1-2)
- [x] Backend FastAPI + Auth JWT
- [x] RBAC básico
- [x] Móvil: Login y token refresh

### ✅ Fase 2: Catálogos (Semana 3-4)
- [x] Versionado Draft→Publish
- [x] API de descarga
- [x] Seed initial (v1.0.0)

### ✅ Fase 3: Form Builder (Semana 5-6)
- [x] DynamicFormBuilder widget
- [x] EAV storage (activity_fields)
- [x] Validaciones dinámicas

### ✅ Fase 4: Workflow Engine (Semana 7-8)
- [x] WorkflowService
- [x] Transiciones configurables
- [x] Activity log

### ✅ Fase 5: Sync (Semana 9-10)
- [x] Push/Pull incremental
- [x] Conflict resolution
- [x] Background sync

### 🔄 Fase 6: Eventos (Semana 11-12)
- [ ] API eventos
- [ ] Reportar desde móvil
- [ ] Convertir evento → actividad

### 🔄 Fase 7: Escritorio (Semana 13-16)
- [ ] Setup Flutter Windows
- [ ] Catalog CRUD
- [ ] Form Builder visual
- [ ] Workflow editor

### ⏳ Fase 8: Evidencias (Semana 17)
- [ ] MinIO/S3 integration
- [ ] Upload multipart
- [ ] Compresión imágenes

### ⏳ Fase 9: Reportes (Semana 18)
- [ ] Templates Jinja2
- [ ] Generación PDF
- [ ] Audit log viewer

---

## 👥 Equipo

- **Backend**: [Tu Nombre]
- **App Móvil**: [Tu Nombre]
- **Desktop**: [Tu Nombre]
- **DevOps**: [Tu Nombre]

---

## 📄 Licencia

Propietario © 2026 SAO. Todos los derechos reservados.

---

## 📞 Soporte

Para dudas o reportes de bugs:
- Email: soporte@sao.mx
- Issues: [GitHub Issues](https://github.com/tu-org/sao/issues)

---

**Última actualización:** 2026-02-17  
**Versión:** 1.0.0-alpha
