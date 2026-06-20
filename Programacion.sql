-- =====================================================================
-- PROYECTO FINAL - BASES DE DATOS
-- Escenario B: Sistema de Reservas de Hotel  (UN SOLO HOTEL)
-- Script: 04_programacion.sql
-- Propósito: Funciones, triggers y procedimientos almacenados.
--            Incluye los sugeridos por el enunciado y extras.
-- =====================================================================
SET search_path TO hotel, public;

-- =====================================================================
-- FUNCION 1: fn_habitaciones_disponibles
-- Devuelve las habitaciones libres en un rango de fechas.
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_habitaciones_disponibles (
    p_fecha_inicio DATE,
    p_fecha_fin    DATE
)
RETURNS TABLE (
    id_habitacion INT,
    numero        VARCHAR,
    tipo          VARCHAR,
    precio_noche  NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_fecha_fin <= p_fecha_inicio THEN
        RAISE EXCEPTION 'fecha_fin (%) debe ser posterior a fecha_inicio (%)',
                         p_fecha_fin, p_fecha_inicio;
    END IF;

    RETURN QUERY
    SELECT  h.id_habitacion,
            h.numero,
            th.nombre,
            th.precio
    FROM    habitacion h
    JOIN    tipo_habitacion th ON th.id_tipo = h.id_tipo
    WHERE   NOT EXISTS (
            SELECT 1
            FROM   reservacion r
            WHERE  r.id_habitacion = h.id_habitacion
              AND  r.estado IN ('PENDIENTE','CONFIRMADA','CHECK_IN')
              AND  daterange(r.fecha_inicio, r.fecha_fin, '[)')
                && daterange(p_fecha_inicio, p_fecha_fin, '[)')
          )
    ORDER BY h.piso, h.numero;
END;
$$;
COMMENT ON FUNCTION fn_habitaciones_disponibles(DATE,DATE)
IS 'Lista las habitaciones libres en el rango dado.';


-- =====================================================================
-- FUNCION 2: fn_total_estancia
-- Calcula los importes de una estancia (sin emitir factura):
--   noches, subtotal_habitacion, subtotal_servicios, impuestos, total
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_total_estancia (
    p_id_estancia INT,
    p_iva         NUMERIC DEFAULT 0.21
)
RETURNS TABLE (
    noches              INT,
    subtotal_habitacion NUMERIC,
    subtotal_servicios  NUMERIC,
    impuestos           NUMERIC,
    total               NUMERIC
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_noches   INT;
    v_precio   NUMERIC;
    v_sub_hab  NUMERIC;
    v_sub_serv NUMERIC;
    v_imp      NUMERIC;
BEGIN
    SELECT (r.fecha_fin - r.fecha_inicio), th.precio
      INTO v_noches, v_precio
      FROM check_in_check_out e
      JOIN reservacion r          ON r.id_reserva    = e.id_reserva
      JOIN habitacion h           ON h.id_habitacion = e.id_habitacion
      JOIN tipo_habitacion th     ON th.id_tipo      = h.id_tipo
     WHERE e.id_estancia = p_id_estancia;

    IF v_noches IS NULL THEN
        RAISE EXCEPTION 'No existe la estancia %', p_id_estancia;
    END IF;

    v_sub_hab := v_noches * v_precio;

    SELECT COALESCE(SUM(cs.subtotal), 0)
      INTO v_sub_serv
      FROM consumo_servicio cs
     WHERE cs.id_estancia = p_id_estancia;

    v_imp := ROUND((v_sub_hab + v_sub_serv) * p_iva, 2);

    noches              := v_noches;
    subtotal_habitacion := v_sub_hab;
    subtotal_servicios  := v_sub_serv;
    impuestos           := v_imp;
    total               := v_sub_hab + v_sub_serv + v_imp;
    RETURN NEXT;
END;
$$;
COMMENT ON FUNCTION fn_total_estancia(INT, NUMERIC)
IS 'Calcula importes de la estancia: habitacion + servicios + IVA.';


-- =====================================================================
-- FUNCION 3: fn_tasa_ocupacion
-- Tasa de ocupacion (%) del hotel en un rango dado
-- (sobre todas las habitaciones del establecimiento).
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_tasa_ocupacion (
    p_fecha_inicio DATE,
    p_fecha_fin    DATE
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_dias            INT;
    v_habitaciones    INT;
    v_noches_ocupadas INT;
BEGIN
    v_dias := p_fecha_fin - p_fecha_inicio;
    IF v_dias <= 0 THEN
        RAISE EXCEPTION 'Rango invalido';
    END IF;

    SELECT COUNT(*) INTO v_habitaciones FROM habitacion;

    SELECT COALESCE(SUM(
                LEAST(r.fecha_fin, p_fecha_fin)
                - GREATEST(r.fecha_inicio, p_fecha_inicio)
           ), 0)
      INTO v_noches_ocupadas
      FROM reservacion r
     WHERE r.estado IN ('CONFIRMADA','CHECK_IN','CHECK_OUT')
       AND r.fecha_inicio < p_fecha_fin
       AND r.fecha_fin    > p_fecha_inicio;

    IF v_habitaciones = 0 THEN RETURN 0; END IF;

    RETURN ROUND(100.0 * v_noches_ocupadas / (v_habitaciones * v_dias), 2);
END;
$$;


-- =====================================================================
-- TRIGGER (sugerido por el enunciado)
-- "Al intentar insertar una reservacion, verificar que la habitacion
--  no este ocupada en ese periodo; si hay conflicto, lanzar un error."
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_check_solape_reserva()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_conflicto INT;
BEGIN
    IF NEW.estado NOT IN ('PENDIENTE','CONFIRMADA','CHECK_IN') THEN
        RETURN NEW;
    END IF;

    IF NEW.fecha_fin <= NEW.fecha_inicio THEN
        RAISE EXCEPTION 'fecha_fin (%) debe ser posterior a fecha_inicio (%)',
                         NEW.fecha_fin, NEW.fecha_inicio;
    END IF;

    SELECT r.id_reserva INTO v_conflicto
      FROM reservacion r
     WHERE r.id_habitacion = NEW.id_habitacion
       AND r.estado IN ('PENDIENTE','CONFIRMADA','CHECK_IN')
       AND r.id_reserva <> COALESCE(NEW.id_reserva, -1)
       AND daterange(r.fecha_inicio, r.fecha_fin, '[)')
        && daterange(NEW.fecha_inicio, NEW.fecha_fin, '[)')
     LIMIT 1;

    IF v_conflicto IS NOT NULL THEN
        RAISE EXCEPTION
          'Conflicto: la habitacion % ya tiene la reserva % activa entre % y %.',
          NEW.id_habitacion, v_conflicto, NEW.fecha_inicio, NEW.fecha_fin;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tg_reserva_sin_solape ON reservacion;
CREATE TRIGGER tg_reserva_sin_solape
BEFORE INSERT OR UPDATE OF id_habitacion, fecha_inicio, fecha_fin, estado
ON reservacion
FOR EACH ROW EXECUTE FUNCTION fn_check_solape_reserva();


-- =====================================================================
-- TRIGGER extra: precio congelado en consumo_servicio
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_set_precio_consumo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.precio_unitario IS NULL THEN
        SELECT s.precio INTO NEW.precio_unitario
          FROM servicio s WHERE s.id_servicio = NEW.id_servicio;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tg_precio_consumo ON consumo_servicio;
CREATE TRIGGER tg_precio_consumo
BEFORE INSERT ON consumo_servicio
FOR EACH ROW EXECUTE FUNCTION fn_set_precio_consumo();

-- =====================================================================
-- TRIGGER extra 2: Validar que fecha_salida no sea menor a fecha_entrada
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_trg_validar_fechas_estancia()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.fecha_salida_real IS NOT NULL AND NEW.fecha_salida_real::date < NEW.fecha_entrada_real::date THEN
        RAISE EXCEPTION 'Error: La fecha de salida (%) no puede ser menor a la fecha de entrada (%)', 
		NEW.fecha_salida_real, NEW.fecha_entrada_real;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validar_estancia ON check_in_check_out;
CREATE TRIGGER trg_validar_estancia
BEFORE INSERT OR UPDATE ON check_in_check_out
FOR EACH ROW
EXECUTE FUNCTION fn_trg_validar_fechas_estancia();


-- =====================================================================
-- PROCEDIMIENTO (sugerido por el enunciado)
-- "Realizar el proceso de check-out: calcular el total a cobrar
--  (habitacion + servicios) y generar la factura correspondiente."
-- Nota: el OUT va ANTES del IN con DEFAULT (PostgreSQL error 42P13).
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_realizar_checkout (
    p_id_estancia IN  INT,
    p_id_factura  OUT INT,
    p_iva         IN  NUMERIC DEFAULT 0.21
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado     estado_reservacion;
    v_id_reserva INT;
    v_noches     INT;
    v_sub_hab    NUMERIC;
    v_sub_serv   NUMERIC;
    v_imp        NUMERIC;
    v_total      NUMERIC;
    v_detalle    TEXT;
BEGIN
    SELECT r.id_reserva, r.estado
      INTO v_id_reserva, v_estado
      FROM check_in_check_out e
      JOIN reservacion r ON r.id_reserva = e.id_reserva
     WHERE e.id_estancia = p_id_estancia;

    IF v_id_reserva IS NULL THEN
        RAISE EXCEPTION 'No existe la estancia %', p_id_estancia;
    ELSIF v_estado <> 'CHECK_IN' THEN
        RAISE EXCEPTION 'La reserva % no esta en CHECK_IN (estado actual: %)',
                         v_id_reserva, v_estado;
    END IF;

    IF EXISTS (SELECT 1 FROM factura WHERE id_estancia = p_id_estancia) THEN
        RAISE EXCEPTION 'La estancia % ya tiene factura emitida', p_id_estancia;
    END IF;

    SELECT noches, subtotal_habitacion, subtotal_servicios, impuestos, total
      INTO v_noches, v_sub_hab, v_sub_serv, v_imp, v_total
      FROM fn_total_estancia(p_id_estancia, p_iva);

    v_detalle := format('%s noches, habitacion: $%s, servicios: $%s, IVA: $%s',
                        v_noches, v_sub_hab, v_sub_serv, v_imp);

    INSERT INTO factura (id_estancia, monto_total, impuestos, detalle)
    VALUES (p_id_estancia, v_total, v_imp, v_detalle)
    RETURNING id_factura INTO p_id_factura;

    UPDATE reservacion SET estado = 'CHECK_OUT' WHERE id_reserva = v_id_reserva;

    UPDATE check_in_check_out
       SET fecha_salida_real = CURRENT_TIMESTAMP
     WHERE id_estancia = p_id_estancia AND fecha_salida_real IS NULL;

    RAISE NOTICE 'Check-out OK. Factura % por $ %', p_id_factura, v_total;
END;
$$;
COMMENT ON PROCEDURE sp_realizar_checkout(INT, INT, NUMERIC)
IS 'Cierra la estancia, calcula totales y emite la factura.';


-- =====================================================================
-- PROCEDIMIENTO extra: sp_registrar_reserva (Seguro contra concurrencia)
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_registrar_reserva (
    p_id_huesped    IN  INT,
    p_id_habitacion IN  INT,
    p_fecha_inicio  IN  DATE,
    p_fecha_fin     IN  DATE,
    p_id_reserva    OUT INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_habitacion_libre INT;
BEGIN
    -- Bloquear la fila de la habitacion para evitar overbooking
    SELECT h.id_habitacion INTO v_habitacion_libre
    FROM habitacion h
    WHERE h.id_habitacion = p_id_habitacion
      AND NOT EXISTS (
          SELECT 1 FROM reservacion r
          WHERE r.id_habitacion = h.id_habitacion
          AND r.estado IN ('PENDIENTE', 'CONFIRMADA', 'CHECK_IN')
          AND daterange(r.fecha_inicio, r.fecha_fin, '[)')
              && daterange(p_fecha_inicio, p_fecha_fin, '[)')
      )
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La habitación % ya no está disponible para esas fechas.', p_id_habitacion;
    END IF;

    -- Si pasó la validación y está bloqueada, insertamos seguros
    INSERT INTO reservacion (id_huesped, id_habitacion, fecha_inicio, fecha_fin, estado)
    VALUES (p_id_huesped, p_id_habitacion, p_fecha_inicio, p_fecha_fin, 'CONFIRMADA')
    RETURNING id_reserva INTO p_id_reserva;

    RAISE NOTICE 'Reserva % creada para huesped %', p_id_reserva, p_id_huesped;
END;
$$;


-- =====================================================================
-- DEMOSTRACIONES (descomentar para probar)
-- =====================================================================
-- -- A) Habitaciones libres en julio 2026:
-- SELECT * FROM fn_habitaciones_disponibles('2026-07-01','2026-07-05');

-- -- B) Total estimado de la estancia 9 (en curso):
-- SELECT * FROM fn_total_estancia(9);

-- -- C) Tasa de ocupacion del hotel en mayo 2026:
-- SELECT fn_tasa_ocupacion('2026-05-01', '2026-06-01');

-- -- D) Crear una nueva reserva:
-- DO $$
-- DECLARE v_id INT;
-- BEGIN
--    CALL sp_registrar_reserva(3, 8, '2026-07-10','2026-07-14', v_id);
--    RAISE NOTICE 'Nueva reserva: %', v_id;
-- END $$;

-- -- E) Hacer check-out de la estancia 9 (que esta en CHECK_IN):
-- DO $$
-- DECLARE v_fac INT;
-- BEGIN
--    CALL sp_realizar_checkout(9, v_fac);
--    RAISE NOTICE 'Factura emitida: %', v_fac;
-- END $$;

-- -- F) Probar trigger anti-solape (debe fallar):
-- -- INSERT INTO reservacion (id_huesped, id_habitacion, fecha_inicio, fecha_fin)
-- -- VALUES (4, 27, '2026-05-02','2026-05-04');

-- =====================================================================
-- FIN DEL SCRIPT 04_programacion.sql
-- =====================================================================
