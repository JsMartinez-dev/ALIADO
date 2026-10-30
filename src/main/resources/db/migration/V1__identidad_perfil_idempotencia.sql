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
    password_hash   VARCHAR(255) NOT NULL,                       -- BCrypt, nunca en claro
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
