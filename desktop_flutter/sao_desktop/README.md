# SAO Desktop - sistema de administración y control

## Consola central para la gestión operativa

SAO Desktop funciona como consola de validación, control y seguimiento para las actividades capturadas desde la app móvil.

### Funcionalidad actual

#### ✅ Implementado

**1. Tablero**
- KPIs principales: pendientes, aprobadas, rechazadas y total.

**2. Operaciones > Validación**
- Vista principal con 3 paneles: cola, formulario y evidencias.
- Atajos de teclado:
  - `Enter` para aprobar y avanzar.
  - `R` para rechazar.
  - `Esc` para saltar actividad.
- Navegación fluida entre registros.
- Evidencias con metadatos de GPS y tiempo.
- Comentarios estructurados para rechazo.

**3. Base local con Drift**
- Persistencia SQLite para operación local.
- Datos semilla para pruebas y navegación inicial.
- Soporte de trabajo sin conexión en flujos acotados.

**4. Arquitectura**
- Separación por capas de datos, dominio y presentación.
- Riverpod para manejo de estado.
- Repositorios reactivos y desacoplados.

**5. Módulos complementarios**
- Planeación.
- Catálogos.
- Usuarios.
- Reportes.

### Estructura de carpetas

```text
lib/
├── main.dart
├── app/
├── data/
├── features/
└── ui/
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

#### 4. Compilación limpia en macOS fuera de Documents o iCloud

Si macOS falla por firma o metadatos Finder, usar el script de compilación limpia disponible en la carpeta de diagnóstico.

### Uso general

1. La aplicación abre en la vista de validación.
2. La cola lateral muestra actividades pendientes.
3. El panel central presenta detalle del expediente.
4. El panel derecho muestra la evidencia asociada.
5. Las acciones pueden ejecutarse con botones o atajos.

### Atajos de teclado

- `Enter`: aprobar y avanzar.
- `R`: abrir diálogo de rechazo.
- `Esc`: saltar sin acción.
- Flechas en galería: navegar entre evidencias.

### Base de datos local

**Ubicación**: carpeta Documents del usuario.

Incluye datos de prueba para usuarios, proyectos, frentes, municipios, motivos de rechazo y actividades con evidencia.

### Modo offline

- ✅ La consola puede seguir operando en tareas locales.
- ✅ Los cambios se almacenan en cola local.
- ⏳ La sincronización completa con backend debe seguir validándose por flujo.

### Próximos pasos

1. Terminar sincronización real con backend.
2. Ampliar planeación con calendario o Gantt.
3. Completar CRUD de catálogos y usuarios.
4. Robustecer reportes y exportaciones.
5. Mejorar visor de evidencias y mapas.

### Pila técnica

- Flutter Desktop.
- Drift para persistencia local.
- Riverpod para estado.
- Material Design 3.
- Arquitectura limpia por capas.

---

**Estado**: compilando y funcional  
**Fecha**: febrero de 2026
