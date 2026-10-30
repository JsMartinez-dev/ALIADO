# Implementar un SPEC mediante su Implementation Plan

Actúa como agente de desarrollo de software del proyecto.

## Objetivo

Implementar progresivamente las funcionalidades de un SPEC, utilizando su Implementation Plan como guía de ejecución y respetando todas las reglas arquitectónicas establecidas en `AGENTS.md`.

## Fase 1. Preparación

1. Lee `AGENTS.md`.
2. Consulta `/docs/plan-general.md`.
3. Localiza el SPEC solicitado en `/docs/specs/`.
4. Localiza su Implementation Plan en `/docs/plans/`.
5. Consulta sus dependencias y documentos relacionados.
6. Inspecciona la estructura actual del módulo y el código existente.

Comprueba que el Implementation Plan esté alineado con Clean Architecture.

Si detectas un conflicto arquitectónico o funcional, informa del problema y no implementes siguiendo una instrucción incompatible.

## Fase 2. Análisis del trabajo pendiente

Identifica:

- Casos de uso del SPEC.
- Fases del Implementation Plan.
- Tareas pendientes.
- Tareas completadas y verificables.
- Dependencias bloqueantes.
- Componentes que ya existen.
- Tareas que pueden ejecutarse en paralelo.

No vuelvas a implementar tareas que ya estén terminadas.

Presenta un resumen del estado actual y el orden recomendado de ejecución.

Si el usuario solamente ha indicado el SPEC, no modifiques el código. Espera a que seleccione una tarea o caso de uso.

## Fase 3. Selección de una tarea

Cuando el usuario seleccione un caso de uso o identificador de tarea:

1. Localiza las tareas correspondientes en el Implementation Plan.
2. Consulta los criterios de aceptación del SPEC.
3. Verifica que se hayan satisfecho las dependencias.
4. Determina los componentes de arquitectura involucrados.
5. Presenta brevemente el alcance que vas a modificar.

No amplíes el alcance sin autorización.

## Fase 4. Implementación

Implementa el trabajo seleccionado respetando:

- Separación de capas.
- Dirección de dependencias.
- Responsabilidades de dominio y aplicación.
- Puertos y adaptadores.
- Límites entre módulos.
- Convenciones del proyecto.
- Pruebas requeridas.

Si el caso de uso necesita varios componentes, implementa el recorrido completo necesario para satisfacerlo.

No crees clases vacías, interfaces redundantes ni funcionalidades especulativas.

## Fase 5. Verificación

Ejecuta las pruebas pertinentes y la compilación correspondiente.

Comprueba los criterios de aceptación del SPEC y las reglas arquitectónicas.

Informa los comandos realmente ejecutados y sus resultados.

No elimines pruebas para solucionar errores de compilación.

## Fase 6. Actualización del Implementation Plan

Después de verificar los resultados:

- Identifica las tareas que pueden marcarse como completadas.
- Mantén las tareas pendientes sin cambios.
- No marques tareas parcialmente implementadas como terminadas.
- No cambies los identificadores originales.
- No modifiques requisitos funcionales.
- No alteres dependencias sin justificación.

Actualiza los checkboxes del plan únicamente cuando el usuario haya autorizado la actualización documental.

## Fase 7. Informe final

Indica:

1. SPEC y caso de uso trabajado.
2. Identificadores de tareas ejecutadas.
3. Archivos creados y modificados.
4. Responsabilidades de los componentes.
5. Decisiones arquitectónicas.
6. Pruebas ejecutadas.
7. Resultados de compilación.
8. Criterios de aceptación verificados.
9. Pendientes y dependencias.

**Regla fundamental:** el Implementation Plan dirige la secuencia del desarrollo, pero el SPEC define el comportamiento esperado y `AGENTS.md` define cómo debe construirse.