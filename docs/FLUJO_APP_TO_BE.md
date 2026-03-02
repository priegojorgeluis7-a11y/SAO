# Flujo Operativo SAO (TO-BE)

## Objetivo
Definir el flujo objetivo para operación real de campo, con asignación remota, captura robusta, cancelación controlada y sincronización completa a nube.

## Principios TO-BE
- Operación **offline-first**: nada se pierde sin conexión.
- Trazabilidad completa: estados, eventos y evidencias auditables.
- Validación consistente: reglas iguales entre UI y guardado final.
- Sincronización automática con reintentos y observabilidad.

## Visión de tutorial (modo guiado)
- En la pantalla de acceso, el usuario puede activar un switch: **Entrar en modo tutorial**.
- Si está activo, entra al tutorial **sin iniciar sesión**.
- El tutorial muestra una pantalla guiada con pasos operativos:
    1. Revisar actividades asignadas.
    2. Iniciar actividad (tiempo/ubicación).
    3. Terminar y capturar en wizard.
    4. Guardar y sincronizar.
    5. Qué pasa si cancela (queda en revisión pendiente).
- El tutorial se usa como onboarding práctico para personal nuevo o de refuerzo.
- Desde esa pantalla, el usuario puede salir a operación real con **Comenzar operación real**.

---

## Diagrama de flujo TO-BE

```mermaid
flowchart TD
    A[Login + selección de proyecto] --> A1{Switch modo tutorial}
    A1 -->|ON| A2[Pantalla tutorial guiada\n(sin login)]
    A1 -->|OFF| B[Bootstrap de catálogos\n(sync versionado)]
    A2 --> A3[Comenzar operación real]
    A3 --> B
    B --> C[Descarga asignaciones del día\npor usuario/rol/frente]
    C --> D[Home con agenda real\n(Pendiente/En curso/Revisión/Terminada)]

    D --> E{Swipe derecho}
    E -->|Pendiente| F[Iniciar actividad]
    F --> F1[Guardar startedAt + geolocalización + auditoría]
    F1 --> G[En curso]

    E -->|En curso| H[Terminar actividad]
    H --> H1[Guardar finishedAt]
    H1 --> I[Revisión pendiente]
    I --> J[Abrir Wizard]

    E -->|Revisión pendiente| J

    J --> J1[Paso 1 Contexto]
    J1 --> J2[Paso 2 Clasificación\n(catálogos relacionales)]
    J2 --> J3[Paso 3 Evidencias\n(foto/video/PDF + metadata)]
    J3 --> J4[Paso 4 Confirmación]

    J4 --> K{Validación Gatekeeper}
    K -->|Inválido| K1[Resaltar campo y regresar al paso]
    K1 --> J
    K -->|Válido| L[Guardar local: Activity + Fields + Evidence]

    L --> M[Marcar READY_TO_SYNC\ninsertar SyncQueue]
    M --> N{Conectividad}
    N -->|Online| O[Sync Worker en background]
    N -->|Offline| P[Queda en cola local]

    O --> Q{Resultado API}
    Q -->|OK| R[Marcar SYNCED + SYNC_OK]
    Q -->|Error temporal| S[Retry exponencial]
    S --> O
    Q -->|Error permanente| T[Marcar ERROR + mensaje acción]

    P --> U[Usuario abre Centro Sync\n(forzar sync / retry / limpiar)]
    U --> O

    D --> V{Swipe izquierdo}
    V --> W[Incidencia/Bloqueo]
    W --> X[Estado CANCELED o BLOQUEADA\nsegún política]
```

---

## Flujo de trabajo TO-BE para personal

### 1) Inicio de jornada
1. Inicia sesión.
2. Se sincronizan catálogos para el proyecto seleccionado.
3. Se descargan asignaciones reales del día por usuario.

### 2) Ejecución en campo
1. Inicia actividad (timestamp + geolocalización).
2. Realiza trabajo en sitio.
3. Termina actividad y abre captura (wizard).

### 3) Captura obligatoria y cierre
1. Completa contexto, clasificación y resultado.
2. Adjunta evidencias con metadatos mínimos (tipo, fecha, descripción, hash).
3. Gatekeeper valida y permite cerrar.
4. Actividad pasa a **READY_TO_SYNC**.

### 4) Sincronización
1. Si hay conexión, se sube automáticamente.
2. Si no hay conexión, queda en cola local sin perder información.
3. Worker procesa cola por prioridad + reintentos.
4. Resultado final:
   - **SYNCED** (éxito)
   - **ERROR** (requiere acción)

### 5) Cancelación / incidencias
- Si se abandona wizard antes de guardar: actividad permanece **Revisión pendiente**.
- Si existe bloqueo real de operación: registrar incidencia y cerrar como **CANCELED/BLOQUEADA** con motivo.

---

## Máquina de estados TO-BE

| Estado | Evento | Próximo estado | Persistencia |
|---|---|---|---|
| Pendiente | Iniciar | En curso | startedAt + log CREATED/STARTED |
| En curso | Terminar | Revisión pendiente | finishedAt + log |
| Revisión pendiente | Guardar wizard válido | Ready to sync | Activity + fields + evidences + queue |
| Ready to sync | Sync OK | Synced | serverRevision + log SYNC_OK |
| Ready to sync | Sync fail temporal | Ready to sync | attempts++ + retry |
| Ready to sync | Sync fail permanente | Error | lastError + acción usuario |
| Cualquiera | Incidencia grave | Canceled/Bloqueada | motivo + evidencia opcional |

---

## Reglas funcionales sugeridas TO-BE
- Una sola fuente de verdad para validación (UI y backend alineados).
- Evidencia mínima configurable por tipo de actividad (catálogo).
- Reintentos automáticos con backoff exponencial y tope por política.
- Centro de Sync con acciones: reintentar item, forzar todo, ver errores, limpiar completados.
- Telemetría: tiempos de ciclo (inicio→fin→sync), tasa de error, backlog de cola.

---

## Gap principal AS-IS vs TO-BE
1. Asignación del día: de seed local a agenda real por backend.
2. Sync de actividades: de parcial/manual a worker completo y automático.
3. Estados finales: de “terminada visual” a “terminada + sincronizada verificable”.
4. Incidencias: de retorno simple a Pendiente, a flujo formal cancelado/bloqueado con trazabilidad.
