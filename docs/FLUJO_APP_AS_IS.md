# Flujo Operativo SAO (AS-IS)

## Objetivo
Documentar el flujo **actual implementado** en la app para personal operativo: asignación, inicio, término, captura en wizard, cancelación y sincronización.

## Resumen ejecutivo
- Las actividades del día hoy están cargadas como dataset local (seed/mock en Home).
- El flujo operativo principal usa swipe derecho por estados: **Pendiente → En curso → Revisión pendiente → Terminada**.
- El wizard de registro tiene 4 pasos: Contexto, Clasificación, Evidencias y Confirmación.
- Si el usuario no guarda el wizard, la actividad queda en **Revisión pendiente** para reintento.
- La sincronización de **catálogos** sí está implementada; la de **actividades/evidencias** está parcialmente implementada (cola local y repositorio, pero sin worker end-to-end final).

---

## Diagrama de flujo AS-IS

```mermaid
flowchart TD
    A[Inicio de jornada / Home] --> B[Carga actividades del día\n(Seed local en Home)]
    B --> C{Usuario hace swipe derecho}

    C -->|Estado Pendiente| D[Iniciar actividad]
    D --> D1[Registrar horaInicio + GPS mock]
    D1 --> E[Estado En curso]

    C -->|Estado En curso| F[Terminar actividad]
    F --> F1[Registrar horaFin]
    F1 --> G[Estado Revisión pendiente]
    G --> H[Abrir Wizard de registro]

    C -->|Estado Revisión pendiente| H

    H --> H1[Paso 1: Contexto]
    H1 --> H2[Paso 2: Clasificación]
    H2 --> H3[Paso 3: Evidencias]
    H3 --> H4[Paso 4: Confirmar]

    H4 --> I{Guardar exitoso}
    I -->|Sí| J[Guardar actividad en Drift\nstatus DRAFT]
    J --> K[Regresar Home con resultado]
    K --> L[Estado Terminada]

    I -->|No o error| M[Se mantiene en Revisión pendiente]
    H -->|Cancelar/salir| M

    B --> N{Swipe izquierdo}
    N --> O[Reportar incidencia]
    O --> P[Regresa a Pendiente]

    J --> Q[Posible encolado para sync\n(READY_TO_SYNC + SyncQueue)]
    Q --> R[Centro de Sincronización\n(estado aún parcial)]
```

---

## Flujo por etapa (AS-IS)

### 1) Asignación de actividades
1. Personal abre Home.
2. App muestra actividades del día (actualmente mock local por proyecto/frente).
3. Cada actividad inicia en estado de ejecución **Pendiente**.

### 2) Inicio de actividad
1. Swipe derecho en actividad pendiente.
2. Sistema registra hora de inicio y GPS (mock).
3. Estado cambia a **En curso**.

### 3) Término de actividad
1. Swipe derecho en actividad en curso.
2. Sistema registra hora fin.
3. Estado cambia a **Revisión pendiente**.
4. Se abre wizard para captura final.

### 4) Captura en wizard
Pasos:
1. Contexto
2. Clasificación
3. Evidencias
4. Confirmación y Guardar

Reglas relevantes:
- En paso de evidencias, UI permite continuar sin evidencia.
- En guardado final, gatekeeper valida consistencia completa y exige evidencia válida para cerrar correctamente.

### 5) Cancelación / abandono
- Si usuario cierra/cancela sin guardar: actividad queda en **Revisión pendiente**.
- Puede reabrirse con swipe derecho para completar captura.

### 6) Incidencias
- Swipe izquierdo abre modal de incidencias rápidas.
- Al registrar incidencia, estado operativo vuelve a **Pendiente**.

### 7) Sincronización a nube
- **Catálogos:** sincronización versionada implementada (diff/snapshot/fallback local).
- **Actividades/Evidencias:** existe estructura de cola (`SyncQueue`) y repositorio, pero flujo end-to-end aún parcial.

---

## Máquina de estados operativa (AS-IS)

| Estado actual | Evento usuario | Estado siguiente | Comentario |
|---|---|---|---|
| Pendiente | Swipe derecho (Iniciar) | En curso | Guarda horaInicio |
| En curso | Swipe derecho (Terminar) | Revisión pendiente | Guarda horaFin + abre wizard |
| Revisión pendiente | Guardado wizard exitoso | Terminada | Cierre funcional en Home |
| Revisión pendiente | Cancelar / error en guardado | Revisión pendiente | Reintento posterior |
| Cualquier estado visible | Swipe izquierdo (incidencia) | Pendiente | Flujo rápido de bloqueo/incidencia |

---

## Riesgos operativos actuales
- Asignación diaria aún depende de seed local (no backend real en este flujo).
- Hay diferencia entre mensajes UX de evidencia y validación final de guardado.
- Sync de actividades/evidencias todavía no cierra ciclo completo de subida automática.
