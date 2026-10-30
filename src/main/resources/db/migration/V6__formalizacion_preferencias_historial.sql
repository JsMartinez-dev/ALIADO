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
