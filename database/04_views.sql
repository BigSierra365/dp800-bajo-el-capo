/* =============================================================================
   Proyecto   : Bajo el Capó · DP-800 (Microsoft SQL AI Developer Associate)
   Script     : database/04_views.sql
   Objetivo   : Crea las vistas de consulta del catálogo, las averías y las
                reservas. Son la puerta de acceso de los usuarios no
                administradores (ver 06_security.sql).
   Requisitos : 02_create_tables.sql ejecutado.
   Ejecución  : SSMS 22, o
                sqlcmd -S localhost -d BajoElCapoDB -E -C -b -i database\04_views.sql
   Siguiente  : 05_procedures.sql
   Autor      : Emmanuel Grande Sierra
   ============================================================================= */

USE BajoElCapoDB;
GO

-- A: catálogo comercial; nunca expone precio_compra (margen interno del concesionario)
CREATE OR ALTER VIEW catalogo.vw_catalogo
AS
SELECT
    v.vehiculo_id,
    v.matricula,
    ma.nombre      AS marca,
    mo.nombre      AS modelo,
    mo.segmento,
    v.anio,
    v.kilometros,
    v.combustible,
    v.precio_venta,
    v.descripcion,
    v.equipamiento,
    v.estado
FROM catalogo.Vehiculos AS v
JOIN catalogo.Modelos   AS mo ON mo.modelo_id = v.modelo_id
JOIN catalogo.Marcas    AS ma ON ma.marca_id  = mo.marca_id;
GO
-- Ejemplo: SELECT marca, modelo, precio_venta FROM catalogo.vw_catalogo WHERE estado = N'Disponible';

-- B: averías conocidas de cada modelo; riesgo = frecuencia × gravedad (de 1 a 25)
CREATE OR ALTER VIEW taller.vw_averias_por_modelo
AS
SELECT
    mo.modelo_id,
    ma.nombre                     AS marca,
    mo.nombre                     AS modelo,
    a.averia_id,
    a.titulo,
    a.coste_estimado,
    mam.frecuencia,
    mam.gravedad,
    mam.frecuencia * mam.gravedad AS riesgo
FROM taller.ModeloAveria AS mam
JOIN taller.Averias      AS a  ON a.averia_id  = mam.averia_id
JOIN catalogo.Modelos    AS mo ON mo.modelo_id = mam.modelo_id
JOIN catalogo.Marcas     AS ma ON ma.marca_id  = mo.marca_id;
GO
-- Ejemplo: SELECT titulo, riesgo FROM taller.vw_averias_por_modelo WHERE modelo = N'León';

-- C: reservas con vehículo, cliente y comercial (RLS y DDM de las tablas base se aplican también aquí)
CREATE OR ALTER VIEW ventas.vw_reservas
AS
SELECT
    r.reserva_id,
    r.fecha,
    r.estado,
    v.matricula,
    ma.nombre     AS marca,
    mo.nombre     AS modelo,
    c.cliente_id,
    c.nombre      AS cliente,
    c.email,
    c.telefono,
    co.nombre     AS comercial
FROM ventas.Reservas      AS r
JOIN catalogo.Vehiculos   AS v  ON v.vehiculo_id   = r.vehiculo_id
JOIN catalogo.Modelos     AS mo ON mo.modelo_id    = v.modelo_id
JOIN catalogo.Marcas      AS ma ON ma.marca_id     = mo.marca_id
JOIN ventas.Clientes      AS c  ON c.cliente_id    = r.cliente_id
JOIN ventas.Comerciales   AS co ON co.comercial_id = r.comercial_id;
GO
-- Ejemplo: SELECT cliente, modelo, estado FROM ventas.vw_reservas WHERE estado = N'Activa';

PRINT N'Vistas creadas: vw_catalogo, vw_averias_por_modelo, vw_reservas.';
GO
