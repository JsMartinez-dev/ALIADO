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
