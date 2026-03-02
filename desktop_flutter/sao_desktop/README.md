# SAO Desktop - Sistema de Administración y Control

## Consola Central para Gestión de SAO Mobile

SAO Desktop es la "fuente de verdad" que administra y controla las actividades capturadas por SAO Mobile.

### Características

#### ✅ Implementado

**1. Dashboard**
- KPIs principales: Pendientes, Aprobadas, Rechazadas, Total

**2. Operaciones > Validación** (Pantalla principal funcional)
- **3 paneles**: Cola / Formulario / Evidencias
- **Atajos de teclado**:
  - `Enter` → Aprobar y pasar a siguiente
  - `R` → Rechazar (abre diálogo)
  - `Esc` → Saltar actividad
- Navegación fluida entre actividades
- Visualización de evidencias con metadata GPS/timestamp
- Sistema de comentarios para rechazo

**3. Base de datos SQLite (Drift)**
- 10 tablas: Users, Projects, ActivityTypes, Activities, Evidences, Assignments, Fronts, Municipalities, RejectionReasons, SyncQueue
- Seed data automático con 10 actividades de prueba
- Offline-first: funciona sin internet

**4. Arquitectura**
- Data/Domain/Presentation layers
- Riverpod para state management
- Repositorios con Streams reactivos

**5. Módulos placeholder**
- Planeación (asignación de actividades)
- Catálogos (tipos, frentes, municipios)
- Usuarios (gestión de permisos)
- Reportes (generación de informes)

### Estructura de carpetas

```
lib/
├── main.dart                    # Entry point + DB init
├── app/
│   └── shell.dart              # NavigationRail + TopBar
├── data/
│   ├── database/
│   │   ├── app_database.dart   # DB principal con seed
│   │   └── tables.dart         # Schema de 10 tablas
│   ├── models/
│   │   └── activity_model.dart # ActivityWithDetails
│   └── repositories/
│       └── activity_repository.dart # CRUD + Streams
└── features/
    ├── dashboard/
    │   └── dashboard_page.dart
    ├── operations/
    │   ├── validation_page.dart
    │   └── widgets/
    │       ├── activity_queue_panel.dart
    │       ├── activity_form_panel.dart
    │       ├── evidence_gallery_panel.dart
    │       └── review_actions.dart
    ├── planning/
    ├── catalogs/
    ├── users/
    └── reports/
```

### Instalación y ejecución

#### 1. Instalar dependencias

```powershell
cd d:\SAO\desktop_flutter\sao_desktop
flutter pub get
```

#### 2. Generar código de Drift

```powershell
dart run build_runner build --delete-conflicting-outputs
```

#### 3. Ejecutar en Windows

```powershell
flutter run -d windows
```

**Nota sobre el icono**: Si muestra error sobre `app_icon.ico`, puedes:
- Crear un archivo vacío: `New-Item -Path "windows\runner\resources\app_icon.ico" -ItemType File`
- O usar un icono real de 256x256px en formato .ico

### Uso

1. **Al iniciar**: La app abre automáticamente en **Operaciones > Validación**
2. **Cola izquierda**: Muestra 10 actividades pendientes de revisión con seed data
3. **Panel central**: Detalles completos de la actividad seleccionada
4. **Panel derecho**: Galería de evidencias fotográficas
5. **Acciones**:
   - Click en cualquier actividad de la cola para seleccionarla
   - Navegar entre evidencias con flechas
   - Aprobar/Rechazar/Saltar con botones o atajos de teclado

### Keyboard Shortcuts

- `Enter` - Aprobar actividad y pasar a siguiente
- `R` - Abrir diálogo de rechazo
- `Esc` - Saltar a siguiente actividad sin acción
- Flechas en galería - Navegar entre evidencias

### Base de datos

**Ubicación**: `%USERPROFILE%\Documents\sao_desktop.db`

**Seed data automático**:
- 3 usuarios (Admin, Coordinador, Ingeniero)
- 1 proyecto (TMQ)
- 5 tipos de actividad
- 4 frentes
- 4 municipios
- 6 motivos de rechazo
- **10 actividades con estado PENDING_REVIEW**
- 2-4 evidencias por actividad (20+ evidencias totales)

### Modo Offline

- ✅ Toda la operación funciona sin internet
- ✅ Cambios se guardan en `sync_queue` tabla
- ⏳ Sincronización con backend (pendiente de implementar)

### Próximos pasos

1. **Sincronización real**: Conectar sync_queue con API REST
2. **Planeación**: Calendario/Gantt para asignación de actividades
3. **Catálogos**: CRUD completo para tipos, frentes, etc.
4. **Usuarios**: Gestión de roles y permisos
5. **Reportes**: Exportar a PDF/Word con plantillas
6. **Evidencias reales**: Integrar visor de imágenes desde filesystem
7. **Maps**: Integrar Google Maps/OpenStreetMap para GPS

### Stack técnico

- Flutter 3.x Desktop (Windows)
- Drift 2.31.0 (SQLite ORM)
- Riverpod 2.6.1 (State management)
- Material Design 3
- Architecture: Clean Architecture (Data/Domain/Presentation)

---

**Estado**: ✅ Compilando y funcional
**Fecha**: Feb 2026
**Autor**: GitHub Copilot
