
-- =====================================================================
-- PROYECTO FINAL - BASES DE DATOS
-- Escenario B: Sistema de Reservas de Hotel  (UN SOLO HOTEL)
-- Script: 01_ddl.sql  (Data Definition Language)
-- Motor : PostgreSQL 17+
-- Base  : Esquema relacional derivado del modelo E-R ProyectoBD_v2
-- Nota  : El enunciado habla de "un hotel". Por eso NO se modela la
--         entidad Hotel: todas las habitaciones, empleados y servicios
--         pertenecen implícitamente al único establecimiento.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Creación de la base (ejecutar conectado a "postgres")
-- ---------------------------------------------------------------------
-- DROP DATABASE IF EXISTS hotel_db;
-- CREATE DATABASE hotel_db
--     WITH ENCODING = 'UTF8'
--          LC_COLLATE = 'es_ES.UTF-8'
--          LC_CTYPE   = 'es_ES.UTF-8'
--          TEMPLATE   = template0;
-- \c hotel_db

-- ---------------------------------------------------------------------
-- Esquema de trabajo
-- ---------------------------------------------------------------------
DROP SCHEMA IF EXISTS hotel CASCADE;
CREATE SCHEMA hotel;
SET search_path TO hotel, public;

-- Extensión necesaria para la restricción EXCLUDE (btree + gist)
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- ---------------------------------------------------------------------
-- Tipos enumerados
-- ---------------------------------------------------------------------
CREATE TYPE estado_reservacion AS ENUM
    ('PENDIENTE','CONFIRMADA','CHECK_IN','CHECK_OUT','CANCELADA','NO_SHOW');

-- =====================================================================
-- TABLA: tipo_habitacion
-- =====================================================================
CREATE TABLE tipo_habitacion (
    id_tipo     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      VARCHAR(60)  NOT NULL UNIQUE,
    descripcion VARCHAR(200),
    precio      NUMERIC(10,2) NOT NULL,
    CONSTRAINT ck_tipo_precio CHECK (precio > 0)
);

-- =====================================================================
-- TABLA: huesped
-- =====================================================================
CREATE TABLE huesped (
    id_huesped          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    documento_identidad VARCHAR(30)  NOT NULL UNIQUE,
    nombre              VARCHAR(120) NOT NULL,
    mail                VARCHAR(120) NOT NULL UNIQUE,
    telefono            VARCHAR(30),
    CONSTRAINT ck_huesped_mail CHECK (mail LIKE '%@%.%')
);

-- =====================================================================
-- TABLA: empleado
-- (sin id_hotel: todos pertenecen al único hotel)
-- =====================================================================
CREATE TABLE empleado (
    id_empleado INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      VARCHAR(120) NOT NULL,
    puesto      VARCHAR(60)  NOT NULL
);

-- =====================================================================
-- TABLA: servicio
-- (sin id_hotel)
-- =====================================================================
CREATE TABLE servicio (
    id_servicio INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      VARCHAR(80)  NOT NULL UNIQUE,
    descripcion VARCHAR(200),
    precio      NUMERIC(10,2) NOT NULL,
    CONSTRAINT ck_serv_precio CHECK (precio >= 0)
);

-- =====================================================================
-- TABLA: habitacion
-- (sin id_hotel; el número de habitación es único en todo el hotel)
-- =====================================================================
CREATE TABLE habitacion (
    id_habitacion INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_tipo       INT NOT NULL,
    numero        VARCHAR(10) NOT NULL UNIQUE,
    piso          SMALLINT    NOT NULL,
    CONSTRAINT fk_hab_tipo FOREIGN KEY (id_tipo) REFERENCES tipo_habitacion(id_tipo)
                           ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_hab_piso CHECK (piso BETWEEN 0 AND 50)
);
CREATE INDEX ix_habitacion_tipo ON habitacion(id_tipo);

-- =====================================================================
-- TABLA: reservacion
-- Apunta a la habitación física. EXCLUDE impide solapamiento.
-- =====================================================================
CREATE TABLE reservacion (
    id_reserva    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_huesped    INT NOT NULL,
    id_habitacion INT NOT NULL,
    fecha_reserva TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_inicio  DATE NOT NULL,
    fecha_fin     DATE NOT NULL,
    estado        estado_reservacion NOT NULL DEFAULT 'CONFIRMADA',
    CONSTRAINT fk_res_huesped    FOREIGN KEY (id_huesped)    REFERENCES huesped(id_huesped),
    CONSTRAINT fk_res_habitacion FOREIGN KEY (id_habitacion) REFERENCES habitacion(id_habitacion),
    CONSTRAINT ck_res_fechas CHECK (fecha_fin > fecha_inicio)
);
CREATE INDEX ix_reserva_huesped    ON reservacion(id_huesped);
CREATE INDEX ix_reserva_habitacion ON reservacion(id_habitacion);
CREATE INDEX ix_reserva_fechas     ON reservacion(fecha_inicio, fecha_fin);

-- Regla del enunciado: una habitación no puede estar reservada
-- dos veces en el mismo período (estados activos).
ALTER TABLE reservacion
    ADD CONSTRAINT ex_reserva_no_solape
    EXCLUDE USING gist (
        id_habitacion WITH =,
        daterange(fecha_inicio, fecha_fin, '[)') WITH &&
    )
    WHERE (estado IN ('PENDIENTE','CONFIRMADA','CHECK_IN'));

-- =====================================================================
-- TABLA: check_in_check_out  (estancia real del huésped)
-- =====================================================================
CREATE TABLE check_in_check_out (
    id_estancia        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_reserva         INT NOT NULL UNIQUE,
    id_empleado        INT NOT NULL,
    id_habitacion      INT NOT NULL,
    fecha_entrada_real TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_salida_real  TIMESTAMP,
    CONSTRAINT fk_est_reserva    FOREIGN KEY (id_reserva)    REFERENCES reservacion(id_reserva),
    CONSTRAINT fk_est_empleado   FOREIGN KEY (id_empleado)   REFERENCES empleado(id_empleado),
    CONSTRAINT fk_est_habitacion FOREIGN KEY (id_habitacion) REFERENCES habitacion(id_habitacion),
    CONSTRAINT ck_est_fechas CHECK (fecha_salida_real IS NULL
                                    OR fecha_salida_real >= fecha_entrada_real)
);
CREATE INDEX ix_est_empleado ON check_in_check_out(id_empleado);

-- =====================================================================
-- TABLA: consumo_servicio  (entidad débil de la estancia)
-- =====================================================================
CREATE TABLE consumo_servicio (
    id_estancia     INT NOT NULL,
    id_consumo      INT NOT NULL,
    id_servicio     INT NOT NULL,
    fecha           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    cantidad        SMALLINT  NOT NULL DEFAULT 1,
    precio_unitario NUMERIC(10,2) NOT NULL,
    subtotal        NUMERIC(12,2)
        GENERATED ALWAYS AS (cantidad * precio_unitario) STORED,
    PRIMARY KEY (id_estancia, id_consumo),
    CONSTRAINT fk_cs_estancia FOREIGN KEY (id_estancia) REFERENCES check_in_check_out(id_estancia)
                              ON DELETE CASCADE,
    CONSTRAINT fk_cs_servicio FOREIGN KEY (id_servicio) REFERENCES servicio(id_servicio),
    CONSTRAINT ck_cs_cantidad CHECK (cantidad > 0),
    CONSTRAINT ck_cs_precio   CHECK (precio_unitario >= 0)
);
CREATE INDEX ix_cs_servicio ON consumo_servicio(id_servicio);

-- =====================================================================
-- TABLA: factura
-- =====================================================================
CREATE TABLE factura (
    id_factura    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_estancia   INT NOT NULL UNIQUE,
    fecha_emision TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    monto_total   NUMERIC(12,2) NOT NULL,
    impuestos     NUMERIC(12,2) NOT NULL,
    detalle       TEXT,
    CONSTRAINT fk_fact_estancia FOREIGN KEY (id_estancia) REFERENCES check_in_check_out(id_estancia),
    CONSTRAINT ck_fact_monto CHECK (monto_total >= 0 AND impuestos >= 0)
);

-- ---------------------------------------------------------------------
-- VISTA de apoyo: ocupación actual por habitación
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_ocupacion_actual AS
SELECT  h.id_habitacion,
        h.numero         AS habitacion,
        th.nombre        AS tipo,
        r.id_reserva,
        hu.nombre        AS huesped,
        r.fecha_inicio,
        r.fecha_fin
FROM   habitacion h
JOIN   tipo_habitacion th  ON th.id_tipo  = h.id_tipo
LEFT JOIN reservacion r    ON r.id_habitacion = h.id_habitacion
                           AND r.estado = 'CHECK_IN'
                           AND CURRENT_DATE BETWEEN r.fecha_inicio AND r.fecha_fin - INTERVAL '1 day'
LEFT JOIN huesped hu       ON hu.id_huesped = r.id_huesped;

-- =====================================================================
-- FIN DEL SCRIPT 01_ddl.sql
-- =====================================================================
