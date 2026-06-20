-- =====================================================================
-- PROYECTO FINAL - BASES DE DATOS
-- Escenario B: Sistema de Reservas de Hotel  (UN SOLO HOTEL)
-- Script: 03_consultas.sql
-- Propósito: Las 5 consultas sugeridas por el enunciado + extras.
-- =====================================================================
SET search_path TO hotel, public;

-- =====================================================================
-- CONSULTA 1 (enunciado)
-- Habitaciones disponibles en un rango de fechas dado.
-- Ejemplo: del 2026-06-05 al 2026-06-10.
-- =====================================================================
SELECT  h.id_habitacion,
        h.numero,
        th.nombre        AS tipo,
        th.precio        AS precio_noche
FROM    habitacion h
JOIN    tipo_habitacion th  ON th.id_tipo  = h.id_tipo
WHERE   NOT EXISTS (
          SELECT 1
          FROM   reservacion r
          WHERE  r.id_habitacion = h.id_habitacion
            AND  r.estado IN ('PENDIENTE','CONFIRMADA','CHECK_IN')
            AND  daterange(r.fecha_inicio, r.fecha_fin, '[)')
              && daterange(DATE '2026-06-05', DATE '2026-06-10', '[)')
        )
ORDER BY h.piso, h.numero;


-- =====================================================================
-- CONSULTA 2 (enunciado)
-- Huespedes con MAYOR GASTO HISTORICO (suma de facturas).
-- =====================================================================
SELECT  hu.id_huesped,
        hu.nombre,
        hu.documento_identidad,
        COUNT(f.id_factura)            AS estancias,
        COALESCE(SUM(f.monto_total), 0.00) AS gasto_total
FROM    huesped hu
JOIN    reservacion r          ON r.id_huesped  = hu.id_huesped
JOIN    check_in_check_out e   ON e.id_reserva  = r.id_reserva
JOIN    factura f              ON f.id_estancia = e.id_estancia
GROUP BY hu.id_huesped, hu.nombre, hu.documento_identidad
ORDER BY gasto_total DESC
LIMIT 10;


-- =====================================================================
-- CONSULTA 3 (enunciado)
-- Servicios MAS CONSUMIDOS por TIPO DE HABITACION.
-- =====================================================================
SELECT  th.nombre              AS tipo_habitacion,
        s.nombre               AS servicio,
        SUM(cs.cantidad)       AS unidades_consumidas,
        SUM(cs.subtotal)       AS ingresos_servicio
FROM    consumo_servicio cs
JOIN    servicio s             ON s.id_servicio   = cs.id_servicio
JOIN    check_in_check_out e   ON e.id_estancia   = cs.id_estancia
JOIN    habitacion h           ON h.id_habitacion = e.id_habitacion
JOIN    tipo_habitacion th     ON th.id_tipo      = h.id_tipo
GROUP BY th.nombre, s.nombre
ORDER BY th.nombre, unidades_consumidas DESC;


-- =====================================================================
-- CONSULTA 4 (enunciado)
-- TASA DE OCUPACION MENSUAL por tipo de habitacion (año en curso).
-- ocupacion = noches_reservadas / (cantidad_habitaciones * dias_del_mes)
-- =====================================================================
WITH meses AS (
    SELECT generate_series(
             date_trunc('year', CURRENT_DATE)::date,
             date_trunc('year', CURRENT_DATE)::date + INTERVAL '11 months',
             INTERVAL '1 month'
           )::date AS inicio_mes
),
mes_rango AS (
    SELECT  inicio_mes,
            (inicio_mes + INTERVAL '1 month')::date AS fin_mes,
            EXTRACT(DAY FROM (inicio_mes + INTERVAL '1 month - 1 day'))::int AS dias_mes
    FROM    meses
),
ocupacion AS (
    SELECT  mr.inicio_mes,
            th.id_tipo,
            th.nombre,
            COALESCE(SUM(
                GREATEST(
                  0,
                  LEAST(r.fecha_fin, mr.fin_mes)
                  - GREATEST(r.fecha_inicio, mr.inicio_mes)
                )
            ), 0) AS noches_reservadas
    FROM    mes_rango mr
    CROSS JOIN tipo_habitacion th
    LEFT JOIN habitacion h  ON h.id_tipo       = th.id_tipo
    LEFT JOIN reservacion r ON r.id_habitacion = h.id_habitacion
                           AND r.estado IN ('CONFIRMADA','CHECK_IN','CHECK_OUT')
                           AND r.fecha_inicio < mr.fin_mes
                           AND r.fecha_fin    > mr.inicio_mes
    GROUP BY mr.inicio_mes, th.id_tipo, th.nombre
),
capacidad AS (
    SELECT  th.id_tipo,
            COUNT(h.id_habitacion) AS cant_habitaciones
    FROM    tipo_habitacion th
    LEFT JOIN habitacion h ON h.id_tipo = th.id_tipo
    GROUP BY th.id_tipo
)
SELECT  to_char(o.inicio_mes,'YYYY-MM') AS mes,
        o.nombre                         AS tipo,
        c.cant_habitaciones,
        o.noches_reservadas,
        c.cant_habitaciones * mr.dias_mes AS noches_disponibles,
        ROUND(
            100.0 * o.noches_reservadas
            / NULLIF(c.cant_habitaciones * mr.dias_mes, 0),
        2) AS tasa_ocupacion_pct
FROM    ocupacion o
JOIN    capacidad c   ON c.id_tipo    = o.id_tipo
JOIN    mes_rango mr  ON mr.inicio_mes = o.inicio_mes
ORDER BY mes, tipo;


-- =====================================================================
-- CONSULTA 5 (enunciado)
-- INGRESOS TOTALES por mes (año en curso).
-- =====================================================================
SELECT  to_char(date_trunc('month', f.fecha_emision), 'YYYY-MM') AS mes,
        COUNT(*)                       AS cantidad_facturas,
        SUM(f.monto_total - f.impuestos) AS ingresos_netos,
        SUM(f.impuestos)               AS impuestos_cobrados,
        SUM(f.monto_total)             AS ingresos_totales
FROM    factura f
WHERE   EXTRACT(YEAR FROM f.fecha_emision) = EXTRACT(YEAR FROM CURRENT_DATE)
GROUP BY date_trunc('month', f.fecha_emision)
ORDER BY mes;


-- =====================================================================
-- CONSULTA 6 (extra)
-- Top 5 huespedes recurrentes (cantidad de reservas).
-- =====================================================================
SELECT  hu.nombre,
        COUNT(r.id_reserva)            AS total_reservas,
        MAX(r.fecha_inicio)            AS ultima_visita,
        COALESCE(SUM(f.monto_total),0) AS total_pagado
FROM    huesped hu
JOIN    reservacion r          ON r.id_huesped  = hu.id_huesped
LEFT JOIN check_in_check_out e ON e.id_reserva  = r.id_reserva
LEFT JOIN factura f            ON f.id_estancia = e.id_estancia
GROUP BY hu.id_huesped, hu.nombre
ORDER BY total_reservas DESC, total_pagado DESC
LIMIT 5;


-- =====================================================================
-- CONSULTA 7 (extra)
-- Resumen general: noches promedio, ticket promedio e ingresos totales.
-- =====================================================================
SELECT  COUNT(f.id_factura)                            AS estancias_facturadas,
        ROUND(AVG(r.fecha_fin - r.fecha_inicio), 2)    AS noches_promedio,
        ROUND(AVG(f.monto_total), 2)                   AS ticket_promedio,
        SUM(f.monto_total)                             AS ingresos_totales
FROM    factura f
JOIN    check_in_check_out e   ON e.id_estancia = f.id_estancia
JOIN    reservacion r          ON r.id_reserva  = e.id_reserva;


-- =====================================================================
-- CONSULTA 8 (extra)
-- Detalle completo de una estancia con sus consumos (formato JSON).
-- =====================================================================
WITH consumos AS (
    SELECT cs.id_estancia,
           json_agg(json_build_object(
               'servicio', s.nombre,
               'fecha',    cs.fecha,
               'cantidad', cs.cantidad,
               'precio',   cs.precio_unitario,
               'subtotal', cs.subtotal
           ) ORDER BY cs.fecha) AS lista_consumos,
           SUM(cs.subtotal) AS total_consumos
    FROM   consumo_servicio cs
    JOIN   servicio s ON s.id_servicio = cs.id_servicio
    GROUP BY cs.id_estancia
)
SELECT  e.id_estancia,
        h.numero               AS habitacion,
        hu.nombre              AS huesped,
        r.fecha_inicio,
        r.fecha_fin,
        (r.fecha_fin - r.fecha_inicio) AS noches,
        th.precio              AS precio_noche,
        c.lista_consumos,
        c.total_consumos,
        f.monto_total          AS total_factura
FROM    check_in_check_out e
JOIN    reservacion r          ON r.id_reserva    = e.id_reserva
JOIN    huesped hu             ON hu.id_huesped   = r.id_huesped
JOIN    habitacion h           ON h.id_habitacion = e.id_habitacion
JOIN    tipo_habitacion th     ON th.id_tipo      = h.id_tipo
LEFT JOIN consumos c           ON c.id_estancia   = e.id_estancia
LEFT JOIN factura f            ON f.id_estancia   = e.id_estancia
ORDER BY r.fecha_inicio DESC;


-- =====================================================================
-- CONSULTA 9 (extra)
-- Ranking de empleados por cantidad de check-ins realizados.
-- =====================================================================
SELECT  e.id_empleado,
        e.nombre,
        e.puesto,
        COUNT(est.id_estancia)             AS checkins_realizados,
        COUNT(f.id_factura)                AS facturas_asociadas
FROM    empleado e
LEFT JOIN check_in_check_out est ON est.id_empleado = e.id_empleado
LEFT JOIN factura f             ON f.id_estancia    = est.id_estancia
GROUP BY e.id_empleado, e.nombre, e.puesto
ORDER BY checkins_realizados DESC;


-- =====================================================================
-- CONSULTA 10 (extra)
-- Habitaciones que nunca fueron reservadas (oportunidad comercial).
-- =====================================================================
SELECT  h.numero,
        th.nombre AS tipo,
        h.piso
FROM    habitacion h
JOIN    tipo_habitacion th ON th.id_tipo  = h.id_tipo
LEFT JOIN reservacion r    ON r.id_habitacion = h.id_habitacion
WHERE   r.id_reserva IS NULL
ORDER BY h.piso, h.numero;

-- =====================================================================
-- FIN DEL SCRIPT 03_consultas.sql
-- =====================================================================
