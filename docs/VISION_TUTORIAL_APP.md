# Visión Tutorial SAO

## Propósito
Este modo ayuda a personal nuevo a entender, en menos de 5 minutos, el flujo completo de trabajo en SAO antes de operar en producción.

## Documento relacionado
Para la guia operativa paso a paso, consultar `docs/TUTORIAL_OPERATIVO_SAO.md`.

## ¿Cómo se activa?
1. Usuario llega a login.
2. Activa el switch **Entrar en modo tutorial**.
3. Inicia sesión normalmente.
4. La app redirige a la pantalla de tutorial en lugar de ir directo a Home.

## Qué enseña el tutorial
### Paso 1: Asignaciones
- Qué es una actividad asignada.
- Cómo se interpreta el estado inicial **Pendiente**.

### Paso 2: Inicio de actividad
- Acción: swipe derecho sobre actividad pendiente.
- Resultado: registro de hora de inicio y ubicación.
- Estado resultante: **En curso**.

### Paso 3: Término + captura
- Acción: swipe derecho en actividad en curso.
- Resultado: se marca fin y se abre wizard de captura.
- Wizard: Contexto → Clasificación → Evidencias → Confirmación.

### Paso 4: Guardado y sincronización
- Al guardar: la actividad queda lista para sincronizar.
- Si hay conexión: se envía automáticamente.
- Si no hay conexión: permanece en cola local para reintento.

### Paso 5: Cancelación y reintento
- Si usuario cierra wizard sin guardar: queda en **Revisión pendiente**.
- Puede reabrir y completar después.

## Cierre del tutorial
- Botón: **Comenzar operación real**.
- Acción: desactiva modo tutorial de la sesión y redirige a Inicio.

## Objetivo de adopción
- Reducir errores de captura inicial.
- Homologar proceso operativo entre equipos.
- Acelerar onboarding de nuevos usuarios.
