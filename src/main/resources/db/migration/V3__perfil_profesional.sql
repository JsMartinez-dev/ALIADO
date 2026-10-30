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
