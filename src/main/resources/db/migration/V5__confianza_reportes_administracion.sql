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
