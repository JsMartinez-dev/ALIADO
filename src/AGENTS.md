# Instrucciones para el agente de desarrollo

# 1. Objetivo y contexto obligatorio

Este proyecto es un monolito modular desarrollado con Clean Architecture.

Todas las tareas de desarrollo deben respetar las reglas arquitectónicas definidas en este documento.

## 1.1. Documentación del proyecto

La documentación se encuentra organizada de la siguiente manera:

- `/docs/plan-general.md`: visión global, alcance y organización del sistema.
- `/docs/specs/`: especificaciones funcionales y no funcionales de cada funcionalidad.
- `/docs/plans/`: planes técnicos de implementación asociados a cada SPEC.
- `/docs/architecture/`: documentación arquitectónica complementaria, cuando exista.

## 1.2. Jerarquía y responsabilidad de la documentación

Utiliza cada documento según su responsabilidad:

1. Las instrucciones explícitas más recientes del usuario prevalecen sobre instrucciones anteriores.
2. `AGENTS.md` establece las reglas arquitectónicas y convenciones obligatorias de implementación.
3. Los SPEC son la fuente de verdad para los requisitos funcionales, reglas de negocio y criterios de aceptación.
4. El Plan General establece el contexto global, la organización del sistema y sus dependencias.
5. Los Implementation Plans establecen la secuencia técnica de implementación y las tareas necesarias para completar cada SPEC.

Un Implementation Plan no puede introducir requisitos funcionales que no estén respaldados por los SPEC ni contradecir las reglas arquitectónicas de `AGENTS.md`.

Si un plan contiene una estructura de paquetes, tecnología o decisión técnica incompatible con la arquitectura vigente, identifica el conflicto y propone actualizar el plan antes de implementarlo.

No resuelvas contradicciones importantes silenciosamente.

## 1.3. Documentación que debe consultarse antes de implementar

Cuando el usuario solicite trabajar en un SPEC específico:

1. Lee `AGENTS.md`.
2. Lee el Plan General.
3. Localiza el SPEC correspondiente en `/docs/specs/`.
4. Localiza su Implementation Plan en `/docs/plans/`.
5. Inspecciona los SPEC y planes adicionales que tengan dependencias directas o afecten los módulos involucrados.
6. Consulta la documentación arquitectónica necesaria para la tarea.
7. Inspecciona el código existente antes de proponer modificaciones.

No es obligatorio volver a leer todos los SPEC del proyecto para cada tarea. Consulta los documentos relacionados con el alcance solicitado y amplía la lectura cuando existan dependencias entre funcionalidades, módulos o contratos compartidos.

Si no encuentras el SPEC o su Implementation Plan, indícalo expresamente.

## 1.4. Relación entre los SPEC y los Implementation Plans

Cada Implementation Plan debe corresponder a un único SPEC.

El plan es la guía técnica para desarrollar los casos de uso documentados en su especificación.

Al utilizar un plan:

- Conserva sus identificadores de tareas.
- Respeta el orden de ejecución y sus dependencias.
- Comprueba que las tareas correspondan a requisitos reales.
- Identifica las tareas que ya están implementadas.
- No vuelvas a implementar componentes que ya existen.
- No marques tareas como terminadas sin verificar su cumplimiento.
- Si la arquitectura cambia, identifica las tareas del plan que requieren actualización.
- No elimines tareas o dependencias sin justificar el cambio.

El plan puede incluir tareas técnicas derivadas de un requisito, como crear un adaptador, implementar una migración o desarrollar pruebas. Estas decisiones deben ser coherentes con la arquitectura y no deben alterar el comportamiento funcional especificado.

## 1.5. Contradicciones y documentación desactualizada

Si encuentras diferencias entre documentación y código:

1. Identifica el requisito y los archivos involucrados.
2. Explica la diferencia encontrada.
3. Determina si corresponde actualizar el plan, corregir la implementación o solicitar una decisión funcional.
4. No modifiques documentación ni código fuera del alcance autorizado.

Si `/docs` está incompleto o algún archivo no puede abrirse, informa exactamente qué información no estuvo disponible.

Antes de una tarea grande, presenta un resumen breve de los documentos consultados, las tareas del plan relacionadas y los módulos que podrían modificarse.

No afirmes haber leído documentos que no hayas podido consultar.

## 2. Estructura arquitectónica requerida por módulo

Cada módulo de negocio debe respetar esta estructura base, adaptándola solo cuando una carpeta no sea necesaria para su funcionalidad:

```text
modulo/
├── domain/
│   ├── model/                 # Modelos de dominio y reglas/invariantes del negocio
│   ├── repository/            # Interfaces/puertos de repositorios requeridos por el núcleo
│   └── exception/             # Excepciones propias del dominio, cuando aplique
│
├── application/
│   ├── usecase/               # Contratos explícitos de casos de uso, si aportan claridad
│   ├── dto/                   # Commands, queries y resultados de aplicación; no DTO HTTP
│   └── port/                  # Otros puertos de entrada/salida, especialmente integraciones externas
│
├── infrastructure/
│   ├── persistence/
│   │   ├── entity/            # Entidades de persistencia JPA (@Entity, @Table, etc.)
│   │   ├── mapper/            # Conversión entre dominio y persistencia
│   │   ├── jpa/               # Interfaces que extienden JpaRepository y detalles Spring Data
│   │   └── adapter/           # Implementaciones concretas de los puertos de repositorio
│   ├── adapter/               # Adaptadores para correo, APIs u otros sistemas externos
│   └── config/                # Configuración técnica y composición de dependencias
│
└── presentation/
    ├── controller/            # Controladores HTTP/API REST
    ├── dto/                   # DTO de entrada y salida HTTP (Request/Response)
    ├── mapper/                # Conversión entre DTO HTTP y objetos de aplicación
    └── exception/             # Traducción de errores a respuestas HTTP
```

No crees carpetas, interfaces o clases vacías solo para que el árbol se vea completo. Añade componentes cuando la funcionalidad los necesite. Respeta los nombres y convenciones que ya use el repositorio, excepto cuando se solicite una refactorización explícita.

## 3. Responsabilidades de cada capa

### `domain/`

- Contiene el modelo del negocio, las reglas esenciales, invariantes y excepciones de dominio.
- Las clases del dominio deben ser Java puro y no deben importar Spring, JPA/Hibernate, DTO HTTP, controladores, clientes HTTP ni SDK de proveedores.
- No agregues `@Entity`, `@Table`, `JpaRepository`, `@RestController` ni anotaciones equivalentes a clases del dominio.
- `domain/repository/` contiene contratos/puertos de persistencia necesarios para el núcleo. Estas interfaces no deben extender `JpaRepository` ni exponer `Entity` de persistencia.
- Las interfaces deben declarar operaciones necesarias para el negocio; no añadas métodos especulativos o CRUD genérico sin una necesidad real.
- Coloca excepciones aquí solamente cuando representen una condición o regla del dominio. Los errores de red, configuración o persistencia no son automáticamente errores de dominio.

### `application/`

- Contiene los casos de uso y la orquestación de operaciones del sistema.
- Los servicios de aplicación coordinan el dominio y usan interfaces/puertos; no contienen consultas JPA ni detalles de HTTP.
- `application/dto/` contiene objetos de entrada/salida de los casos de uso, como `RegistrarClienteCommand` o `ClienteResultado`. No reutilices automáticamente DTO de presentación.
- `application/port/` define contratos para dependencias externas que la aplicación necesita, como correo, almacenamiento de archivos, APIs de terceros o publicación de eventos.
- Evita dependencias de framework en el núcleo de la aplicación. No introduzcas imports de Spring en `domain/` y evita introducirlos en `application/`; gestiona el registro de beans/configuración técnica desde infraestructura cuando sea viable y consistente con el proyecto.
- `usecase/`. Si se usan interfaces explícitas de caso de uso, define claramente su función y evita abstracciones redundantes.
- Implementa validaciones de negocio en el dominio o en el caso de uso según corresponda; la validación superficial de formato de una petición puede estar en presentación.

### `infrastructure/`

- Contiene implementaciones tecnológicas concretas y detalles reemplazables.
- `persistence/entity/` contiene modelos de persistencia, por ejemplo `ClienteEntity`, con anotaciones JPA.
- `persistence/jpa/` contiene interfaces Spring Data, por ejemplo `ClienteJpaRepository extends JpaRepository<ClienteEntity, Long>`.
- `persistence/mapper/` convierte explícitamente entre modelos de dominio y entidades de persistencia. No filtren entidades JPA hacia el dominio o hacia los casos de uso.
- `persistence/adapter/` implementa los puertos de repositorio definidos en el núcleo. El adaptador coordina el mapper y el repositorio JPA; no debe apropiarse de las reglas de negocio.
- `infrastructure/adapter/` implementa puertos de integración, por ejemplo un adaptador de correo que implemente una interfaz definida por la aplicación.
- `config/` mantiene configuración técnica y composición de dependencias cuando se necesite.
- Mantén credenciales, secretos y datos sensibles fuera del código fuente. Utiliza la configuración segura ya adoptada por el proyecto.

### `presentation/`

- Los controladores reciben peticiones, invocan casos de uso y devuelven respuestas HTTP.
- `presentation/dto/` contiene contratos de la API como `CrearClienteRequest` y `ClienteResponse`. No los confundas con `Cliente`, `ClienteEntity` ni con los DTO de aplicación.
- `presentation/mapper/` convierte entre DTO HTTP y los objetos de entrada/salida de la aplicación.
- Los controladores no deben acceder directamente a `JpaRepository`, entidades JPA ni la base de datos, ni implementar reglas de negocio complejas.
- `presentation/exception/` o un manejador global traduce errores a códigos y cuerpos HTTP consistentes. No dupliques manejadores si ya existe uno global.
- No expongas directamente entidades JPA ni objetos internos del dominio como contrato público de la API, salvo que una decisión de diseño existente y explícita lo justifique.

## 4. Dirección de dependencias e inversión de dependencias

La regla obligatoria es que las dependencias del código fuente apunten hacia el núcleo:

- `domain` no depende de ninguna otra capa del módulo.
- `application` puede depender de `domain`.
- `presentation` puede depender de `application` y de contratos públicos del núcleo cuando corresponda, pero no de implementaciones de persistencia.
- `infrastructure` implementa contratos definidos hacia el interior y puede depender de `domain`/`application` para cumplirlos.
- El dominio y los casos de uso no deben conocer `ClienteEntity`, `ClienteJpaRepository`, los controladores, ni la implementación concreta de proveedores externos.

Distingue **dirección de dependencias en el código** del **flujo de ejecución**: en tiempo de ejecución una petición puede viajar del controlador al caso de uso y luego al adaptador, pero el caso de uso llama a una abstracción, no a una clase concreta de infraestructura.

Para persistencia, el patrón esperado es:

1. `domain/model/Cliente.java`: modelo de negocio sin dependencia JPA.
2. `domain/repository/ClienteRepository.java`: contrato de persistencia definido hacia el núcleo.
3. `application/service/RegistrarClienteUseCase.java`: orquesta el caso de uso a través de ese contrato.
4. `infrastructure/persistence/entity/ClienteEntity.java`: representación JPA de la tabla.
5. `infrastructure/persistence/mapper/ClientePersistenceMapper.java`: conversión explícita entre `Cliente` y `ClienteEntity`.
6. `infrastructure/persistence/jpa/ClienteJpaRepository.java`: interfaz Spring Data JPA.
7. `infrastructure/persistence/adapter/ClientePersistenceAdapter.java`: implementa `ClienteRepository` usando el mapper y `ClienteJpaRepository`.

El contrato de repositorio puede vivir en `domain/repository/` según la estructura establecida en este proyecto. No crees una segunda interfaz equivalente en `application/port/` por duplicación. Para otras integraciones, usa `application/port/` cuando sea apropiado y consistente con el módulo.

## 5. Reglas para el monolito modular

- Cada módulo debe ser propietario de su lógica de negocio, entidades de persistencia, repositorios concretos, casos de uso y controladores.
- No importes desde un módulo las clases internas de infraestructura de otro módulo. En particular, un módulo no debe depender del `Entity`, `JpaRepository` o adaptador de persistencia de otro.
- La comunicación entre módulos debe realizarse a través de interfaces/fachadas/casos de uso públicos claramente definidos o eventos de dominio/aplicación cuando el diseño lo requiera.
- Evita dependencias circulares entre módulos. Si detectas una, informa del problema y propone una dirección de dependencia adecuada antes de crear más acoplamiento.
- No muevas lógica específica de un módulo a un paquete compartido solo para facilitar imports. Un módulo `shared`/`common` debe contener únicamente conceptos realmente genéricos y estables.
- No conviertas automáticamente el monolito modular en microservicios ni agregues mensajería, complejidad distribuida o nuevas tecnologías sin un requisito documentado.
- Respeta los límites y contratos existentes incluso cuando otra implementación parezca más rápida.

## 6. Reglas de implementación

- Antes de crear una clase, busca si ya existe una clase que cumpla esa responsabilidad.
- Reutiliza las convenciones, versiones, dependencias, estilo de nombres, manejo de errores y formato de respuestas ya presentes en el proyecto.
- Evita refactorizaciones masivas o cambios fuera del alcance solicitado. No reemplaces implementaciones funcionales por una arquitectura nueva completa sin autorización explícita.
- No agregues librerías nuevas si las dependencias existentes resuelven el problema. Si una dependencia nueva es necesaria, explica por qué.
- No añadas métodos, endpoints, roles, permisos, campos, tablas ni reglas que no estén respaldados por los `spec`, el Plan General o la solicitud del usuario.
- Mantén los mappers explícitos y fáciles de probar; no reutilices automáticamente un mapper de HTTP para persistencia ni a la inversa.
- Asegura que el flujo de errores sea coherente y que no se filtren trazas, secretos o información interna en respuestas al usuario.
- Para operaciones de escritura, piensa en transacciones y consistencia. Implementa el límite transaccional siguiendo las convenciones existentes sin introducir dependencias de framework innecesarias en el dominio.
- No marques una tarea como completada si no ejecutaste las verificaciones indicadas o si quedan errores conocidos. Explica qué comandos y pruebas sí se ejecutaron.

## 7. Pruebas y verificación

- Para reglas de negocio, agrega pruebas unitarias del dominio.
- Para casos de uso, prueba el comportamiento usando contratos/mocks o dobles de prueba en vez de depender obligatoriamente de una base de datos real.
- Para adaptadores de persistencia, agrega pruebas de integración cuando sean pertinentes para comprobar el mapeo y las consultas.
- Para controladores, prueba códigos HTTP, validaciones y forma de la respuesta cuando corresponda.
- Usa el sistema de construcción que ya tenga el repositorio (Maven o Gradle); no supongas uno sin inspeccionar los archivos.
- Ejecuta las pruebas pertinentes y, si el tiempo y el entorno lo permiten, la compilación del módulo afectado o del proyecto. Si algún comando falla por problemas preexistentes o por falta de entorno/servicios, informa el error sin ocultarlo.
- No elimines pruebas para hacer que la compilación pase. Corrige la causa cuando esté dentro del alcance solicitado.

# 8. Flujo de trabajo esperado en cada tarea

El desarrollo se realizará de manera incremental, siguiendo los Implementation Plans de `/docs/plans/`.

## 8.1. Al iniciar un SPEC

Cuando el usuario solicite comenzar un SPEC:
1. Lee las instrucciones de `AGENTS.md`.
2. Consulta el Plan General, el SPEC seleccionado y su Implementation Plan.
3. Identifica todos los casos de uso de la especificación.
4. Inspecciona las dependencias con otros SPEC.
5. Comprueba que el Implementation Plan esté alineado con la arquitectura vigente.
6. Inspecciona la implementación existente.
7. Presenta el orden de ejecución, dependencias, fases y tareas pendientes.

Si el plan está desactualizado o contradice la arquitectura, recomienda actualizarlo antes de comenzar la implementación.

No comiences a modificar código cuando el usuario solamente solicite analizar o preparar el desarrollo de un SPEC.

## 8.2. Al seleccionar un caso de uso

Cuando el usuario seleccione un caso de uso:

1. Localiza su identificador en el SPEC.
2. Localiza las tareas correspondientes en el Implementation Plan.
3. Identifica sus dependencias y comprueba que estén satisfechas.
4. Identifica los componentes de Clean Architecture involucrados.
5. Presenta el alcance concreto que se implementará.

No desarrolles tareas dependientes antes de completar sus prerrequisitos, salvo que exista una justificación documentada.

## 8.3. Durante la implementación

- Implementa una funcionalidad completa y verificable a la vez.
- Respeta el orden establecido en el plan.
- Mantén las responsabilidades de cada capa.
- No implementes funcionalidades ajenas al caso de uso seleccionado.
- No dupliques componentes existentes.
- Crea las pruebas necesarias.
- Evita refactorizaciones no relacionadas con la tarea.

## 8.4. Al finalizar una tarea

1. Ejecuta las pruebas correspondientes.
2. Ejecuta la compilación pertinente.
3. Comprueba los criterios de aceptación.
4. Revisa que las dependencias arquitectónicas sean correctas.
5. Identifica las tareas del Implementation Plan que pueden marcarse como completadas.
6. Actualiza los checkboxes del plan únicamente si los resultados verifican su cumplimiento.

No modifiques los requisitos originales del SPEC.

Si el plan necesita ajustes, explica los cambios y solicita autorización antes de modificarlo.

## 8.5. Informe de resultados

Al finalizar, informa:

- SPEC y caso de uso implementados.
- Identificadores de las tareas completadas.
- Archivos creados y modificados.
- Componentes arquitectónicos involucrados.
- Pruebas ejecutadas y resultados.
- Criterios de aceptación verificados.
- Dependencias o tareas pendientes.

No marques una funcionalidad como completada si sus verificaciones no han sido satisfactorias.