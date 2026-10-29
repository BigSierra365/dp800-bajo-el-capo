/* =============================================================================
   Proyecto   : Bajo el Capó · DP-800 (Microsoft SQL AI Developer Associate)
   Script     : database/07_indexes.sql
   Objetivo   : Optimización de la consulta del listado del catálogo (primera
                página de coches disponibles de un segmento y un rango de precio).
                Carga temporal de unos 50.000 coches, medición antes y después de
                un índice compuesto, y borrado de la carga (el índice se queda).
   Requisitos : 06_security.sql ejecutado.
   Ejecución  : SSMS 22 con «Incluir plan de ejecución real» (Ctrl+M), o
                sqlcmd -S localhost -d BajoElCapoDB -E -C -b -I -i database\07_indexes.sql
                Planes reales y mediciones: tests\medir_optimizacion.ps1
   Siguiente  : 08_advanced_queries.sql
   Autor      : Emmanuel Grande Sierra
   ============================================================================= */

USE BajoElCapoDB;
GO
SET NOCOUNT ON;
GO

-- A: limpieza previa · sin el índice de la mejora y sin restos de cargas anteriores
DROP INDEX IF EXISTS ix_vehiculos_estado_precio ON catalogo.Vehiculos;
DELETE FROM catalogo.Vehiculos WHERE descripcion LIKE N'[[]CARGA]%';
GO

-- B: carga de 50.000 coches de prueba con GENERATE_SERIES
--    Matrícula válida para el CHECK de 02 (4 cifras + 3 letras sin vocales), sin repetir las
--    existentes; modelos, años, combustibles, precios y estados repartidos de forma regular.
--    Marcador: la descripción empieza por [CARGA], para poder borrarlos en el bloque F.
DECLARE @letras CHAR(20) = 'BCDFGHJKLMNPRSTVWXYZ';

WITH modelos AS (
    SELECT modelo_id,
           ROW_NUMBER() OVER (ORDER BY modelo_id) - 1 AS pos,
           COUNT(*) OVER ()                       AS total
    FROM catalogo.Modelos
),
serie AS (
    SELECT s.value AS n,
           CONCAT(RIGHT(CONCAT('000', s.value % 10000), 4),
                  SUBSTRING(@letras, (s.value / 10000) / 400 % 20 + 1, 1),
                  SUBSTRING(@letras, (s.value / 10000) / 20  % 20 + 1, 1),
                  SUBSTRING(@letras, (s.value / 10000)       % 20 + 1, 1)) AS matricula
    FROM GENERATE_SERIES(0, 52999) AS s
)
INSERT INTO catalogo.Vehiculos
    (modelo_id, matricula, anio, kilometros, combustible, precio_venta, precio_compra, descripcion, estado)
SELECT TOP (50000)
    m.modelo_id,
    s.matricula,
    2012 + s.n % 13,
    (s.n * 7919) % 250000,
    CHOOSE(s.n % 5 + 1, N'Gasolina', N'Diésel', N'Híbrido', N'Eléctrico', N'GLP'),
    CAST(3500 + (s.n * 37) % 26500 AS DECIMAL(10,2)),
    CAST((3500 + (s.n * 37) % 26500) * 0.8 AS DECIMAL(10,2)),
    N'[CARGA] Coche de prueba para medir el rendimiento del listado del catálogo con un volumen '
    + N'ampliado de stock; texto de relleno con una longitud parecida a las descripciones reales.',
    CASE WHEN s.n % 20 < 14 THEN N'Disponible' WHEN s.n % 20 < 17 THEN N'Reservado' ELSE N'Vendido' END
FROM serie   AS s
JOIN modelos AS m ON m.pos = s.n % m.total
WHERE NOT EXISTS (SELECT 1 FROM catalogo.Vehiculos AS v WHERE v.matricula = s.matricula)
ORDER BY s.n;

UPDATE STATISTICS catalogo.Vehiculos WITH FULLSCAN;   -- estadísticas al día para los dos planes

SELECT COUNT(*) AS vehiculos_totales,
       SUM(CASE WHEN descripcion LIKE N'[[]CARGA]%' THEN 1 ELSE 0 END) AS vehiculos_de_carga
FROM catalogo.Vehiculos;
GO

-- C: consulta ANTES de la mejora · primera página del listado (50 SUV disponibles de 10.000
--    a 15.000 €, los más baratos primero). Se ejecuta dos veces: se compara la segunda.
SET STATISTICS IO, TIME ON;
PRINT N'C1: ANTES, primera ejecución';
SELECT TOP (50) v.matricula, ma.nombre AS marca, mo.nombre AS modelo, v.anio, v.kilometros, v.precio_venta
FROM catalogo.Vehiculos AS v
JOIN catalogo.Modelos   AS mo ON mo.modelo_id = v.modelo_id
JOIN catalogo.Marcas    AS ma ON ma.marca_id  = mo.marca_id
WHERE v.estado = N'Disponible'
  AND mo.segmento = N'SUV'
  AND v.precio_venta BETWEEN 10000 AND 15000
ORDER BY v.precio_venta;
PRINT N'C2: ANTES, segunda ejecución (la que se compara)';
SELECT TOP (50) v.matricula, ma.nombre AS marca, mo.nombre AS modelo, v.anio, v.kilometros, v.precio_venta
FROM catalogo.Vehiculos AS v
JOIN catalogo.Modelos   AS mo ON mo.modelo_id = v.modelo_id
JOIN catalogo.Marcas    AS ma ON ma.marca_id  = mo.marca_id
WHERE v.estado = N'Disponible'
  AND mo.segmento = N'SUV'
  AND v.precio_venta BETWEEN 10000 AND 15000
ORDER BY v.precio_venta;
SET STATISTICS IO, TIME OFF;
GO

-- D: la mejora · índice compuesto sobre los filtros del propio coche
--    - estado primero: predicado de igualdad, el más útil para delimitar el rango del índice.
--    - precio_venta después: predicado de rango y columna del ORDER BY; dentro de un mismo estado
--      las filas quedan ya ordenadas por precio, así que el TOP (50) puede parar pronto sin ordenar.
--    - INCLUDE: modelo_id (JOIN con Modelos) y las columnas que se muestran; el índice cubre la
--      consulta y evita los key lookups a la tabla, cuyas filas son anchas (descripción, JSON, vector).
--    - El segmento está en Modelos (24 filas) y se resuelve con el JOIN; no cabe en este índice.
CREATE INDEX ix_vehiculos_estado_precio
    ON catalogo.Vehiculos (estado, precio_venta)
    INCLUDE (modelo_id, matricula, anio, kilometros);
GO

-- E: consulta DESPUÉS de la mejora · idéntica a la del bloque C
SET STATISTICS IO, TIME ON;
PRINT N'E1: DESPUÉS, primera ejecución';
SELECT TOP (50) v.matricula, ma.nombre AS marca, mo.nombre AS modelo, v.anio, v.kilometros, v.precio_venta
FROM catalogo.Vehiculos AS v
JOIN catalogo.Modelos   AS mo ON mo.modelo_id = v.modelo_id
JOIN catalogo.Marcas    AS ma ON ma.marca_id  = mo.marca_id
WHERE v.estado = N'Disponible'
  AND mo.segmento = N'SUV'
  AND v.precio_venta BETWEEN 10000 AND 15000
ORDER BY v.precio_venta;
PRINT N'E2: DESPUÉS, segunda ejecución (la que se compara)';
SELECT TOP (50) v.matricula, ma.nombre AS marca, mo.nombre AS modelo, v.anio, v.kilometros, v.precio_venta
FROM catalogo.Vehiculos AS v
JOIN catalogo.Modelos   AS mo ON mo.modelo_id = v.modelo_id
JOIN catalogo.Marcas    AS ma ON ma.marca_id  = mo.marca_id
WHERE v.estado = N'Disponible'
  AND mo.segmento = N'SUV'
  AND v.precio_venta BETWEEN 10000 AND 15000
ORDER BY v.precio_venta;
SET STATISTICS IO, TIME OFF;
GO

-- F: borrado de la carga; el índice se mantiene y vuelven los 228 coches de 03
DELETE FROM catalogo.Vehiculos WHERE descripcion LIKE N'[[]CARGA]%';
UPDATE STATISTICS catalogo.Vehiculos WITH FULLSCAN;
SELECT COUNT(*) AS vehiculos_tras_limpieza FROM catalogo.Vehiculos;
GO

PRINT N'Optimización terminada: índice ix_vehiculos_estado_precio creado y carga borrada.';
GO
