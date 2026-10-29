/* =============================================================================
   Proyecto   : Bajo el Capó · DP-800 (Microsoft SQL AI Developer Associate)
   Script     : database/08_advanced_queries.sql
   Objetivo   : Consultas T-SQL avanzadas, una por técnica, cada una ligada a
                una pregunta de negocio: CTE, window functions, consulta
                correlacionada, JSON y expresiones regulares.
   Requisitos : 03_insert_data.sql y 05_procedures.sql ejecutados.
   Ejecución  : SSMS 22 (solo lectura: no modifica datos)
   Autor      : Emmanuel Grande Sierra
   ============================================================================= */

USE BajoElCapoDB;
GO

-- A: CTE + ROW_NUMBER · ¿Cuáles son las 3 averías más frecuentes de cada modelo?
WITH ranking AS (
    SELECT
        marca,
        modelo,
        titulo,
        frecuencia,
        gravedad,
        ROW_NUMBER() OVER (PARTITION BY modelo_id
                           ORDER BY frecuencia DESC, gravedad DESC) AS posicion
    FROM taller.vw_averias_por_modelo
)
SELECT marca, modelo, posicion, titulo, frecuencia, gravedad
FROM ranking
WHERE posicion <= 3
ORDER BY marca, modelo, posicion;
GO

-- B: window functions · ¿Está cada coche caro o barato frente a su segmento?
SELECT
    segmento,
    marca,
    modelo,
    matricula,
    precio_venta,
    CAST(AVG(precio_venta) OVER (PARTITION BY segmento) AS DECIMAL(10,2))                AS media_segmento,
    CAST(precio_venta - AVG(precio_venta) OVER (PARTITION BY segmento) AS DECIMAL(10,2)) AS diferencia,
    RANK() OVER (PARTITION BY segmento ORDER BY precio_venta)                            AS puesto_mas_barato
FROM catalogo.vw_catalogo
WHERE estado = N'Disponible'
ORDER BY segmento, puesto_mas_barato;
GO

-- C: consulta correlacionada · ¿Qué modelos cuestan más de mantener que la media de su marca?
--    (la subconsulta se evalúa para cada fila, usando la marca del modelo exterior)
SELECT
    ma.nombre                               AS marca,
    mo.nombre                               AS modelo,
    taller.fn_coste_esperado(mo.modelo_id)  AS coste_esperado
FROM catalogo.Modelos AS mo
JOIN catalogo.Marcas  AS ma ON ma.marca_id = mo.marca_id
WHERE taller.fn_coste_esperado(mo.modelo_id) > (
        SELECT AVG(taller.fn_coste_esperado(m2.modelo_id))
        FROM catalogo.Modelos AS m2
        WHERE m2.marca_id = mo.marca_id
      )
ORDER BY marca, coste_esperado DESC;
GO

-- D1: JSON (OPENJSON) · ¿Qué coches disponibles llevan anclajes isofix?
SELECT marca, modelo, matricula, precio_venta
FROM catalogo.vw_catalogo AS c
WHERE c.estado = N'Disponible'
  AND EXISTS (SELECT 1
              FROM OPENJSON(c.equipamiento, '$.extras') AS e
              WHERE e.value = N'isofix')
ORDER BY precio_venta;
GO

-- D2: JSON (JSON_OBJECT + JSON_ARRAYAGG) · Ficha de un coche lista para enviar a una app o a un LLM
DECLARE @vehiculo_id INT = (SELECT MIN(vehiculo_id) FROM catalogo.Vehiculos);

SELECT JSON_OBJECT(
           'matricula'  : v.matricula,
           'marca'      : ma.nombre,
           'modelo'     : mo.nombre,
           'anio'       : v.anio,
           'km'         : v.kilometros,
           'precio'     : v.precio_venta,
           'extras'     : JSON_QUERY(v.equipamiento, '$.extras'),
           -- CAST AS JSON evita que el array ordenado de la subconsulta se escape como texto
           'averias_top': CAST((SELECT JSON_ARRAYAGG(f.titulo ORDER BY f.riesgo DESC)
                                FROM taller.fn_averias_modelo(v.modelo_id) AS f) AS JSON)
       ) AS ficha_json
FROM catalogo.Vehiculos AS v
JOIN catalogo.Modelos   AS mo ON mo.modelo_id = v.modelo_id
JOIN catalogo.Marcas    AS ma ON ma.marca_id  = mo.marca_id
WHERE v.vehiculo_id = @vehiculo_id;
GO

-- E1: regex (REGEXP_REPLACE + REGEXP_LIKE) · Teléfonos normalizados y validación de móvil español
SELECT
    nombre,
    telefono,
    REGEXP_REPLACE(telefono, '[^0-9]', '')                       AS telefono_normalizado,
    CASE WHEN REGEXP_LIKE(REGEXP_REPLACE(telefono, '[^0-9]', ''), '^[67][0-9]{8}$')
         THEN N'Válido' ELSE N'Revisar' END                       AS validacion
FROM ventas.Clientes
ORDER BY validacion DESC, nombre;
GO

-- E2: regex (REGEXP_LIKE, sin distinguir mayúsculas) · Búsqueda por palabras clave en las descripciones
--     Solo encuentra textos que contienen esas palabras; la búsqueda semántica (ai/vector_search.sql)
--     encontrará también coches descritos con otras palabras.
SELECT marca, modelo, descripcion
FROM catalogo.vw_catalogo
WHERE REGEXP_LIKE(descripcion, 'ciudad|urban|aparcar', 'i')
ORDER BY marca, modelo;
GO
