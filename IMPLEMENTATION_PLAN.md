# 📋 Plan de Implementación SAO

## 🎯 Objetivo

Transformar el prototipo existente en un sistema enterprise **100% CATALOG-DRIVEN** y **OFFLINE-FIRST** mediante implementación incremental en 9 fases.

---

## 📦 FASE 1: Fundamentos Backend + Auth (2 semanas)

### Objetivos
- ✅ Backend FastAPI funcional con SQLAlchemy
- ✅ Autenticación JWT con refresh tokens
- ✅ RBAC básico funcionando
- ✅ Seeds de 1 proyecto TMQ con 2 frentes

### Commits

#### 1.1 Setup Backend Structure
```bash
git checkout -b feature/fase1-auth
```

**backend/requirements.txt**
```txt
fastapi==0.115.0
uvicorn[standard]==0.30.0
sqlalchemy==2.0.25
alembic==1.13.0
psycopg2-binary==2.9.9
pydantic==2.5.0
pydantic-settings==2.1.0
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
python-multipart==0.0.6
```

**Archivos a crear:**
```
backend/
├── alembic.ini
├── alembic/
│   ├── env.py
│   └── versions/
├── app/
│   ├── __init__.py
│   ├── main.py
│   ├── core/
│   │   ├── __init__.py
│   │   ├── config.py
│   │   ├── security.py
│   │   └── database.py
│   └── api/
│       └── __init__.py
├── requirements.txt
└── README.md
```

**Commit:**
```
feat(backend): setup FastAPI project structure

- Add requirements.txt with FastAPI, SQLAlchemy, Alembic
- Create project folder structure
- Add basic config and database connection
- Configure Alembic for migrations
```

#### 1.2 Core Models (Part 1: Auth)
**backend/app/models/__init__.py**
**backend/app/models/user.py**
**backend/app/models/role.py**

```python
# models/user.py
from sqlalchemy import Column, String, DateTime, Boolean, Enum
from sqlalchemy.dialects.postgresql import UUID
import uuid
from datetime import datetime
from app.core.database import Base

class User(Base):
    __tablename__ = "users"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String(255), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    pin_hash = Column(String(255), nullable=True)
    full_name = Column(String(255), nullable=False)
    status = Column(Enum('active', 'inactive', 'locked', name='user_status'), default='active')
    last_login_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at = Column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)
```

**Commit:**
```
feat(models): add User, Role, Permission models

- User with email, password_hash, pin_hash
- Role with name and description
- Permission with code, resource, action
- RolePermission many-to-many
- UserRoleScope with project/front/location scopes
```

#### 1.3 Core Models (Part 2: Project Structure)
**backend/app/models/project.py**
**backend/app/models/front.py**

```python
# models/project.py
class Project(Base):
    __tablename__ = "projects"
    
    id = Column(String(10), primary_key=True)  # 'TMQ', 'TAP'
    name = Column(String(255), nullable=False)
    status = Column(Enum('active', 'archived', name='project_status'), default='active')
    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=True)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)
```

**Commit:**
```
feat(models): add Project, Front, Location models

- Project with id (TMQ/TAP/etc)
- Front with PK range (pk_start, pk_end)
- Location with estado/municipio
- Relationships configured
```

#### 1.4 Auth API
**backend/app/api/auth.py**
**backend/app/schemas/auth.py**

```python
# api/auth.py
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from app.core.security import create_access_token, verify_password
from app.schemas.auth import Token, LoginRequest

router = APIRouter(prefix="/auth", tags=["auth"])

@router.post("/login", response_model=Token)
async def login(form: OAuth2PasswordRequestForm = Depends()):
    user = db.query(User).filter(User.email == form.username).first()
    if not user or not verify_password(form.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    
    access_token = create_access_token({"sub": str(user.id)})
    refresh_token = create_refresh_token({"sub": str(user.id)})
    
    return {"access_token": access_token, "refresh_token": refresh_token}
```

**Commit:**
```
feat(auth): implement JWT authentication

- POST /auth/login with email/password
- POST /auth/refresh for token renewal
- JWT token creation with 24h expiry
- Refresh token with 30d expiry
- OAuth2PasswordBearer dependency
```

#### 1.5 RBAC Middleware
**backend/app/core/rbac.py**
**backend/app/core/dependencies.py**

```python
# core/dependencies.py
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

async def get_current_user(token: str = Depends(oauth2_scheme)):
    try:
        payload = jwt.decode(token, settings.JWT_SECRET, algorithms=["HS256"])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise credentials_exception
    return user

def require_permission(permission_code: str):
    async def permission_checker(user: User = Depends(get_current_user)):
        # Check if user has permission via their roles
        has_perm = check_user_permission(user.id, permission_code)
        if not has_perm:
            raise HTTPException(status_code=403, detail="Permission denied")
        return user
    return permission_checker
```

**Commit:**
```
feat(rbac): implement RBAC middleware

- get_current_user dependency
- require_permission decorator
- check_user_permission utility
- Scope filtering for multi-tenant
```

#### 1.6 Seeds (Initial Data)
**backend/app/seeds/initial_data.py**

```python
def seed_initial_data(db: Session):
    # Roles
    roles = [
        Role(id=1, name="ADMIN", description="Administrador del sistema"),
        Role(id=2, name="COORD", description="Coordinador de proyecto"),
        Role(id=3, name="SUPERVISOR", description="Supervisor de frente"),
        Role(id=4, name="OPERATIVO", description="Personal operativo"),
        Role(id=5, name="LECTOR", description="Solo lectura"),
    ]
    db.add_all(roles)
    
    # Permissions
    permissions = [
        Permission(id=1, code="activity.create", resource="activity", action="create"),
        Permission(id=2, code="activity.edit", resource="activity", action="edit"),
        Permission(id=3, code="activity.delete", resource="activity", action="delete"),
        Permission(id=4, code="activity.view", resource="activity", action="view"),
        Permission(id=5, code="catalog.publish", resource="catalog", action="publish"),
        # ... más permisos
    ]
    db.add_all(permissions)
    
    # Project TMQ
    tmq = Project(
        id="TMQ",
        name="Tren México-Querétaro",
        status="active",
        start_date=date(2024, 1, 1)
    )
    db.add(tmq)
    
    # Fronts
    fronts = [
        Front(id=uuid4(), project_id="TMQ", code="F1", name="Frente 1 (CDMX-Tula)", pk_start=0, pk_end=60000),
        Front(id=uuid4(), project_id="TMQ", code="F2", name="Frente 2 (Tula-Querétaro)", pk_start=60000, pk_end=210000),
    ]
    db.add_all(fronts)
    
    # Admin user
    admin = User(
        id=uuid4(),
        email="admin@sao.mx",
        password_hash=get_password_hash("admin123"),
        full_name="Administrador SAO",
        status="active"
    )
    db.add(admin)
    
    db.commit()
```

**Commit:**
```
feat(seeds): add initial data seed script

- 5 roles (ADMIN, COORD, SUPERVISOR, OPERATIVO, LECTOR)
- 15 permissions (activity.*, event.*, catalog.*)
- Project TMQ with 2 fronts (F1, F2)
- Admin user (admin@sao.mx / admin123)
- Role-permission mappings
```

#### 1.7 Migration v1
```bash
alembic revision --autogenerate -m "Initial schema with auth and projects"
alembic upgrade head
```

**Commit:**
```
migration: create initial database schema

- Users, roles, permissions tables
- Projects, fronts, locations
- UserRoleScope for multi-tenant
- Indexes for performance
```

#### 1.8 Móvil: Auth Flow
**mobile/lib/data/remote/api_client.dart**
**mobile/lib/features/auth/login_page.dart**

```dart
// api_client.dart
class ApiClient {
  final Dio _dio;
  final FlutterSecureStorage _storage;
  
  Future<void> init() async {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Refresh token
          await _refreshToken();
          // Retry original request
        }
        handler.next(error);
      },
    ));
  }
  
  Future<TokenResponse> login(String email, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'username': email,
      'password': password,
    });
    return TokenResponse.fromJson(response.data);
  }
}
```

**Commit:**
```
feat(mobile/auth): implement login flow with JWT

- ApiClient with Dio interceptors
- Automatic token refresh on 401
- Secure storage for tokens (flutter_secure_storage)
- Login page with email/password
- Redirect to home on success
```

### Checklist Fase 1
- [ ] Backend FastAPI running on localhost:8000
- [ ] Database migrations applied
- [ ] Seeds executed (1 admin user, 2 fronts)
- [ ] `POST /auth/login` returns JWT tokens
- [ ] Móvil puede hacer login y guardar tokens
- [ ] Próximas requests usan token automáticamente
- [ ] Tests básicos pasando

**PR Title:** `feat: Fase 1 - Backend foundation with Auth and RBAC`

---

## 📦 FASE 2: Catálogos Versionados (2 semanas)

### Objetivos
- ✅ Tablas de catálogos en backend
- ✅ API para descargar catálogos (solo PUBLISHED)
- ✅ Workflow Draft→Publish
- ✅ Seed de catálogo v1.0.0 para TMQ

### Commits

#### 2.1 Catalog Models
**backend/app/models/catalog.py**

```python
class CatalogVersion(Base):
    __tablename__ = "catalog_versions"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id = Column(String(10), ForeignKey("projects.id"), nullable=False)
    version_number = Column(String(20), nullable=False)  # '1.0.0'
    status = Column(Enum('draft', 'published', 'deprecated'), default='draft')
    hash = Column(String(64), nullable=True)  # SHA256
    notes = Column(Text, nullable=True)
    published_by_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    published_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    
    __table_args__ = (
        UniqueConstraint('project_id', 'version_number'),
    )

class CATActivityType(Base):
    __tablename__ = "cat_activity_types"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    version_id = Column(UUID(as_uuid=True), ForeignKey("catalog_versions.id"), nullable=False)
    code = Column(String(50), nullable=False)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    icon = Column(String(50), nullable=True)
    color = Column(String(7), nullable=True)
    sort_order = Column(Integer, default=0)

# Más tablas: CATFormField, CATWorkflowState, CATWorkflowTransition, etc.
```

**Commit:**
```
feat(models): add catalog versioning models

- CatalogVersion with draft/published/deprecated status
- CATActivityType, CATEventType
- CATFormField with widget types
- CATWorkflowState, CATWorkflowTransition
- CATEvidenceRule, CATChecklistTemplate
```

#### 2.2 Catalog Service
**backend/app/services/catalog_service.py**

```python
class CatalogService:
    def __init__(self, db: Session):
        self.db = db
    
    def get_latest_published(self, project_id: str) -> dict:
        """Devuelve el catálogo PUBLISHED más reciente"""
        version = self.db.query(CatalogVersion).filter(
            CatalogVersion.project_id == project_id,
            CatalogVersion.status == 'published'
        ).order_by(CatalogVersion.published_at.desc()).first()
        
        if not version:
            raise HTTPException(404, "No published catalog found")
        
        return self._serialize_catalog(version)
    
    def _serialize_catalog(self, version: CatalogVersion) -> dict:
        """Convierte catálogo a JSON para descargar"""
        return {
            "version_id": str(version.id),
            "version_number": version.version_number,
            "hash": version.hash,
            "published_at": version.published_at.isoformat(),
            "activity_types": [
                {
                    "id": str(at.id),
                    "code": at.code,
                    "name": at.name,
                    # ...
                }
                for at in version.activity_types
            ],
            "form_fields": [...],
            "workflow_states": [...],
            "workflow_transitions": [...],
            # ...
        }
    
    def publish_version(self, version_id: UUID, user_id: UUID):
        """Publica un catálogo DRAFT"""
        version = self.db.query(CatalogVersion).get(version_id)
        
        if version.status != 'draft':
            raise ValueError("Only DRAFT versions can be published")
        
        # Validaciones
        self._validate_catalog(version)
        
        # Deprecar versión anterior
        prev = self.db.query(CatalogVersion).filter(
            CatalogVersion.project_id == version.project_id,
            CatalogVersion.status == 'published'
        ).first()
        if prev:
            prev.status = 'deprecated'
        
        # Generar hash
        catalog_json = self._serialize_catalog(version)
        version.hash = hashlib.sha256(json.dumps(catalog_json).encode()).hexdigest()
        
        # Publicar
        version.status = 'published'
        version.published_by_id = user_id
        version.published_at = datetime.utcnow()
        
        self.db.commit()
```

**Commit:**
```
feat(services): add CatalogService for versioning

- get_latest_published() for mobile download
- publish_version() with validation
- _serialize_catalog() to JSON package
- SHA256 hash generation
- Auto-deprecate previous version on publish
```

#### 2.3 Catalog API
**backend/app/api/catalog.py**

```python
router = APIRouter(prefix="/catalog", tags=["catalog"])

@router.get("/latest")
async def get_latest_catalog(
    project_id: str,
    current_user: User = Depends(get_current_user)
):
    """Descarga el último catálogo PUBLISHED para un proyecto"""
    service = CatalogService(db)
    catalog = service.get_latest_published(project_id)
    return catalog

@router.get("/delta")
async def get_catalog_delta(
    project_id: str,
    since_hash: str = Query(...),
    current_user: User = Depends(get_current_user)
):
    """Devuelve solo cambios desde un hash anterior"""
    # Implementar delta sync
    pass

@router.post("/versions/{version_id}/publish")
async def publish_catalog(
    version_id: UUID,
    current_user: User = Depends(require_permission("catalog.publish"))
):
    """Publica un catálogo DRAFT (solo ADMIN/COORD)"""
    service = CatalogService(db)
    service.publish_version(version_id, current_user.id)
    return {"status": "published"}
```

**Commit:**
```
feat(api): add catalog download endpoints

- GET /catalog/latest?projectId=TMQ
- GET /catalog/delta?since_hash=...
- POST /catalog/versions/{id}/publish (admin only)
- Returns full catalog JSON package
```

#### 2.4 Seed Catalog v1.0.0
**backend/app/seeds/catalog_tmq_v1.py**

```python
def seed_catalog_tmq_v1(db: Session):
    # Crear versión
    version = CatalogVersion(
        id=uuid4(),
        project_id="TMQ",
        version_number="1.0.0",
        status="published",
        notes="Catálogo inicial para TMQ",
        published_by_id=get_admin_user_id(db),
        published_at=datetime.utcnow()
    )
    db.add(version)
    db.flush()
    
    # Activity Types
    activity_types = [
        CATActivityType(
            id=uuid4(),
            version_id=version.id,
            code="INSP_CIVIL",
            name="Inspección Civil",
            description="Inspección de obras civiles",
            icon="engineering",
            color="#1976D2",
            sort_order=1
        ),
        CATActivityType(
            id=uuid4(),
            version_id=version.id,
            code="ASAMBLEA",
            name="Asamblea Informativa",
            description="Reunión con comunidades",
            icon="groups",
            color="#388E3C",
            sort_order=2
        ),
        # ... más tipos
    ]
    db.add_all(activity_types)
    
    # Form Fields para INSP_CIVIL
    fields_insp = [
        CATFormField(
            id=uuid4(),
            version_id=version.id,
            entity_type="activity",
            type_id=activity_types[0].id,
            key="num_inspeccion",
            label="Número de Inspección",
            widget="text",
            required=True,
            sort_order=1
        ),
        CATFormField(
            id=uuid4(),
            version_id=version.id,
            entity_type="activity",
            type_id=activity_types[0].id,
            key="hora_inicio",
            label="Hora de Inicio",
            widget="time",
            required=True,
            sort_order=2
        ),
        # ... más campos
    ]
    db.add_all(fields_insp)
    
    # Workflow States
    states = [
        CATWorkflowState(
            id=uuid4(),
            version_id=version.id,
            entity_type="activity",
            code="PROGRAMADA",
            label="Programada",
            color="#FFC107",
            is_initial=True,
            sort_order=1
        ),
        CATWorkflowState(
            version_id=version.id,
            entity_type="activity",
            code="EN_EJECUCION",
            label="En Ejecución",
            color="#F44336",
            sort_order=2
        ),
        # ENVIADA, VALIDADA, CANCELADA
    ]
    db.add_all(states)
    
    # Workflow Transitions
    transitions = [
        CATWorkflowTransition(
            id=uuid4(),
            version_id=version.id,
            from_state_id=states[0].id,  # PROGRAMADA
            to_state_id=states[1].id,    # EN_EJECUCION
            label="Iniciar",
            allowed_roles=[4],  # OPERATIVO
            required_fields=["hora_inicio"],
            confirm_message="¿Iniciar esta actividad?"
        ),
        # ... más transiciones
    ]
    db.add_all(transitions)
    
    # Generar hash
    catalog_json = CatalogService(db)._serialize_catalog(version)
    version.hash = hashlib.sha256(json.dumps(catalog_json).encode()).hexdigest()
    
    db.commit()
```

**Commit:**
```
feat(seeds): add catalog v1.0.0 for project TMQ

- 5 activity types (INSP_CIVIL, ASAMBLEA, RECORRIDO, etc)
- 3 event types (INCIDENTE, HALLAZGO, SOLICITUD)
- 20+ form fields with validation
- Workflow: PROGRAMADA → EN_EJECUCION → ENVIADA → VALIDADA
- Evidence rules (min photos, GPS required)
- Checklist template for INSP_CIVIL
```

#### 2.5 Móvil: Catalog Download
**mobile/lib/data/repositories/catalog_repository.dart**

```dart
class CatalogRepository {
  final ApiClient _api;
  final AppDatabase _db;
  
  Future<void> downloadAndApplyCatalog(String projectId) async {
    // 1. GET /catalog/latest
    final response = await _api.getCatalogLatest(projectId);
    final package = CatalogPackage.fromJson(response.data);
    
    // 2. Verificar hash
    final localVersion = await _db.catalogVersions
        .getSingle(package.versionId);
    
    if (localVersion?.hash == package.hash) {
      print("Catalog already up to date");
      return;
    }
    
    // 3. Aplicar catálogo
    await _db.transaction(() async {
      // Eliminar catálogo anterior
      await _db.delete(_db.catActivityTypes).go();
      await _db.delete(_db.catFormFields).go();
      // ...
      
      // Insertar nuevo catálogo
      await _db.batch((batch) {
        batch.insertAll(
          _db.catActivityTypes,
          package.activityTypes.map((e) => e.toCompanion()),
        );
        batch.insertAll(
          _db.catFormFields,
          package.formFields.map((e) => e.toCompanion()),
        );
        // ...
      });
      
      // Actualizar versión
      await _db.into(_db.catalogVersions).insert(
        CatalogVersionsCompanion.insert(
          id: package.versionId,
          projectId: projectId,
          versionNumber: package.versionNumber,
          hash: package.hash,
          publishedAt: package.publishedAt,
        ),
        mode: InsertMode.insertOrReplace,
      );
    });
    
    print("Catalog ${package.versionNumber} applied successfully");
  }
}
```

**Commit:**
```
feat(mobile/catalog): implement catalog download and apply

- CatalogRepository.downloadAndApplyCatalog()
- CatalogPackage model
- Transactional replacement of old catalog
- Hash verification to avoid redundant downloads
```

### Checklist Fase 2
- [ ] Backend tiene tablas catalog_*
- [ ] Seeds ejecutados (catalog v1.0.0 PUBLISHED)
- [ ] `GET /catalog/latest?projectId=TMQ` devuelve JSON completo
- [ ] Móvil descarga y aplica catálogo en Drift
- [ ] Tablas locales cat_* pobladas correctamente
- [ ] Tests de serialización pasando

**PR Title:** `feat: Fase 2 - Catalog versioning with Draft→Publish workflow`

---

## 📦 FASE 3: Motor de Formularios Dinámicos (2 semanas)

### Objetivos
- ✅ Widget `DynamicFormBuilder` funcionando
- ✅ Renderiza todos los tipos de widgets desde catálogo
- ✅ Validaciones dinámicas
- ✅ Guardar en `activity_fields` (EAV)

### Commits

#### 3.1 Form Builder Widget
**mobile/lib/features/activities/widgets/dynamic_form_builder.dart**

```dart
class DynamicFormBuilder extends ConsumerWidget {
  final String activityTypeId;
  final Map<String, dynamic> initialValues;
  final void Function(Map<String, dynamic> values) onChanged;
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Leer campos del catálogo
    final fields = ref.watch(formFieldsProvider(activityTypeId));
    
    return fields.when(
      data: (fieldList) => Column(
        children: fieldList.map((field) {
          // 2. Renderizar widget según field.widget
          return _buildFieldWidget(field);
        }).toList(),
      ),
      loading: () => CircularProgressIndicator(),
      error: (e, s) => Text("Error: $e"),
    );
  }
  
  Widget _buildFieldWidget(CATFormField field) {
    switch (field.widget) {
      case FieldWidget.text:
        return _TextFieldWidget(field: field, onChanged: _onFieldChanged);
      case FieldWidget.number:
        return _NumberFieldWidget(field: field, onChanged: _onFieldChanged);
      case FieldWidget.select:
        return _SelectFieldWidget(field: field, onChanged: _onFieldChanged);
      case FieldWidget.date:
        return _DateFieldWidget(field: field, onChanged: _onFieldChanged);
      case FieldWidget.time:
        return _TimeFieldWidget(field: field, onChanged: _onFieldChanged);
      case FieldWidget.gps:
        return _GPSFieldWidget(field: field, onChanged: _onFieldChanged);
      case FieldWidget.photo:
        return _PhotoFieldWidget(field: field, onChanged: _onFieldChanged);
      default:
        return SizedBox.shrink();
    }
  }
}
```

**Commit:**
```
feat(mobile/forms): add DynamicFormBuilder widget

- Reads CAT_FormField from catalog
- Renders widgets dynamically: text, number, select, date, time, gps, photo
- Handles validation (required, regex)
- Conditional visibility (visible_when)
- Returns Map<String, dynamic> with values
```

#### 3.2 Field Widgets
**mobile/lib/features/activities/widgets/field_widgets/**

```dart
// text_field_widget.dart
class _TextFieldWidget extends StatefulWidget {
  final CATFormField field;
  final ValueChanged<String> onChanged;
  
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: field.label,
        hintText: field.placeholder,
      ),
      validator: (value) {
        if (field.required && (value == null || value.isEmpty)) {
          return 'Campo requerido';
        }
        if (field.validationRegex != null) {
          final regex = RegExp(field.validationRegex!);
          if (!regex.hasMatch(value!)) {
            return 'Formato inválido';
          }
        }
        return null;
      },
      onChanged: onChanged,
    );
  }
}

// select_field_widget.dart
class _SelectFieldWidget extends StatelessWidget {
  final CATFormField field;
  final ValueChanged<String?> onChanged;
  
  @override
  Widget build(BuildContext context) {
    // Parse options from field.optionsSource
    final options = _parseOptions(field.optionsSource);
    
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(labelText: field.label),
      items: options.map((opt) {
        return DropdownMenuItem(
          value: opt['value'],
          child: Text(opt['label']),
        );
      }).toList(),
      validator: (value) {
        if (field.required && value == null) {
          return 'Campo requerido';
        }
        return null;
      },
      onChanged: onChanged,
    );
  }
  
  List<Map<String, String>> _parseOptions(String? source) {
    if (source == null) return [];
    
    // Si es JSON array: [{"value": "A", "label": "Opción A"}]
    if (source.startsWith('[')) {
      return (jsonDecode(source) as List)
          .map((e) => Map<String, String>.from(e))
          .toList();
    }
    
    // Si es referencia a catálogo: "cat_municipios"
    // TODO: fetch from catalog table
    
    return [];
  }
}
```

**Commit:**
```
feat(mobile/forms): implement field widget components

- TextFieldWidget with regex validation
- NumberFieldWidget with min/max
- SelectFieldWidget with dynamic options
- DateFieldWidget with date picker
- TimeFieldWidget with time picker
- GPSFieldWidget with location capture
- PhotoFieldWidget with image picker
```

#### 3.3 EAV Storage
**mobile/lib/data/repositories/activity_repository.dart**

```dart
class ActivityRepository {
  final AppDatabase _db;
  
  Future<void> saveActivity(Activity activity, Map<String, dynamic> fields) async {
    await _db.transaction(() async {
      // 1. Guardar Activity
      await _db.into(_db.activities).insert(activity.toCompanion());
      
      // 2. Guardar campos dinámicos en ActivityFields (EAV)
      final fieldCompanions = fields.entries.map((e) {
        return ActivityFieldsCompanion.insert(
          activityId: activity.id,
          fieldKey: e.key,
          fieldValue: e.value.toString(),
        );
      }).toList();
      
      await _db.batch((batch) {
        batch.insertAll(_db.activityFields, fieldCompanions);
      });
      
      // 3. Agregar a sync queue
      await _db.into(_db.syncQueue).insert(
        SyncQueueCompanion.insert(
          entityType: 'activity',
          entityId: activity.id,
          operation: SyncOperation.create,
          payload: jsonEncode({
            'activity': activity.toJson(),
            'fields': fields,
          }),
        ),
      );
    });
  }
  
  Future<Map<String, dynamic>> getActivityFields(String activityId) async {
    final fields = await (_db.select(_db.activityFields)
          ..where((tbl) => tbl.activityId.equals(activityId)))
        .get();
    
    return Map.fromEntries(
      fields.map((f) => MapEntry(f.fieldKey, f.fieldValue)),
    );
  }
}
```

**Commit:**
```
feat(mobile/activity): implement EAV storage for dynamic fields

- ActivityRepository.saveActivity() saves to activity_fields
- getActivityFields() reconstructs Map from EAV
- Transactional save (activity + fields + sync_queue)
```

#### 3.4 Integración en Wizard
**mobile/lib/features/activities/wizard/wizard_step_details.dart**

```dart
class WizardStepDetails extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(wizardControllerProvider);
    final activityTypeId = controller.activityTypeId;
    
    return Scaffold(
      appBar: AppBar(title: Text("Detalles")),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // Campos estáticos (título, descripción)
              TextField(
                decoration: InputDecoration(labelText: "Título"),
                onChanged: (value) => controller.setTitle(value),
              ),
              
              SizedBox(height: 16),
              
              // Campos dinámicos desde catálogo
              DynamicFormBuilder(
                activityTypeId: activityTypeId,
                initialValues: controller.dynamicFields,
                onChanged: (fields) {
                  controller.setDynamicFields(fields);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**Commit:**
```
feat(mobile/wizard): integrate DynamicFormBuilder in wizard

- Replace hardcoded form fields with DynamicFormBuilder
- Load fields from catalog based on activityTypeId
- Save dynamic fields to WizardController state
- Remove old hardcoded step implementations
```

### Checklist Fase 3
- [ ] DynamicFormBuilder renderiza todos los widgets
- [ ] Validaciones funcionando (required, regex)
- [ ] Conditional visibility implementada
- [ ] Guardar en activity_fields correctamente
- [ ] Wizard usa DynamicFormBuilder
- [ ] NO hay campos hardcoded en wizard
- [ ] Tests de form builder pasando

**PR Title:** `feat: Fase 3 - Dynamic form builder from catalog`

---

## 📦 FASE 4: Motor de Workflow (2 semanas)

### Objetivos
- ✅ WorkflowService valida transiciones
- ✅ Móvil muestra botones dinámicos según transiciones disponibles
- ✅ Validaciones antes de transición (campos requeridos, evidencia)
- ✅ Activity log registra cada cambio

### Commits

#### 4.1 Workflow Service (Backend)
**backend/app/services/workflow_service.py**

```python
class WorkflowService:
    def __init__(self, db: Session):
        self.db = db
    
    def get_available_transitions(
        self,
        activity_id: UUID,
        user_id: UUID
    ) -> list[dict]:
        """Devuelve transiciones disponibles para el usuario"""
        activity = self.db.query(Activity).get(activity_id)
        if not activity:
            raise HTTPException(404, "Activity not found")
        
        # Obtener roles del usuario para esta actividad
        user_roles = self._get_user_roles_for_activity(user_id, activity)
        
        # Buscar transiciones desde el estado actual
        transitions = self.db.query(CATWorkflowTransition).filter(
            CATWorkflowTransition.version_id == activity.catalog_version_id,
            CATWorkflowTransition.from_state_code == activity.status
        ).all()
        
        # Filtrar por roles permitidos
        allowed = []
        for trans in transitions:
            if any(role.id in trans.allowed_roles for role in user_roles):
                # Validar campos requeridos
                can_transition = self._validate_required_fields(activity, trans)
                
                allowed.append({
                    "transition_id": str(trans.id),
                    "label": trans.label,
                    "to_state": trans.to_state_code,
                    "can_execute": can_transition,
                    "blocking_reasons": self._get_blocking_reasons(activity, trans)
                })
        
        return allowed
    
    def execute_transition(
        self,
        activity_id: UUID,
        transition_id: UUID,
        user_id: UUID,
        comment: str = None
    ):
        """Ejecuta una transición de workflow"""
        activity = self.db.query(Activity).get(activity_id)
        transition = self.db.query(CATWorkflowTransition).get(transition_id)
        
        # Validar que puede ejecutar
        can_execute = self._can_user_execute_transition(
            user_id, activity, transition
        )
        if not can_execute:
            raise HTTPException(403, "Not allowed to execute this transition")
        
        # Validar campos requeridos
        if not self._validate_required_fields(activity, transition):
            raise HTTPException(400, "Required fields missing")
        
        # Validar evidencia si es requerida
        if transition.required_evidence:
            if not self._has_minimum_evidence(activity):
                raise HTTPException(400, "Missing required evidence")
        
        # Ejecutar transición
        old_status = activity.status
        activity.status = transition.to_state_code
        activity.updated_at = datetime.utcnow()
        
        # Registrar en activity_log
        log_entry = ActivityLog(
            id=uuid4(),
            activity_id=activity_id,
            user_id=user_id,
            action="status_changed",
            from_value=old_status,
            to_value=transition.to_state_code,
            comment=comment,
            created_at=datetime.utcnow()
        )
        self.db.add(log_entry)
        
        self.db.commit()
        
        return {
            "new_status": activity.status,
            "message": f"Transition executed: {transition.label}"
        }
```

**Commit:**
```
feat(services): add WorkflowService for state transitions

- get_available_transitions() filters by user roles
- execute_transition() validates and updates status
- _validate_required_fields() checks form completion
- _has_minimum_evidence() checks evidence rules
- Logs every transition in activity_log
```

#### 4.2 Workflow API
**backend/app/api/activities.py**

```python
@router.get("/{activity_id}/transitions")
async def get_transitions(
    activity_id: UUID,
    current_user: User = Depends(get_current_user)
):
    """Obtiene transiciones disponibles para una actividad"""
    service = WorkflowService(db)
    transitions = service.get_available_transitions(activity_id, current_user.id)
    return transitions

@router.post("/{activity_id}/transition")
async def execute_transition(
    activity_id: UUID,
    body: TransitionRequest,
    current_user: User = Depends(get_current_user)
):
    """Ejecuta una transición de workflow"""
    service = WorkflowService(db)
    result = service.execute_transition(
        activity_id,
        body.transition_id,
        current_user.id,
        body.comment
    )
    return result
```

**Commit:**
```
feat(api): add workflow transition endpoints

- GET /activities/{id}/transitions
- POST /activities/{id}/transition
- Returns available transitions with can_execute flag
- Validates permissions and required fields
```

#### 4.3 Workflow Widget (Móvil)
**mobile/lib/features/activities/widgets/workflow_actions.dart**

```dart
class WorkflowActions extends ConsumerWidget {
  final String activityId;
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transitions = ref.watch(availableTransitionsProvider(activityId));
    
    return transitions.when(
      data: (list) {
        if (list.isEmpty) {
          return SizedBox.shrink();
        }
        
        return Wrap(
          spacing: 8,
          children: list.map((transition) {
            return ElevatedButton.icon(
              onPressed: transition.canExecute
                  ? () => _executeTransition(context, ref, transition)
                  : null,
              icon: Icon(_getIconForTransition(transition)),
              label: Text(transition.label),
              style: _getStyleForTransition(transition),
            );
          }).toList(),
        );
      },
      loading: () => CircularProgressIndicator(),
      error: (e, s) => Text("Error: $e"),
    );
  }
  
  Future<void> _executeTransition(
    BuildContext context,
    WidgetRef ref,
    WorkflowTransition transition,
  ) async {
    // Mostrar diálogo de confirmación si existe
    if (transition.confirmMessage != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Confirmar"),
          content: Text(transition.confirmMessage!),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text("Confirmar"),
            ),
          ],
        ),
      );
      
      if (confirmed != true) return;
    }
    
    // Ejecutar transición
    try {
      await ref.read(activityRepositoryProvider).executeTransition(
        activityId: activityId,
        transitionId: transition.id,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Estado actualizado")),
      );
      
      // Refrescar datos
      ref.invalidate(availableTransitionsProvider(activityId));
      ref.invalidate(activityProvider(activityId));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }
}
```

**Commit:**
```
feat(mobile/workflow): add WorkflowActions widget

- Fetches available transitions from backend
- Renders dynamic buttons for each transition
- Shows confirmation dialog if configured
- Executes transition and refreshes UI
- Handles validation errors gracefully
```

#### 4.4 Activity Log Viewer
**mobile/lib/features/activities/details/activity_log_tab.dart**

```dart
class ActivityLogTab extends ConsumerWidget {
  final String activityId;
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(activityLogsProvider(activityId));
    
    return logs.when(
      data: (logList) => ListView.builder(
        itemCount: logList.length,
        itemBuilder: (context, index) {
          final log = logList[index];
          return ListTile(
            leading: CircleAvatar(
              child: Icon(_getIconForAction(log.action)),
            ),
            title: Text(_getDescriptionForLog(log)),
            subtitle: Text(log.userName),
            trailing: Text(
              formatDateTime(log.createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          );
        },
      ),
      loading: () => CircularProgressIndicator(),
      error: (e, s) => Text("Error: $e"),
    );
  }
  
  String _getDescriptionForLog(ActivityLog log) {
    switch (log.action) {
      case 'created':
        return 'Actividad creada';
      case 'status_changed':
        return 'Estado: ${log.fromValue} → ${log.toValue}';
      case 'assigned':
        return 'Asignada a ${log.toValue}';
      case 'field_updated':
        return 'Campo actualizado: ${log.comment}';
      default:
        return log.action;
    }
  }
}
```

**Commit:**
```
feat(mobile/activity): add activity log viewer

- ActivityLogTab shows chronological history
- Displays user, action, timestamp
- Formatted descriptions for each action type
- Pull-to-refresh support
```

### Checklist Fase 4
- [ ] Backend valida transiciones según roles
- [ ] Móvil muestra solo botones permitidos
- [ ] Validaciones bloquean transiciones inválidas
- [ ] ActivityLog registra cada cambio
- [ ] UI muestra historial de cambios
- [ ] Tests de workflow service pasando

**PR Title:** `feat: Fase 4 - Configurable workflow engine with validation`

---

## 📦 FASE 5: Sync Incremental (2 semanas)

### Objetivos
- ✅ Sync bidireccional (push + pull)
- ✅ Retry automático con backoff
- ✅ Detección de conflictos
- ✅ Delta sync (solo cambios)

### Commits

#### 5.1 Sync API (Backend)
**backend/app/api/sync.py**

```python
@router.post("/push")
async def push_changes(
    body: SyncPushRequest,
    current_user: User = Depends(get_current_user)
):
    """Recibe cambios del móvil (outbox items)"""
    results = []
    
    for item in body.items:
        try:
            # Aplicar cambio según entity_type y operation
            if item.entity_type == "activity":
                if item.operation == "create":
                    _create_activity(item.payload)
                elif item.operation == "update":
                    _update_activity(item.entity_id, item.payload)
                # ...
            
            results.append({
                "id": item.id,
                "status": "synced",
                "server_id": item.entity_id
            })
        except Exception as e:
            results.append({
                "id": item.id,
                "status": "error",
                "error": str(e)
            })
    
    return {"results": results}

@router.get("/pull")
async def pull_changes(
    since: datetime = Query(...),
    current_user: User = Depends(get_current_user)
):
    """Devuelve cambios desde una fecha"""
    # Filtrar por scopes del usuario
    scopes = get_user_scopes(current_user.id)
    
    # Activities modificadas desde 'since'
    activities = db.query(Activity).filter(
        Activity.updated_at > since,
        # Filtrar por scopes
    ).all()
    
    # Events modificados
    events = db.query(Event).filter(
        Event.updated_at > since
    ).all()
    
    return {
        "activities": [a.to_dict() for a in activities],
        "events": [e.to_dict() for e in events],
        "timestamp": datetime.utcnow().isoformat()
    }
```

**Commit:**
```
feat(api): add sync push/pull endpoints

- POST /sync/push receives outbox items
- GET /sync/pull?since=... returns delta changes
- Scope filtering for multi-tenant
- Returns timestamps for next sync
```

#### 5.2 Sync Engine (Móvil)
**mobile/lib/features/sync/sync_engine.dart**

```dart
class SyncEngine {
  final AppDatabase _db;
  final ApiClient _api;
  final Logger _logger;
  
  Future<SyncResult> syncAll() async {
    try {
      // 1. Push pending changes
      final pushResult = await _pushPendingChanges();
      
      // 2. Pull remote changes
      final pullResult = await _pullRemoteChanges();
      
      return SyncResult(
        pushedCount: pushResult.synced,
        pulledCount: pullResult.applied,
        conflicts: pushResult.conflicts + pullResult.conflicts,
      );
    } catch (e, s) {
      _logger.error("Sync failed", e, s);
      rethrow;
    }
  }
  
  Future<PushResult> _pushPendingChanges() async {
    // Leer sync_outbox
    final items = await (_db.select(_db.syncQueue)
          ..where((tbl) => tbl.status.equals('pending'))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt)]))
        .get();
    
    if (items.isEmpty) {
      return PushResult(synced: 0, conflicts: []);
    }
    
    // Enviar en lotes de 50
    final batches = _chunk(items, 50);
    int synced = 0;
    List<Conflict> conflicts = [];
    
    for (final batch in batches) {
      try {
        final response = await _api.pushChanges(
          batch.map((e) => e.toJson()).toList(),
        );
        
        // Procesar resultados
        for (final result in response.results) {
          final item = batch.firstWhere((e) => e.id == result.id);
          
          if (result.status == 'synced') {
            await _markAsSynced(item);
            synced++;
          } else if (result.status == 'error') {
            await _markAsError(item, result.error);
            if (result.error.contains('conflict')) {
              conflicts.add(Conflict.fromSyncItem(item));
            }
          }
        }
      } catch (e) {
        _logger.error("Push batch failed", e);
        // Retry logic con backoff exponencial
        await _scheduleBatchRetry(batch);
      }
    }
    
    return PushResult(synced: synced, conflicts: conflicts);
  }
  
  Future<PullResult> _pullRemoteChanges() async {
    // Obtener timestamp del último sync
    final syncState = await _db.syncState.getSingle();
    final since = syncState?.lastSyncAt ?? DateTime(2020);
    
    // GET /sync/pull
    final response = await _api.pullChanges(since: since);
    
    int applied = 0;
    List<Conflict> conflicts = [];
    

    await _db.transaction(() async {
      // Aplicar activities
      for (final activityData in response.activities) {
        final existing = await _db.activities.getById(activityData['id']);
        
        if (existing != null) {
          // Detectar conflicto (updated_at local > remoto)
          if (existing.updatedAt.isAfter(activityData['updated_at'])) {
            conflicts.add(Conflict.fromActivity(existing, activityData));
            continue;
          }
        }
        
        // Aplicar cambio
        await _db.into(_db.activities).insert(
          Activity.fromJson(activityData).toCompanion(),
          mode: InsertMode.insertOrReplace,
        );
        applied++;
      }
      
      // Aplicar events
      // ...
      
      // Actualizar sync_state
      await _db.update(_db.syncState).write(
        SyncStateCompanion(
          lastSyncAt: Value(DateTime.parse(response.timestamp)),
        ),
      );
    });
    
    return PullResult(applied: applied, conflicts: conflicts);
  }
  
  Future<void> _markAsSynced(SyncQueueItem item) async {
    await (_db.update(_db.syncQueue)
          ..where((tbl) => tbl.id.equals(item.id)))
        .write(SyncQueueCompanion(
          status: Value(SyncStatus.synced),
          syncedAt: Value(DateTime.now()),
        ));
  }
  
  Future<void> _scheduleBatchRetry(List<SyncQueueItem> batch) async {
    for (final item in batch) {
      await (_db.update(_db.syncQueue)
            ..where((tbl) => tbl.id.equals(item.id)))
          .write(SyncQueueCompanion(
            retryCount: Value(item.retryCount + 1),
            status: Value(SyncStatus.pending),
          ));
    }
  }
}
```

**Commit:**
```
feat(mobile/sync): implement bidirectional sync engine

- syncAll() orchestrates push + pull
- _pushPendingChanges() sends outbox in batches
- _pullRemoteChanges() applies delta updates
- Conflict detection (last-write-wins)
- Retry logic with exponential backoff
- Updates sync_state timestamp
```

#### 5.3 Background Sync
**mobile/lib/features/sync/background_sync_service.dart**

```dart
class BackgroundSyncService {
  final SyncEngine _engine;
  Timer? _timer;
  
  void startPeriodicSync({Duration interval = const Duration(minutes: 15)}) {
    _timer?.cancel();
    
    _timer = Timer.periodic(interval, (timer) async {
      if (await _hasConnectivity()) {
        try {
          await _engine.syncAll();
          print("Background sync completed");
        } catch (e) {
          print("Background sync failed: $e");
        }
      }
    });
  }
  
  void stopPeriodicSync() {
    _timer?.cancel();
    _timer = null;
  }
  
  Future<bool> _hasConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }
}
```

**Commit:**
```
feat(mobile/sync): add background sync service

- Periodic sync every 15 minutes
- Checks connectivity before syncing
- Graceful error handling
- Start/stop methods for lifecycle management
```

#### 5.4 Conflict Resolution UI
**mobile/lib/features/sync/conflict_resolver_page.dart**

```dart
class ConflictResolverPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflicts = ref.watch(conflictsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text("Conflictos de Sincronización"),
      ),
      body: conflicts.when(
        data: (list) {
          if (list.isEmpty) {
            return Center(child: Text("No hay conflictos"));
          }
          
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final conflict = list[index];
              return ConflictCard(
                conflict: conflict,
                onResolve: (resolution) {
                  ref.read(syncRepositoryProvider).resolveConflict(
                    conflict.id,
                    resolution,
                  );
                },
              );
            },
          );
        },
        loading: () => CircularProgressIndicator(),
        error: (e, s) => Text("Error: $e"),
      ),
    );
  }
}

class ConflictCard extends StatelessWidget {
  final Conflict conflict;
  final ValueChanged<ConflictResolution> onResolve;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Actividad: ${conflict.activityTitle}",
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("Tu versión: ${conflict.localUpdatedAt}"),
            Text("Versión servidor: ${conflict.remoteUpdatedAt}"),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => onResolve(ConflictResolution.keepLocal),
                  child: Text("Conservar Mía"),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => onResolve(ConflictResolution.keepRemote),
                  child: Text("Usar Servidor"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

**Commit:**
```
feat(mobile/sync): add conflict resolution UI

- ConflictResolverPage lists all conflicts
- ConflictCard shows local vs remote differences
- User can choose: keep local or keep remote
- Resolves conflict and retries sync
```

### Checklist Fase 5
- [ ] Push sync envía cambios en lotes
- [ ] Pull sync descarga solo delta
- [ ] Background sync cada 15 minutos
- [ ] Conflictos detectados y mostrados en UI
- [ ] Retry automático con backoff
- [ ] Tests de sync engine pasando

**PR Title:** `feat: Fase 5 - Bidirectional sync with conflict resolution`

---

## 📦 FASES 6-9: Resumen

Por brevedad, aquí está el resumen de las fases restantes:

### FASE 6: Eventos + Coordinador (2 semanas)
- Backend API `/events`
- Móvil: Reportar evento desde FAB
- Convertir evento → actividad
- Agenda coordinador (ya existe parcialmente)
- Asignación con conflictos

### FASE 7: Escritorio Admin (4 semanas)
- Setup Flutter Windows
- UI con `fluent_ui`
- Catalog Manager (CRUD versiones)
- Form Builder visual (drag-drop)
- Workflow Editor (canvas de estados)
- User Admin (CRUD usuarios + roles/scopes)
- Preview móvil

### FASE 8: Evidencias + Storage (1 semana)
- Backend integración MinIO/S3
- Upload multipart
- Compresión de imágenes
- Pre-signed URLs para download

### FASE 9: Reportes y Auditoría (1 semana)
- Templates Jinja2
- Generación PDF (reportlab)
- Desktop: Selector de filtros + preview
- Audit log viewer

---

## 📊 Timeline Total

```
Semana 1-2:   FASE 1 - Backend + Auth ✅
Semana 3-4:   FASE 2 - Catálogos Versionados ✅
Semana 5-6:   FASE 3 - Form Builder Dinámico ✅
Semana 7-8:   FASE 4 - Workflow Engine ✅
Semana 9-10:  FASE 5 - Sync Incremental ✅
Semana 11-12: FASE 6 - Eventos + Coordinador ✅
Semana 13-16: FASE 7 - Escritorio Admin ✅
Semana 17:    FASE 8 - Evidencias + Storage ✅
Semana 18:    FASE 9 - Reportes ✅

Total: ~4.5 meses (18 semanas)
```

---

## 🎯 Próximos Pasos

1. **Review de ARCHITECTURE.md y este plan**
2. **Crear rama `feature/fase1-auth`**
3. **Implementar commits de Fase 1 (2.1-2.8)**
4. **Tests unitarios para cada servicio**
5. **PR y merge a `develop`**
6. **Repetir para Fase 2...**

---

**Última actualización:** 2026-02-17
**Versión del documento:** 1.0
