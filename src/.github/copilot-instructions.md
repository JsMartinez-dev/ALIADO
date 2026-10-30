# Instrucciones del repositorio para GitHub Copilot

Este proyecto es un monolito modular que utiliza Clean Architecture.

Antes de realizar cualquier modificación de código:

1. Lee `AGENTS.md` ubicado en la raíz del repositorio. Es la referencia principal para las reglas arquitectónicas, responsabilidades de las capas, dirección de dependencias y convenciones de implementación.

2. Consulta `/docs/plan-general.md` para comprender el contexto global del sistema.

3. Cuando el usuario indique un SPEC, consulta su especificación en `/docs/specs/` y su correspondiente Implementation Plan en `/docs/plans/`.

4. Consulta únicamente los SPEC, planes y documentos adicionales relacionados con las dependencias de la tarea. No es necesario cargar todos los documentos del proyecto en cada solicitud.

5. Utiliza el SPEC como fuente de verdad funcional y el Implementation Plan como guía de ejecución técnica. Ningún plan puede contradecir las reglas arquitectónicas de `AGENTS.md`.

6. Inspecciona el código existente antes de crear o modificar componentes. Evita duplicaciones y cambios fuera del alcance solicitado.

7. Respeta la separación entre `domain`, `application`, `infrastructure` y `presentation`, la inversión de dependencias y los límites de los módulos.

8. Implementa de forma incremental, siguiendo las dependencias y el orden establecido en el Implementation Plan.

9. Ejecuta las pruebas y verificaciones pertinentes. No afirmes haber ejecutado pruebas o completado tareas que no hayas verificado.

10. No modifiques SPEC, Planes de Implementación ni el Plan General sin autorización expresa, excepto cuando actualizar la documentación forme parte de la tarea solicitada.

Ante contradicciones, documentación incompleta o decisiones arquitectónicas ambiguas, informa el problema antes de realizar cambios que puedan afectar el diseño del sistema.