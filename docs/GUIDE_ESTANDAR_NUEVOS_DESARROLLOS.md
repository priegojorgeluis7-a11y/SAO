# Guía estándar para iniciar nuevos sistemas

**Fecha:** 2026-04-18  
**Versión:** 2.0  
**Estado:** Vigente  
**Responsable:** Equipo SAO

---

## 1. Propósito del documento
Este documento está diseñado para compartirse de forma independiente con equipos, proveedores o programas que **no tienen acceso al repositorio original**.

Su objetivo es servir como una **base completa para arrancar un nuevo sistema** con:
- diseño consistente
- buenas prácticas técnicas
- estructura mantenible
- criterios mínimos de calidad
- lineamientos claros para construir productos homogéneos

Si un equipo sigue esta guía desde el inicio, podrá crear soluciones más ordenadas, más fáciles de mantener y con una experiencia visual coherente.

---

## 2. Cuándo usar esta guía
Usar este documento cuando se vaya a construir:
- una nueva aplicación web
- una app móvil
- una app de escritorio
- un panel administrativo
- un módulo funcional nuevo
- una herramienta interna o automatización

También puede usarse como documento base para:
- proveedores externos
- nuevos integrantes del equipo
- asistentes de IA o automatizaciones de desarrollo
- equipos que necesiten un estándar común antes de programar

---

## 3. Principios rectores

### 3.1 Consistencia antes que creatividad aislada
La solución debe verse y comportarse como parte de un mismo ecosistema. La prioridad es que el sistema sea claro, uniforme y profesional.

### 3.2 Reutilización antes que duplicación
Antes de crear algo nuevo, revisar si puede resolverse con un patrón, componente o estructura ya definida.

### 3.3 Claridad antes que complejidad
El sistema debe ser fácil de leer, entender, probar y mantener. Evitar arquitecturas innecesariamente complejas.

### 3.4 Datos reales como fuente única de verdad
Los estados de negocio, permisos y validaciones importantes deben originarse en la capa de negocio o backend, no en lógica visual duplicada.

### 3.5 Escalabilidad desde el día uno
Aunque el sistema empiece pequeño, su estructura debe permitir crecimiento sin desorden.

---

## 4. Estructura mínima recomendada para un nuevo sistema
Todo nuevo proyecto debería iniciar con al menos esta organización:

### 4.1 Capas mínimas
1. **Presentación / UI**  
   Pantallas, componentes visuales, formularios, tablas, navegación.

2. **Lógica de negocio**  
   Casos de uso, validaciones funcionales, reglas del sistema.

3. **Acceso a datos**  
   APIs, base de datos, almacenamiento local, servicios externos.

4. **Configuración y entorno**  
   Variables de entorno, parámetros, endpoints, secretos y despliegue.

5. **Calidad y documentación**  
   Pruebas, checklist, definiciones funcionales y decisiones técnicas.

### 4.2 Regla clave
Nunca mezclar toda la lógica en una sola pantalla o archivo.  
Cada capa debe tener una responsabilidad clara.

---

## 5. Estándar visual obligatorio

### 5.1 Colores
Los colores deben manejarse mediante un **sistema de tokens** y no por valores sueltos.

#### Reglas:
- No usar colores hardcodeados dispersos por el sistema.
- No depender de colores directos como rojo, verde o azul sin contexto semántico.
- Nombrar los colores por su función, no por su apariencia.

#### Ejemplos correctos:
- colorPrimario
- colorTextoPrincipal
- colorExito
- colorAdvertencia
- colorError
- colorBorde
- colorFondoTarjeta

#### Ejemplos incorrectos:
- azulBonito
- rojoFuerte
- color1
- usar hex repetidos en varias pantallas

### 5.2 Tipografía
Definir una jerarquía consistente desde el inicio:
- Título principal
- Subtítulo
- Texto de cuerpo
- Etiquetas
- Texto auxiliar
- Texto de error

#### Reglas:
- Usar una escala tipográfica definida.
- Mantener pesos consistentes.
- Evitar tamaños arbitrarios distintos en cada pantalla.

### 5.3 Espaciado
Definir una escala fija de espaciado desde el inicio. Por ejemplo:
- 4
- 8
- 12
- 16
- 24
- 32

#### Reglas:
- No usar márgenes y paddings aleatorios.
- Mantener alineación y respiración visual.
- Usar la misma lógica de separación en todo el sistema.

### 5.4 Bordes, radios y sombras
Definir reglas simples y reutilizables para:
- radio de inputs
- radio de tarjetas
- profundidad de modales
- estados hover o foco

### 5.5 Componentes base obligatorios
Todo sistema debería tener al menos estos componentes reutilizables:
- botón primario
- botón secundario
- input de texto
- selector o dropdown
- tarjeta estándar
- modal de confirmación
- banner de error o advertencia
- indicador de carga
- estado vacío
- badge o chip de estado

---

## 6. Buenas prácticas de experiencia de usuario

### 6.1 Estados obligatorios en cada flujo
Cada pantalla importante debe contemplar:
- carga
- vacío
- éxito
- error
- sin conexión, si aplica
- permiso denegado, si aplica

### 6.2 Formularios
Los formularios deben:
- mostrar etiquetas claras
- indicar campos obligatorios
- validar antes de guardar
- informar errores de forma entendible
- confirmar cuando una acción fue exitosa

### 6.3 Navegación
- La navegación debe ser simple e intuitiva.
- El usuario debe saber siempre dónde está.
- Evitar rutas confusas o flujos que escondan acciones críticas.

### 6.4 Accesibilidad
- Mantener buen contraste.
- No comunicar algo solo por color.
- Usar textos claros y entendibles.
- Asegurar que botones y controles sean fáciles de identificar.

---

## 7. Buenas prácticas técnicas

### 7.1 Separación de responsabilidades
- La UI muestra información.
- La lógica decide reglas.
- Los servicios consultan o guardan datos.
- La configuración define el entorno.

### 7.2 Nombres claros
Todo nombre debe explicar su propósito. Evitar nombres ambiguos como:
- helperFinal
- data2
- pruebaNueva
- moduloBueno

Preferir nombres como:
- usuarioRepository
- validarFormularioRegistro
- actividadService
- estadoSincronizacion

### 7.3 Manejo de errores
Todo error debe tratarse en dos niveles:

#### Para usuario:
- mensaje claro
- acción sugerida si aplica
- no mostrar errores técnicos crudos

#### Para soporte técnico:
- registrar contexto
- guardar detalle útil para diagnóstico
- permitir rastrear el problema

### 7.4 Configuración segura
- No incluir secretos en código fuente.
- Usar variables de entorno.
- Separar configuración por ambiente: desarrollo, pruebas y producción.

### 7.5 Escalabilidad
- Diseñar componentes reutilizables.
- Evitar dependencia fuerte entre módulos.
- Pensar en crecimiento de usuarios, pantallas y datos.

---

## 8. Estándar funcional mínimo para arrancar un nuevo sistema
Antes de iniciar programación, el equipo debe definir como mínimo:

### 8.1 Definición funcional
- objetivo del sistema
- tipo de usuarios
- principales casos de uso
- datos que se van a capturar o consultar
- flujo principal del negocio

### 8.2 Definición visual
- paleta base
- tipografía base
- componentes base
- estilo de formularios
- estilo de tablas, tarjetas y botones

### 8.3 Definición técnica
- stack o lenguaje a usar
- estructura de carpetas
- estrategia de despliegue
- entorno de desarrollo
- método de autenticación si aplica
- forma de persistencia de datos

### 8.4 Definición de calidad
- cómo se validará el sistema
- qué pruebas mínimas existirán
- qué significa “terminado”

---

## 9. Propuesta de stack inicial genérico
Si el equipo aún no ha definido herramientas, esta base puede servir:

### Frontend
- framework moderno de componentes
- sistema de diseño con tokens reutilizables
- manejo de estado centralizado si el proyecto lo requiere

### Backend
- API organizada por módulos
- validación de entradas
- autenticación y autorización claras
- separación entre controladores, servicios y acceso a datos

### Base de datos
- esquema definido desde el inicio
- nombres consistentes
- trazabilidad de auditoría si el negocio lo requiere

### DevOps
- variables de entorno
- ambiente de desarrollo
- ambiente de pruebas
- ambiente de producción
- pipeline mínimo de validación

---

## 10. Plantilla de estructura para cualquier proyecto
El equipo puede tomar esta estructura como punto de partida:

### Carpetas sugeridas
- docs/
- src/ o app/
- components/
- features/ o modules/
- services/
- data/
- config/
- tests/
- scripts/

### Documentos mínimos sugeridos
- visión general del sistema
- alcance funcional
- arquitectura técnica
- guía visual o design system
- checklist de salida
- historial de cambios

---

## 11. Checklist de inicio de proyecto
Antes de comenzar desarrollo, confirmar:

### Negocio
- [ ] El problema está claramente definido
- [ ] Se conocen los usuarios objetivo
- [ ] Hay alcance inicial acordado

### Diseño
- [ ] Existe paleta de color y jerarquía tipográfica
- [ ] Se definieron componentes base
- [ ] Hay reglas de consistencia visual

### Técnica
- [ ] Se definió stack
- [ ] Se definió estructura del proyecto
- [ ] Se definió estrategia de configuración y entornos

### Operación
- [ ] Se definió cómo se desplegará
- [ ] Se definió cómo se monitorearán errores
- [ ] Se definió cómo se harán validaciones

---

## 12. Checklist de calidad antes de entregar

### Diseño
- [ ] El sistema mantiene una línea visual consistente
- [ ] No hay colores, tamaños ni estilos improvisados
- [ ] Los componentes reutilizables son suficientes y claros

### Código
- [ ] El código está organizado por responsabilidades
- [ ] No hay duplicación innecesaria
- [ ] Los nombres son claros y mantenibles
- [ ] La configuración está separada del código

### Funcionalidad
- [ ] El flujo principal funciona de punta a punta
- [ ] Los errores están controlados
- [ ] Los formularios validan correctamente
- [ ] Los permisos y estados están contemplados

### Calidad
- [ ] Existen pruebas o validaciones manuales registradas
- [ ] La documentación mínima está actualizada
- [ ] El sistema puede ser entendido por otro equipo

---

## 13. Prompt base para pedir a otro equipo o a una IA que inicie un sistema

Se puede compartir esta instrucción como texto base:

> Diseñar e implementar un nuevo sistema siguiendo una arquitectura limpia, mantenible y escalable. Usar un diseño visual consistente con componentes reutilizables, tokens semánticos para colores, jerarquía tipográfica definida, espaciado uniforme y estados claros de carga, vacío, éxito y error. Separar presentación, lógica de negocio y acceso a datos. Evitar valores hardcodeados, duplicación y acoplamiento innecesario. Documentar la estructura, validar formularios, manejar errores con claridad y entregar una base lista para crecer.

---

## 14. Recomendaciones finales
- Empezar simple, pero con orden.
- No sacrificar mantenibilidad por velocidad momentánea.
- Definir convenciones antes de producir muchas pantallas.
- Documentar decisiones importantes desde el inicio.
- Si algo se repite dos o tres veces, convertirlo en estándar reutilizable.

---

## 15. Resumen ejecutivo
Si un equipo solo recuerda cinco reglas, deben ser estas:

1. Mantener una sola línea visual.
2. No hardcodear estilos ni lógica crítica.
3. Separar responsabilidades desde el inicio.
4. Diseñar para crecimiento y mantenimiento.
5. Validar y documentar antes de entregar.
