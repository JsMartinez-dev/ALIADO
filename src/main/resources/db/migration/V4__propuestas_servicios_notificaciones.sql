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
