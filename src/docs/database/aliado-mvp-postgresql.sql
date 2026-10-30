-- ---------- V1__identidad_perfil_idempotencia.sql ----------
-- =============================================================
-- V1: Identidad, perfil y privacidad
-- Specs: SPEC-01 (auth), SPEC-02 (perfil)
-- Transversal: idempotency_keys (plan-spec-01 T009, plan general sección 14)
-- SPEC-03 (descubrimiento) no define tablas.
-- =============================================================

-- SPEC-01 -------------------------------------------------------

CREATE TABLE usuarios (
                          id              UUID PRIMARY KEY,
                          email           VARCHAR(255) NOT NULL,
                          password_hash   VARCHAR(255) NOT NULL,
                          rol             VARCHAR(20)  NOT NULL
                              CHECK (rol IN ('CLIENTE', 'PRESTADOR', 'ADMINISTRADOR')),
                          estado_cuenta   VARCHAR(40)  NOT NULL
                              CHECK (estado_cuenta IN ('ACTIVA', 'BLOQUEADA_PREVENTIVAMENTE')),
                          fecha_creacion  TIMESTAMPTZ  NOT NULL
);

-- FR-003: correo único sin distinguir mayúsculas
CREATE UNIQUE INDEX uq_usuarios_email ON usuarios (LOWER(email));

CREATE TABLE consentimientos (
                                 id                UUID PRIMARY KEY,
                                 usuario_id        UUID        NOT NULL REFERENCES usuarios (id),
                                 version_terminos  VARCHAR(50) NOT NULL,
                                 fecha_aceptacion  TIMESTAMPTZ NOT NULL
);
CREATE INDEX ix_consentimientos_usuario ON consentimientos (usuario_id);

CREATE TABLE sesiones (
                          id                 UUID PRIMARY KEY,
                          usuario_id         UUID         NOT NULL REFERENCES usuarios (id),
                          token_hash         VARCHAR(64)  NOT NULL,                    -- SHA-256 hex del token opaco
                          fecha_inicio       TIMESTAMPTZ  NOT NULL,
                          fecha_expiracion   TIMESTAMPTZ  NOT NULL,
                          fecha_cierre       TIMESTAMPTZ,                              -- NULL mientras no se cierre
    -- Valores propuestos: el plan no enumera el estado de la sesión
                          estado             VARCHAR(20)  NOT NULL
                              CHECK (estado IN ('ACTIVA', 'CERRADA', 'EXPIRADA')),
                          CONSTRAINT uq_sesiones_token_hash UNIQUE (token_hash)
);
CREATE INDEX ix_sesiones_token_estado ON sesiones (token_hash, estado, fecha_expiracion);

CREATE TABLE tokens_recuperacion (
                                     id                UUID PRIMARY KEY,
                                     usuario_id        UUID        NOT NULL REFERENCES usuarios (id),
                                     codigo_hash       VARCHAR(64) NOT NULL,                      -- SHA-256 hex, un solo uso
                                     fecha_creacion    TIMESTAMPTZ NOT NULL,
                                     fecha_expiracion  TIMESTAMPTZ NOT NULL,
                                     usado             BOOLEAN     NOT NULL DEFAULT FALSE
);
CREATE INDEX ix_tokens_recuperacion_codigo ON tokens_recuperacion (codigo_hash);

-- SPEC-02 -------------------------------------------------------

CREATE TABLE perfiles (
                          usuario_id                UUID PRIMARY KEY REFERENCES usuarios (id),   -- relación 1 a 1
                          nombre                    VARCHAR(120),
                          telefono                  VARCHAR(30),
    -- NEEDS CLARIFICATION (SPEC-02): valores permitidos por las reglas de privacidad base.
    -- Sin CHECK hasta definirlos.
                          preferencia_visibilidad   VARCHAR(50) NOT NULL,
                          version                   INTEGER     NOT NULL DEFAULT 0          -- @Version (bloqueo optimista)
);

CREATE TABLE ubicaciones (
                             usuario_id                  UUID PRIMARY KEY REFERENCES usuarios (id),  -- relación 1 a 1
                             zona_aproximada             VARCHAR(100) NOT NULL,       -- dato público por defecto
                             direccion_exacta_cifrada    TEXT,                        -- cifrado a nivel de aplicación (AES); nunca en vistas públicas
                             version                     INTEGER      NOT NULL DEFAULT 0
);

CREATE TABLE solicitudes_eliminacion (
                                         id                  UUID PRIMARY KEY,
                                         usuario_id          UUID        NOT NULL REFERENCES usuarios (id),
                                         fecha_solicitud     TIMESTAMPTZ NOT NULL,
                                         fecha_expiracion    TIMESTAMPTZ NOT NULL,                  -- fecha_solicitud + 24 horas
                                         estado              VARCHAR(20) NOT NULL
                                             CHECK (estado IN ('PENDIENTE', 'CONFIRMADA', 'EXPIRADA', 'RECHAZADA')),
                                         fecha_confirmacion  TIMESTAMPTZ
);
CREATE INDEX ix_solicitudes_eliminacion_usuario_estado ON solicitudes_eliminacion (usuario_id, estado);

-- Una sola solicitud PENDIENTE por usuario (no expresable con UNIQUE normal)
CREATE UNIQUE INDEX uq_solicitud_eliminacion_pendiente
    ON solicitudes_eliminacion (usuario_id)
    WHERE estado = 'PENDIENTE';

-- Transversal ---------------------------------------------------

-- Almacenamiento de respuestas de comandos reintentables (Idempotency-Key)
CREATE TABLE idempotency_keys (
                                  clave              UUID        NOT NULL,
                                  operacion          VARCHAR(100) NOT NULL,                  -- p. ej. 'auth.registro'
                                  usuario_id         UUID        REFERENCES usuarios (id),   -- NULL en operaciones previas a la sesión
                                  status_code        INTEGER     NOT NULL,
                                  respuesta          JSONB       NOT NULL,
                                  fecha_creacion     TIMESTAMPTZ NOT NULL,
                                  fecha_expiracion   TIMESTAMPTZ NOT NULL,
                                  PRIMARY KEY (clave, operacion)
);
CREATE INDEX ix_idempotency_expiracion ON idempotency_keys (fecha_expiracion);

-- ---------- V2__catalogo_solicitudes.sql ----------
-- =============================================================
-- V2: Catálogo compartido y solicitudes
-- Spec: SPEC-04 (solicitudes + catálogo). Catálogo administrado en SPEC-12.
-- =============================================================

CREATE TABLE categorias_servicio (
                                     id      UUID PRIMARY KEY,
                                     nombre  VARCHAR(120) NOT NULL,
                                     estado  VARCHAR(10)  NOT NULL CHECK (estado IN ('ACTIVO', 'INACTIVO')),
                                     CONSTRAINT uq_categorias_nombre UNIQUE (nombre)
);

CREATE TABLE zonas (
                       id                    UUID PRIMARY KEY,
                       nombre                VARCHAR(120) NOT NULL,
                       cobertura_geografica  VARCHAR(255),                       -- SPEC-12 lo menciona; opcional
                       estado                VARCHAR(10)  NOT NULL CHECK (estado IN ('ACTIVO', 'INACTIVO')),
                       CONSTRAINT uq_zonas_nombre UNIQUE (nombre)
);

CREATE TABLE solicitudes (
                             id                    UUID PRIMARY KEY,
                             cliente_id            UUID         NOT NULL REFERENCES usuarios (id),
                             categoria_id          UUID         NOT NULL REFERENCES categorias_servicio (id),
                             zona_id               UUID         NOT NULL REFERENCES zonas (id),
                             descripcion           TEXT         NOT NULL,
    -- NEEDS CLARIFICATION (SPEC-04): valores del enum UrgenciaSolicitud no definidos aún
                             urgencia              VARCHAR(20),
                             estado                VARCHAR(20)  NOT NULL
                                 CHECK (estado IN ('BORRADOR', 'PUBLICADA', 'CANCELADA', 'CONTRATADA')),
                             fecha_creacion        TIMESTAMPTZ  NOT NULL,
                             fecha_actualizacion   TIMESTAMPTZ  NOT NULL,
                             version               INTEGER      NOT NULL DEFAULT 0      -- @Version para transiciones críticas
);
-- Consultas del Cliente y del tablero (plan general sección 21)
CREATE INDEX ix_solicitudes_cliente_estado ON solicitudes (cliente_id, estado);
CREATE INDEX ix_solicitudes_categoria_zona_estado ON solicitudes (categoria_id, zona_id, estado);

CREATE TABLE fotos_solicitud (
                                 id            UUID PRIMARY KEY,
                                 solicitud_id  UUID         NOT NULL REFERENCES solicitudes (id),
                                 archivo_key   VARCHAR(500) NOT NULL,                      -- clave en storage privado; nunca el binario
                                 orden         INTEGER      NOT NULL CHECK (orden >= 1),
                                 CONSTRAINT uq_fotos_solicitud_orden UNIQUE (solicitud_id, orden)
);

CREATE TABLE historial_estado_solicitud (
                                            id               UUID PRIMARY KEY,
                                            solicitud_id     UUID        NOT NULL REFERENCES solicitudes (id),
                                            estado_anterior  VARCHAR(20),                             -- NULL en el primer registro
                                            estado_nuevo     VARCHAR(20) NOT NULL
                                                CHECK (estado_nuevo IN ('BORRADOR', 'PUBLICADA', 'CANCELADA', 'CONTRATADA')),
                                            fecha            TIMESTAMPTZ NOT NULL
);
CREATE INDEX ix_historial_solicitud ON historial_estado_solicitud (solicitud_id, fecha);

-- ---------- V3__perfil_profesional.sql ----------
-- =============================================================
-- V3: Perfil profesional del Prestador
-- Spec: SPEC-05 (perfil profesional, portafolio, disponibilidad, agenda)
-- =============================================================

CREATE TABLE perfiles_profesionales (
                                        id                           UUID PRIMARY KEY,
                                        prestador_id                 UUID        NOT NULL REFERENCES usuarios (id),
    -- NEEDS CLARIFICATION (SPEC-05): campos de datos generales definidos por la UI; se guardan como JSON hasta cerrarlos
                                        datos_generales              JSONB,
    -- NEEDS CLARIFICATION (SPEC-05): valores de exposición pública no definidos aún
                                        estado_exposicion_publica    VARCHAR(20) NOT NULL,
                                        fecha_creacion               TIMESTAMPTZ NOT NULL,
                                        fecha_actualizacion          TIMESTAMPTZ NOT NULL,
                                        CONSTRAINT uq_perfil_profesional_prestador UNIQUE (prestador_id)   -- relación 1 a 1 con Usuario Prestador
);

-- Tablas puente: el perfil se relaciona con el catálogo de SPEC-04, no lo duplica
CREATE TABLE perfil_categoria (
                                  perfil_id     UUID NOT NULL REFERENCES perfiles_profesionales (id),
                                  categoria_id  UUID NOT NULL REFERENCES categorias_servicio (id),
                                  PRIMARY KEY (perfil_id, categoria_id)
);
CREATE INDEX ix_perfil_categoria_categoria ON perfil_categoria (categoria_id, perfil_id);

CREATE TABLE perfil_zona_atencion (
                                      perfil_id  UUID NOT NULL REFERENCES perfiles_profesionales (id),
                                      zona_id    UUID NOT NULL REFERENCES zonas (id),
                                      PRIMARY KEY (perfil_id, zona_id)
);
CREATE INDEX ix_perfil_zona_zona ON perfil_zona_atencion (zona_id, perfil_id);

CREATE TABLE experiencias_profesionales (
                                            id           UUID PRIMARY KEY,
                                            perfil_id    UUID        NOT NULL REFERENCES perfiles_profesionales (id),
                                            descripcion  TEXT        NOT NULL,
    -- El plan indica "fecha o periodo": se modela como periodo; fecha_fin puede ser NULL si es vigente
                                            fecha_inicio DATE        NOT NULL,
                                            fecha_fin    DATE,
                                            CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio)
);

CREATE TABLE servicios_portafolio (
                                      id            UUID PRIMARY KEY,
                                      perfil_id     UUID         NOT NULL REFERENCES perfiles_profesionales (id),
                                      descripcion   TEXT         NOT NULL,
                                      evidencia_key VARCHAR(500),                               -- clave en storage privado (ArchivoStorageService)
                                      fecha_creacion TIMESTAMPTZ NOT NULL
);

CREATE TABLE disponibilidades (
                                  id           UUID PRIMARY KEY,
                                  perfil_id    UUID     NOT NULL REFERENCES perfiles_profesionales (id),
    -- El plan indica "diaSemana o rango": se modela con día y rango horario; día NULL = aplica a todo el rango
                                  dia_semana   SMALLINT CHECK (dia_semana BETWEEN 1 AND 7),
                                  hora_inicio  TIME     NOT NULL,
                                  hora_fin     TIME     NOT NULL,
                                  CHECK (hora_fin > hora_inicio)
);
CREATE INDEX ix_disponibilidades_perfil ON disponibilidades (perfil_id);

CREATE TABLE compromisos_agenda (
                                    id                  UUID PRIMARY KEY,
                                    perfil_id           UUID        NOT NULL REFERENCES perfiles_profesionales (id),
                                    fecha_hora_inicio   TIMESTAMPTZ NOT NULL,
                                    fecha_hora_fin      TIMESTAMPTZ NOT NULL,
                                    origen              VARCHAR(10) NOT NULL CHECK (origen IN ('MANUAL', 'SISTEMA')),
                                    CHECK (fecha_hora_fin > fecha_hora_inicio)
);
CREATE INDEX ix_compromisos_agenda_perfil_fecha ON compromisos_agenda (perfil_id, fecha_hora_inicio);

-- ---------- V4__propuestas_servicios_notificaciones.sql ----------
-- =============================================================
-- V4: Oportunidades (sin tabla propia), propuestas, servicios, mensajes y notificaciones
-- Specs: SPEC-06 (oportunidades: proyección, sin tabla), SPEC-07 (propuestas),
--        SPEC-08 (contratación y ciclo de servicio), SPEC-09 (notificaciones)
-- Decisión del plan general (sección 6.2): las tablas puntuales de notificación
-- de SPEC-06/07/09 se unifican en una sola tabla `notificaciones`.
-- =============================================================

CREATE TABLE propuestas (
                            id                   UUID PRIMARY KEY,
                            solicitud_id         UUID         NOT NULL REFERENCES solicitudes (id),
                            prestador_id         UUID         NOT NULL REFERENCES usuarios (id),
                            disponibilidad       VARCHAR(255) NOT NULL,
                            mensaje              VARCHAR(1000),                                   -- nullable
                            estado               VARCHAR(20)  NOT NULL
                                CHECK (estado IN ('ACTIVA', 'RETIRADA', 'ACEPTADA', 'CERRADA')),
                            fecha_creacion       TIMESTAMPTZ  NOT NULL,
                            fecha_actualizacion  TIMESTAMPTZ  NOT NULL,
                            version              INTEGER      NOT NULL DEFAULT 0                  -- locking en aceptación concurrente
);
CREATE INDEX ix_propuestas_solicitud_estado ON propuestas (solicitud_id, estado);
CREATE INDEX ix_propuestas_prestador_estado ON propuestas (prestador_id, estado);

-- Derivado de plan general (sección 14, idempotencia): un prestador tiene una sola propuesta
-- ACTIVA por solicitud. Verificar contra SPEC-07 antes de cerrar.
CREATE UNIQUE INDEX uq_propuesta_activa_por_prestador
    ON propuestas (solicitud_id, prestador_id)
    WHERE estado = 'ACTIVA';

CREATE TABLE servicios_contratados (
                                       id                       UUID PRIMARY KEY,
                                       solicitud_id             UUID        NOT NULL REFERENCES solicitudes (id),
                                       propuesta_id             UUID        NOT NULL REFERENCES propuestas (id),
                                       cliente_id               UUID        NOT NULL REFERENCES usuarios (id),
                                       prestador_id             UUID        NOT NULL REFERENCES usuarios (id),
    -- P-01 (plan general): transiciones exactas por confirmar
                                       estado                   VARCHAR(20) NOT NULL
                                           CHECK (estado IN ('CONTRATADO', 'EN_EJECUCION', 'TERMINADO', 'FINALIZADO', 'CANCELADO')),
                                       comunicacion_habilitada  BOOLEAN     NOT NULL,
                                       fecha_contratacion       TIMESTAMPTZ NOT NULL,
                                       version                  INTEGER     NOT NULL DEFAULT 0,          -- control de concurrencia optimista
    -- Una solicitud tiene como máximo un servicio contratado; una propuesta, también
                                       CONSTRAINT uq_servicio_por_solicitud UNIQUE (solicitud_id),
                                       CONSTRAINT uq_servicio_por_propuesta UNIQUE (propuesta_id),
                                       CHECK (cliente_id <> prestador_id)
);
CREATE INDEX ix_servicios_cliente_estado ON servicios_contratados (cliente_id, estado);
CREATE INDEX ix_servicios_prestador_estado ON servicios_contratados (prestador_id, estado);

CREATE TABLE historial_estado_servicio (
                                           id               UUID PRIMARY KEY,
                                           servicio_id      UUID        NOT NULL REFERENCES servicios_contratados (id),
                                           estado_anterior  VARCHAR(20),
                                           estado_nuevo     VARCHAR(20) NOT NULL
                                               CHECK (estado_nuevo IN ('CONTRATADO', 'EN_EJECUCION', 'TERMINADO', 'FINALIZADO', 'CANCELADO')),
                                           actor_id         UUID        NOT NULL REFERENCES usuarios (id),   -- quien ejecutó la transición
                                           fecha            TIMESTAMPTZ NOT NULL
);
CREATE INDEX ix_historial_servicio ON historial_estado_servicio (servicio_id, fecha);

-- Canal autorizado entre las partes del servicio (SPEC-08). Es la persistencia del chat de SPEC-15.
CREATE TABLE mensajes_servicio (
                                   id           UUID PRIMARY KEY,
                                   servicio_id  UUID        NOT NULL REFERENCES servicios_contratados (id),
                                   remitente_id UUID        NOT NULL REFERENCES usuarios (id),
                                   contenido    TEXT        NOT NULL,
                                   fecha_envio  TIMESTAMPTZ NOT NULL
);
CREATE INDEX ix_mensajes_servicio ON mensajes_servicio (servicio_id, fecha_envio);

-- Notificaciones unificadas (plan general, secciones 6.2 y 19)
CREATE TABLE notificaciones (
                                id                 UUID PRIMARY KEY,
                                destinatario_id    UUID         NOT NULL REFERENCES usuarios (id),
                                tipo               VARCHAR(40)  NOT NULL
                                    CHECK (tipo IN ('NUEVA_OPORTUNIDAD', 'PROPUESTA_RECIBIDA',
                                                    'ACEPTACION_PROPUESTA', 'CAMBIO_ESTADO_SERVICIO',
                                                    'AVISO_SEGURIDAD_CUENTA')),
                                aggregate_id       UUID         NOT NULL,                    -- id de la solicitud, propuesta o servicio de origen
                                event_version      INTEGER      NOT NULL DEFAULT 1,          -- versión del evento de origen
                                detalle            VARCHAR(500),                             -- p. ej. nuevo estado del servicio
                                canal              VARCHAR(20)  NOT NULL CHECK (canal IN ('PUSH', 'EMAIL')),
                                estado_entrega     VARCHAR(20)  NOT NULL
                                    CHECK (estado_entrega IN ('PENDIENTE', 'ENTREGADA', 'FALLIDA')),
                                intentos           INTEGER      NOT NULL DEFAULT 0,
                                fecha_generacion   TIMESTAMPTZ  NOT NULL,
                                fecha_entrega      TIMESTAMPTZ,
    -- Idempotencia (plan general, sección 19.3): tipo + aggregateId + destinatario + eventVersion
                                CONSTRAINT uq_notificacion_evento UNIQUE (tipo, aggregate_id, destinatario_id, event_version)
);
CREATE INDEX ix_notificaciones_destinatario_entrega ON notificaciones (destinatario_id, estado_entrega);
-- Worker: notificaciones pendientes o fallidas para reintentar
CREATE INDEX ix_notificaciones_pendientes ON notificaciones (estado_entrega, fecha_generacion)
    WHERE estado_entrega IN ('PENDIENTE', 'FALLIDA');

-- ---------- V5__confianza_reportes_administracion.sql ----------
-- =============================================================
-- V5: Confianza, reportes y administración
-- Specs: SPEC-10 (calificaciones, reseñas, reputación, verificación),
--        SPEC-11 (reportes y evidencias), SPEC-12 (administración y moderación)
-- Decisión del plan general: `reportes` es un único núcleo para reseña, usuario y servicio.
-- =============================================================

-- SPEC-10 -------------------------------------------------------

CREATE TABLE calificaciones (
                                id           UUID PRIMARY KEY,
                                servicio_id  UUID     NOT NULL REFERENCES servicios_contratados (id),
                                cliente_id   UUID     NOT NULL REFERENCES usuarios (id),
                                prestador_id UUID     NOT NULL REFERENCES usuarios (id),
                                valor        SMALLINT NOT NULL CHECK (valor BETWEEN 1 AND 5),
                                fecha        TIMESTAMPTZ NOT NULL,
    -- Máximo una calificación por servicio (SPEC-10, FR-059)
                                CONSTRAINT uq_calificacion_servicio UNIQUE (servicio_id),
                                CHECK (cliente_id <> prestador_id)
);
CREATE INDEX ix_calificaciones_prestador ON calificaciones (prestador_id);

CREATE TABLE resenas (
                         id                  UUID PRIMARY KEY,
                         calificacion_id     UUID         NOT NULL REFERENCES calificaciones (id),
                         texto               TEXT         NOT NULL,
                         fecha_creacion      TIMESTAMPTZ  NOT NULL,
    -- NEEDS CLARIFICATION (SPEC-10): valores de visibilidad de la reseña no definidos
                         estado_visibilidad  VARCHAR(20)  NOT NULL,
    -- Una reseña por calificación (SPEC-10, FR-060)
                         CONSTRAINT uq_resena_calificacion UNIQUE (calificacion_id)
);

-- Materialización derivada: reconstruible desde calificaciones (SPEC-10)
CREATE TABLE reputaciones_prestador (
                                        prestador_id             UUID PRIMARY KEY REFERENCES usuarios (id),
                                        valor_agregado           NUMERIC(3, 2) NOT NULL CHECK (valor_agregado BETWEEN 0 AND 5),
                                        cantidad_calificaciones  INTEGER       NOT NULL CHECK (cantidad_calificaciones >= 0),
                                        fecha_calculo            TIMESTAMPTZ   NOT NULL
);

CREATE TABLE solicitudes_verificacion (
                                          id              UUID PRIMARY KEY,
                                          prestador_id    UUID        NOT NULL REFERENCES usuarios (id),
                                          estado          VARCHAR(10) NOT NULL CHECK (estado IN ('PENDIENTE', 'APROBADA', 'RECHAZADA')),
                                          fecha_solicitud TIMESTAMPTZ NOT NULL,
                                          fecha_revision  TIMESTAMPTZ,
                                          CHECK (estado = 'PENDIENTE' OR fecha_revision IS NOT NULL)
);
-- Máximo una verificación PENDIENTE por Prestador (plan general, sección 11)
CREATE UNIQUE INDEX uq_verificacion_pendiente_por_prestador
    ON solicitudes_verificacion (prestador_id)
    WHERE estado = 'PENDIENTE';
-- El nivel de verificación se deriva de solicitudes APROBADAS; no se almacena aquí
-- (NEEDS CLARIFICATION: confirmar si el nivel necesita columna propia)

CREATE TABLE documentos_verificacion (
                                         id                          UUID PRIMARY KEY,
                                         solicitud_verificacion_id   UUID         NOT NULL REFERENCES solicitudes_verificacion (id),
                                         archivo_key                 VARCHAR(500) NOT NULL,       -- storage privado; nunca público
                                         fecha_carga                 TIMESTAMPTZ  NOT NULL
);

-- SPEC-11 + SPEC-12 (núcleo de reportes) -------------------------

CREATE TABLE reportes (
                          id                       UUID PRIMARY KEY,
                          tipo                     VARCHAR(10) NOT NULL CHECK (tipo IN ('RESENA', 'USUARIO', 'SERVICIO')),
                          reportante_id            UUID        NOT NULL REFERENCES usuarios (id),
    -- Un único objetivo, según el tipo (plan general, sección 11): exactamente una de las tres columnas
                          resena_id                UUID        REFERENCES resenas (id),
                          usuario_objetivo_id      UUID        REFERENCES usuarios (id),
                          servicio_id              UUID        REFERENCES servicios_contratados (id),
                          motivo                   VARCHAR(500) NOT NULL,
                          estado                   VARCHAR(12)  NOT NULL
                              CHECK (estado IN ('PENDIENTE', 'EN_REVISION', 'RESUELTO', 'DESCARTADO')),
                          detalle_revisado_en      TIMESTAMPTZ,                   -- SPEC-12: requiere revisión de detalle previa
                          justificacion_resolucion VARCHAR(1000),
                          revisado_por             UUID        REFERENCES usuarios (id),
                          fecha_creacion           TIMESTAMPTZ NOT NULL,
                          fecha_resolucion         TIMESTAMPTZ,
                          version                  INTEGER     NOT NULL DEFAULT 0,  -- @Version para resolución concurrente

                          CONSTRAINT ck_reporte_un_objetivo CHECK (
                              (tipo = 'RESENA'   AND resena_id IS NOT NULL AND usuario_objetivo_id IS NULL AND servicio_id IS NULL) OR
                              (tipo = 'USUARIO'  AND usuario_objetivo_id IS NOT NULL AND resena_id IS NULL AND servicio_id IS NULL) OR
                              (tipo = 'SERVICIO' AND servicio_id IS NOT NULL AND resena_id IS NULL AND usuario_objetivo_id IS NULL)
                              ),
    -- Resolver exige revisión de detalle previa y justificación (SPEC-12, SC-002)
                          CONSTRAINT ck_reporte_resolucion CHECK (
                              estado NOT IN ('RESUELTO', 'DESCARTADO')
                                  OR (detalle_revisado_en IS NOT NULL AND justificacion_resolucion IS NOT NULL
                                  AND revisado_por IS NOT NULL AND fecha_resolucion IS NOT NULL)
                              )
);

-- Objetivo normalizado para la regla de consolidación (columna generada, solo lectura)
ALTER TABLE reportes ADD COLUMN objetivo_ref UUID
    GENERATED ALWAYS AS (COALESCE(resena_id, usuario_objetivo_id, servicio_id)) STORED;

-- SPEC-11: mismo reportante + mismo objetivo + mismo motivo + abierto = se consolida
CREATE UNIQUE INDEX uq_reporte_abierto_consolidado
    ON reportes (reportante_id, tipo, objetivo_ref, motivo)
    WHERE estado IN ('PENDIENTE', 'EN_REVISION');

-- Cola de moderación (SPEC-12, UC070)
CREATE INDEX ix_reportes_cola ON reportes (estado, fecha_creacion)
    WHERE estado IN ('PENDIENTE', 'EN_REVISION');

CREATE TABLE evidencias_reporte (
                                    id            UUID PRIMARY KEY,
                                    reporte_id    UUID         NOT NULL REFERENCES reportes (id),   -- nunca huérfana
                                    archivo_key   VARCHAR(500) NOT NULL,                             -- storage privado
                                    tipo_contenido VARCHAR(100) NOT NULL,                            -- MIME validado
                                    fecha_carga   TIMESTAMPTZ  NOT NULL
);
CREATE INDEX ix_evidencias_reporte ON evidencias_reporte (reporte_id);

-- SPEC-12 -------------------------------------------------------

CREATE TABLE bloqueos_preventivos (
                                      id                UUID PRIMARY KEY,
                                      usuario_id        UUID        NOT NULL REFERENCES usuarios (id),
                                      administrador_id  UUID        NOT NULL REFERENCES usuarios (id),
                                      motivo            VARCHAR(1000) NOT NULL,
                                      fecha_inicio      TIMESTAMPTZ NOT NULL,
                                      fecha_fin         TIMESTAMPTZ,                              -- NEEDS CLARIFICATION (SPEC-12): duración del bloqueo
                                      activo            BOOLEAN     NOT NULL,
                                      CHECK (fecha_fin IS NULL OR fecha_fin > fecha_inicio)
);
-- Un solo bloqueo activo por usuario
CREATE UNIQUE INDEX uq_bloqueo_activo_por_usuario
    ON bloqueos_preventivos (usuario_id)
    WHERE activo = TRUE;

CREATE TABLE acciones_moderacion (
                                     id                UUID PRIMARY KEY,
                                     administrador_id  UUID          NOT NULL REFERENCES usuarios (id),
                                     tipo              VARCHAR(50)   NOT NULL,      -- p. ej. OCULTAR_CONTENIDO, SOLICITAR_CORRECCION
                                     objetivo_tipo     VARCHAR(30)   NOT NULL,      -- PERFIL, RESENA, SERVICIO, USUARIO
                                     objetivo_id       UUID          NOT NULL,
                                     motivo            VARCHAR(1000) NOT NULL,
                                     fecha             TIMESTAMPTZ   NOT NULL
);
CREATE INDEX ix_acciones_moderacion_objetivo ON acciones_moderacion (objetivo_tipo, objetivo_id);

CREATE TABLE marcas_alto_riesgo (
                                    id                UUID PRIMARY KEY,
                                    servicio_id       UUID          NOT NULL REFERENCES servicios_contratados (id),
                                    criterio          VARCHAR(200)  NOT NULL,      -- NEEDS CLARIFICATION (SPEC-12): criterios definidos por producto
                                    administrador_id  UUID          NOT NULL REFERENCES usuarios (id),
                                    fecha             TIMESTAMPTZ   NOT NULL,
                                    activa            BOOLEAN       NOT NULL
);
CREATE UNIQUE INDEX uq_marca_alto_riesgo_activa
    ON marcas_alto_riesgo (servicio_id)
    WHERE activa = TRUE;

-- RNF-005: registro de auditoría append-only (plan general, sección 23)
CREATE TABLE auditoria_administrativa (
                                          id                UUID PRIMARY KEY,
                                          administrador_id  UUID          NOT NULL REFERENCES usuarios (id),
                                          accion            VARCHAR(100)  NOT NULL,      -- p. ej. ACCOUNT_BLOCKED, REPORT_RESOLVED
                                          objetivo_tipo     VARCHAR(30)   NOT NULL,
                                          objetivo_id       UUID          NOT NULL,
                                          detalle           VARCHAR(1000),               -- sanitizado, sin datos personales
                                          fecha             TIMESTAMPTZ   NOT NULL,
                                          trace_id          VARCHAR(64)   NOT NULL
);
CREATE INDEX ix_auditoria_objetivo ON auditoria_administrativa (objetivo_tipo, objetivo_id, fecha);

-- Impide UPDATE y DELETE sobre la auditoría
CREATE OR REPLACE FUNCTION auditoria_inmutable() RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'auditoria_administrativa es append-only';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auditoria_no_update
    BEFORE UPDATE OR DELETE ON auditoria_administrativa
    FOR EACH ROW EXECUTE FUNCTION auditoria_inmutable();

-- ---------- V6__formalizacion_preferencias_historial.sql ----------
-- =============================================================
-- V6: Formalización orientativa, preferencias e historial
-- Specs: SPEC-13 (ruta de formalización), SPEC-14 (preferencias, historial, indicadores)
-- Historial, indicadores y actividad reciente son proyecciones: no tienen tabla
-- (plan general, sección 7.8 y 10.7).
-- =============================================================

-- SPEC-13 -------------------------------------------------------

CREATE TABLE rutas_formalizacion (
                                     id           UUID PRIMARY KEY,
                                     nombre       VARCHAR(200) NOT NULL,
                                     descripcion  TEXT,
                                     activa       BOOLEAN      NOT NULL
);

CREATE TABLE pasos_formalizacion (
                                     id           UUID PRIMARY KEY,
                                     ruta_id      UUID         NOT NULL REFERENCES rutas_formalizacion (id),
                                     titulo       VARCHAR(200) NOT NULL,
                                     descripcion  TEXT,
                                     orden        INTEGER      NOT NULL CHECK (orden >= 1),
                                     CONSTRAINT uq_paso_orden_ruta UNIQUE (ruta_id, orden)
);

CREATE TABLE enlaces_institucionales (
                                         id       UUID PRIMARY KEY,
                                         paso_id  UUID         NOT NULL REFERENCES pasos_formalizacion (id),
                                         nombre   VARCHAR(200) NOT NULL,
                                         url      VARCHAR(500) NOT NULL,
    -- Un enlace caído se marca NO_DISPONIBLE sin convertirse en contenido verificado (SPEC-13)
                                         estado   VARCHAR(15)  NOT NULL CHECK (estado IN ('DISPONIBLE', 'NO_DISPONIBLE'))
);

-- NEEDS CLARIFICATION (SPEC-13, SPEC-18): el origen del progreso no está definido en ningún caso de uso.
-- La tabla existe para no bloquear el modelo; su llenado depende de resolver ese vacío.
CREATE TABLE progreso_formalizacion (
                                        id                   UUID PRIMARY KEY,
                                        prestador_id         UUID        NOT NULL REFERENCES usuarios (id),
                                        ruta_id              UUID        NOT NULL REFERENCES rutas_formalizacion (id),
                                        valor_orientativo    SMALLINT    NOT NULL CHECK (valor_orientativo BETWEEN 0 AND 100),
                                        fecha_actualizacion  TIMESTAMPTZ NOT NULL,
                                        CONSTRAINT uq_progreso_prestador_ruta UNIQUE (prestador_id, ruta_id)
);

-- SPEC-14 -------------------------------------------------------

-- Preferencias de aviso por tipo y canal (plan general, sección 19.2)
CREATE TABLE preferencias_notificacion (
                                           usuario_id    UUID        NOT NULL REFERENCES usuarios (id),
                                           tipo_aviso    VARCHAR(40) NOT NULL
                                               CHECK (tipo_aviso IN ('NUEVA_OPORTUNIDAD', 'PROPUESTA_RECIBIDA',
                                                                     'ACEPTACION_PROPUESTA', 'CAMBIO_ESTADO_SERVICIO',
                                                                     'AVISO_SEGURIDAD_CUENTA')),
                                           canal         VARCHAR(20) NOT NULL CHECK (canal IN ('PUSH', 'EMAIL')),
                                           habilitada    BOOLEAN     NOT NULL,
                                           configurable  BOOLEAN     NOT NULL,
                                           PRIMARY KEY (usuario_id, tipo_aviso, canal),
    -- Un aviso obligatorio (configurable = FALSE) no puede estar deshabilitado (SPEC-14, FR-081)
                                           CHECK (configurable OR habilitada)
);

-- Solicitud y resultado de descarga de historial (SPEC-14, UC083)
CREATE TABLE descargas_historial (
                                     id                 UUID PRIMARY KEY,
                                     usuario_id         UUID         NOT NULL REFERENCES usuarios (id),
                                     fecha_generacion   TIMESTAMPTZ  NOT NULL,
                                     archivo_key        VARCHAR(500),                              -- storage privado; NULL mientras se genera
                                     estado             VARCHAR(15)  CHECK (estado IN ('GENERANDO', 'LISTA', 'FALLIDA'))
);
CREATE INDEX ix_descargas_usuario ON descargas_historial (usuario_id, fecha_generacion);