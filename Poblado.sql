-- =====================================================================
-- PROYECTO FINAL - BASES DE DATOS
-- Escenario B: Sistema de Reservas de Hotel  (UN SOLO HOTEL)
-- Script: 02_dml.sql  (Data Manipulation Language)
-- Propósito: Carga inicial de datos representativos.
-- Pre-requisito: haber ejecutado 01_ddl.sql
-- =====================================================================
SET search_path TO hotel, public;

BEGIN;

-- ---------------------------------------------------------------------
-- TIPO_HABITACION
-- ---------------------------------------------------------------------
INSERT INTO tipo_habitacion (nombre, descripcion, precio) VALUES
 ('Simple',         'Habitacion individual con cama de una plaza',         18000.00),  -- 1
 ('Doble Estandar', 'Habitacion doble con dos camas o una matrimonial',    28000.00),  -- 2
 ('Doble Superior', 'Habitacion doble con vista y amenities mejorados',    35000.00),  -- 3
 ('Triple',         'Habitacion para tres personas',                       42000.00),  -- 4
 ('Suite Junior',   'Suite con living separado',                           65000.00),  -- 5
 ('Suite Premium',  'Suite premium con jacuzzi',                           95000.00);  -- 6

-- ---------------------------------------------------------------------
-- HUESPED
-- ---------------------------------------------------------------------
INSERT INTO huesped (documento_identidad, nombre, mail, telefono) VALUES
 ('30123456', 'Juan Perez',       'jperez@mail.com',     '+54 11 41112222'),  -- 1
 ('28765432', 'Maria Garcia',     'mgarcia@mail.com',    '+54 11 41112223'),  -- 2
 ('35987654', 'Carlos Lopez',     'clopez@mail.com',     '+54 11 41112224'),  -- 3
 ('AB123456', 'Ana Silva',        'asilva@mail.com',     '+55 11 99988877'),  -- 4
 ('40234567', 'Lucia Fernandez',  'lfernandez@mail.com', '+54 11 41112226'),  -- 5
 ('CD789012', 'Roberto Martinez', 'rmartinez@mail.com',  '+34 91 5550000'),   -- 6
 ('32456789', 'Sofia Rodriguez',  'srodriguez@mail.com', '+54 11 41112228'),  -- 7
 ('CL987654', 'Diego Morales',    'dmorales@mail.com',   '+56 9 88776655'),   -- 8
 ('38123459', 'Valentina Gonzalez','vgonzalez@mail.com', '+54 11 41112230'),  -- 9
 ('29654321', 'Martin Torres',    'mtorres@mail.com',    '+54 11 41112231');  -- 10

-- ---------------------------------------------------------------------
-- EMPLEADO  (todos del único hotel)
-- ---------------------------------------------------------------------
INSERT INTO empleado (nombre, puesto) VALUES
 ('Laura Ruiz',      'Recepcionista'),  -- 1
 ('Pedro Sanchez',   'Conserje'),       -- 2
 ('Monica Vega',     'Gerente'),        -- 3
 ('Esteban Nunez',   'Recepcionista'),  -- 4
 ('Patricia Romero', 'Supervisor'),     -- 5
 ('Andres Castro',   'Recepcionista'),  -- 6
 ('Gabriela Mendez', 'Conserje');       -- 7

-- ---------------------------------------------------------------------
-- SERVICIO  (catálogo único, sin duplicados por hotel)
-- ---------------------------------------------------------------------
INSERT INTO servicio (nombre, descripcion, precio) VALUES
 ('Desayuno buffet',       'Desayuno buffet completo',                4500.00),  -- 1
 ('Cena gourmet',          'Cena tres pasos en restaurante',         12000.00),  -- 2
 ('Lavado de ropa',        'Servicio de lavanderia por kilo',         3000.00),  -- 3
 ('Masaje relax 60',       'Masaje descontracturante 60 min',        15000.00),  -- 4
 ('Tragos premium',        'Consumo en bar del hotel',                6500.00),  -- 5
 ('Estacionamiento',       'Cochera cubierta por dia',                3500.00),  -- 6
 ('Spa - circuito',        'Acceso al circuito hidrotermal',          9000.00),  -- 7
 ('Masaje deportivo',      'Masaje deportivo de 60 min',             16500.00),  -- 8
 ('Room service',          'Pedido a la habitacion',                  5500.00),  -- 9
 ('Consumo minibar',       'Consumo del minibar de la habitacion',    2500.00);  -- 10

-- ---------------------------------------------------------------------
-- HABITACION  (30 habitaciones del único hotel, numeradas por piso)
-- ---------------------------------------------------------------------
INSERT INTO habitacion (id_tipo, numero, piso) VALUES
 -- Piso 1 (ids 1-5)
 (1,'101',1), (2,'102',1), (2,'103',1), (3,'104',1), (1,'105',1),
 -- Piso 2 (ids 6-10)
 (2,'201',2), (5,'202',2), (3,'203',2), (6,'204',2), (1,'205',2),
 -- Piso 3 (ids 11-15)
 (2,'301',3), (3,'302',3), (3,'303',3), (4,'304',3), (5,'305',3),
 -- Piso 4 (ids 16-20)
 (5,'401',4), (6,'402',4), (6,'403',4), (1,'404',4), (2,'405',4),
 -- Piso 5 (ids 21-25)
 (1,'501',5), (1,'502',5), (2,'503',5), (2,'504',5), (3,'505',5),
 -- Piso 6 (ids 26-30)
 (4,'601',6), (5,'602',6), (6,'603',6), (2,'604',6), (3,'605',6);

-- ---------------------------------------------------------------------
-- RESERVACION
-- Estados: CHECK_OUT (terminadas), CHECK_IN (en curso),
-- CONFIRMADA (futuras) y CANCELADA.
-- ---------------------------------------------------------------------
INSERT INTO reservacion (id_huesped, id_habitacion, fecha_inicio, fecha_fin, estado) VALUES
 ( 1,  2, '2026-01-10', '2026-01-15', 'CHECK_OUT'),   -- 1  Doble Estandar
 ( 2,  4, '2026-02-05', '2026-02-08', 'CHECK_OUT'),   -- 2  Doble Superior
 ( 3,  7, '2026-02-20', '2026-02-25', 'CHECK_OUT'),   -- 3  Suite Junior
 ( 4, 11, '2026-03-01', '2026-03-04', 'CHECK_OUT'),   -- 4  Doble Estandar
 ( 5, 15, '2026-03-15', '2026-03-20', 'CHECK_OUT'),   -- 5  Suite Junior
 ( 6, 17, '2026-04-02', '2026-04-09', 'CHECK_OUT'),   -- 6  Suite Premium
 ( 7, 23, '2026-04-10', '2026-04-13', 'CHECK_OUT'),   -- 7  Doble Estandar
 ( 8, 26, '2026-04-15', '2026-04-18', 'CHECK_OUT'),   -- 8  Triple
 ( 9, 27, '2026-05-01', '2026-05-05', 'CHECK_IN'),    -- 9  Suite Junior
 (10,  9, '2026-05-08', '2026-05-12', 'CHECK_IN'),    -- 10 Suite Premium
 ( 1, 12, '2026-05-20', '2026-05-23', 'CONFIRMADA'),  -- 11
 ( 2,  3, '2026-06-01', '2026-06-04', 'CONFIRMADA'),  -- 12
 ( 5, 28, '2026-06-10', '2026-06-15', 'CONFIRMADA'),  -- 13
 ( 3,  5, '2026-01-05', '2026-01-08', 'CANCELADA');   -- 14

-- ---------------------------------------------------------------------
-- CHECK_IN_CHECK_OUT (estancias)
-- ---------------------------------------------------------------------
INSERT INTO check_in_check_out (id_reserva, id_empleado, id_habitacion, fecha_entrada_real, fecha_salida_real) VALUES
 ( 1, 1,  2, '2026-01-10 14:30:00', '2026-01-15 11:00:00'),  -- estancia 1
 ( 2, 1,  4, '2026-02-05 15:00:00', '2026-02-08 10:30:00'),  -- 2
 ( 3, 2,  7, '2026-02-20 13:45:00', '2026-02-25 11:00:00'),  -- 3
 ( 4, 4, 11, '2026-03-01 16:00:00', '2026-03-04 10:00:00'),  -- 4
 ( 5, 4, 15, '2026-03-15 12:30:00', '2026-03-20 11:30:00'),  -- 5
 ( 6, 5, 17, '2026-04-02 17:20:00', '2026-04-09 10:00:00'),  -- 6
 ( 7, 6, 23, '2026-04-10 14:00:00', '2026-04-13 11:00:00'),  -- 7
 ( 8, 6, 26, '2026-04-15 15:15:00', '2026-04-18 10:30:00'),  -- 8
 ( 9, 7, 27, '2026-05-01 14:00:00', NULL),                   -- 9  (en curso)
 (10, 3,  9, '2026-05-08 13:30:00', NULL);                   -- 10 (en curso)

-- ---------------------------------------------------------------------
-- CONSUMO_SERVICIO
-- precio_unitario se "congela"; subtotal es columna GENERATED.
-- ---------------------------------------------------------------------
INSERT INTO consumo_servicio (id_estancia, id_consumo, id_servicio, fecha, cantidad, precio_unitario) VALUES
 (1, 1, 1, '2026-01-11 08:30:00', 2, 4500.00),   -- E1 serv=52500
 (1, 2, 2, '2026-01-12 21:00:00', 2, 12000.00),
 (1, 3, 5, '2026-01-13 22:30:00', 3, 6500.00),
 (2, 1, 1, '2026-02-06 08:45:00', 2, 4500.00),   -- E2 serv=24000
 (2, 2, 4, '2026-02-07 17:00:00', 1, 15000.00),
 (3, 1, 4, '2026-02-21 16:00:00', 2, 15000.00),  -- E3 serv=63000
 (3, 2, 2, '2026-02-22 21:30:00', 2, 12000.00),
 (3, 3, 1, '2026-02-23 09:00:00', 2, 4500.00),
 (4, 1, 1, '2026-03-02 08:30:00', 1, 4500.00),   -- E4 serv=10500
 (4, 2, 3, '2026-03-03 10:00:00', 2, 3000.00),
 (5, 1, 7, '2026-03-16 18:00:00', 2, 9000.00),   -- E5 serv=75000
 (5, 2, 8, '2026-03-17 11:00:00', 2, 16500.00),
 (5, 3, 2, '2026-03-18 20:30:00', 2, 12000.00),
 (6, 1, 1, '2026-04-03 08:00:00', 7, 4500.00),   -- E6 serv=56000
 (6, 2, 6, '2026-04-04 09:00:00', 7, 3500.00),
 (7, 1, 1, '2026-04-11 08:30:00', 2, 4500.00),   -- E7 serv=19000
 (7, 2,10, '2026-04-12 22:00:00', 4, 2500.00),
 (8, 1, 1, '2026-04-16 09:00:00', 3, 4500.00),   -- E8 serv=26000
 (8, 2,10, '2026-04-17 19:00:00', 5, 2500.00),
 (9, 1, 1, '2026-05-02 08:30:00', 2, 4500.00),   -- E9 (en curso)
 (9, 2, 4, '2026-05-03 16:00:00', 1, 15000.00),
 (10,1, 1, '2026-05-09 08:00:00', 2, 4500.00),   -- E10 (en curso)
 (10,2, 2, '2026-05-10 21:00:00', 2, 12000.00);

-- ---------------------------------------------------------------------
-- FACTURA  (para las 8 estancias finalizadas)
-- monto_total = noches*precio_noche + servicios + IVA(21%)
-- ---------------------------------------------------------------------
-- E1: hab 5*28000=140000 + serv 52500 = 192500 ; IVA 40425 ; total 232925
-- E2: hab 3*35000=105000 + serv 24000 = 129000 ; IVA 27090 ; total 156090
-- E3: hab 5*65000=325000 + serv 63000 = 388000 ; IVA 81480 ; total 469480
-- E4: hab 3*28000=84000  + serv 10500 = 94500  ; IVA 19845 ; total 114345
-- E5: hab 5*65000=325000 + serv 75000 = 400000 ; IVA 84000 ; total 484000
-- E6: hab 7*95000=665000 + serv 56000 = 721000 ; IVA 151410; total 872410
-- E7: hab 3*28000=84000  + serv 19000 = 103000 ; IVA 21630 ; total 124630
-- E8: hab 3*42000=126000 + serv 26000 = 152000 ; IVA 31920 ; total 183920
INSERT INTO factura (id_estancia, fecha_emision, monto_total, impuestos, detalle) VALUES
 (1, '2026-01-15 11:05:00', 232925.00,  40425.00, '5 noches Doble Estandar + servicios'),
 (2, '2026-02-08 10:35:00', 156090.00,  27090.00, '3 noches Doble Superior + servicios'),
 (3, '2026-02-25 11:05:00', 469480.00,  81480.00, '5 noches Suite Junior + servicios'),
 (4, '2026-03-04 10:05:00', 114345.00,  19845.00, '3 noches Doble Estandar + servicios'),
 (5, '2026-03-20 11:35:00', 484000.00,  84000.00, '5 noches Suite Junior + servicios'),
 (6, '2026-04-09 10:05:00', 872410.00, 151410.00, '7 noches Suite Premium + servicios'),
 (7, '2026-04-13 11:05:00', 124630.00,  21630.00, '3 noches Doble Estandar + servicios'),
 (8, '2026-04-18 10:35:00', 183920.00,  31920.00, '3 noches Triple + servicios');

COMMIT;

-- ---------------------------------------------------------------------
-- Verificación de carga
-- ---------------------------------------------------------------------
SELECT 'tipo_habitacion'     AS tabla, COUNT(*) FROM tipo_habitacion
UNION ALL SELECT 'habitacion',          COUNT(*) FROM habitacion
UNION ALL SELECT 'huesped',             COUNT(*) FROM huesped
UNION ALL SELECT 'empleado',            COUNT(*) FROM empleado
UNION ALL SELECT 'servicio',            COUNT(*) FROM servicio
UNION ALL SELECT 'reservacion',         COUNT(*) FROM reservacion
UNION ALL SELECT 'check_in_check_out',  COUNT(*) FROM check_in_check_out
UNION ALL SELECT 'consumo_servicio',    COUNT(*) FROM consumo_servicio
UNION ALL SELECT 'factura',             COUNT(*) FROM factura;

-- =====================================================================
-- FIN DEL SCRIPT 02_dml.sql
-- =====================================================================
