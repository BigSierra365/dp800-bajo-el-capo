/* =============================================================================
   Proyecto   : Bajo el Capó · DP-800 (Microsoft SQL AI Developer Associate)
   Script     : ai/vector_search.sql
   Objetivo   : Buscador semántico de coches. Una única lógica de ranking
                (ia.fn_ranking_coches) usada por las dos vías:
                - SSMS:     ia.sp_buscar_coches genera el vector de la frase en SQL Server.
                - Terminal: ia.sp_buscar_coches_vector recibe el vector calculado por
                            ai/buscar_coches.ps1 con Ollama.
                Métrica: distancia coseno (0 = mismo significado; 2 = opuesto).
   Requisitos : ai/generate_embeddings.sql ejecutado.
   Ejecución  : SSMS 22, o
                sqlcmd -S localhost -d BajoElCapoDB -E -C -b -I -i ai\vector_search.sql
   Siguiente  : ai/rag.sql
   Autor      : Emmanuel Grande Sierra
   ============================================================================= */

USE BajoElCapoDB;
GO

-- A: ranking compartido · coches disponibles más cercanos al vector, con filtros opcionales
--    Coseno: compara la dirección de los vectores (el significado), no su longitud; bge-m3 está
--    entrenado para esta métrica. Búsqueda exacta: 228 vectores no necesitan índice vectorial.
CREATE OR ALTER FUNCTION ia.fn_ranking_coches
(
    @vector     VECTOR(1024),
    @precio_max DECIMAL(10,2),
    @segmento   NVARCHAR(20),
    @top        INT
)
RETURNS TABLE
AS
RETURN
    SELECT TOP (@top)
        ROW_NUMBER() OVER (ORDER BY d.distancia, d.vehiculo_id) AS posicion,
        CAST(d.distancia AS DECIMAL(6,4))                        AS distancia,
        d.vehiculo_id, d.marca, d.modelo, d.segmento, d.anio, d.kilometros,
        d.combustible, d.precio_venta, d.descripcion
    FROM (
        SELECT v.vehiculo_id, ma.nombre AS marca, mo.nombre AS modelo, mo.segmento, v.anio,
               v.kilometros, v.combustible, v.precio_venta, v.descripcion,
               VECTOR_DISTANCE('cosine', v.embedding, @vector) AS distancia
        FROM catalogo.Vehiculos AS v
        JOIN catalogo.Modelos   AS mo ON mo.modelo_id = v.modelo_id
        JOIN catalogo.Marcas    AS ma ON ma.marca_id  = mo.marca_id
        WHERE v.estado = N'Disponible'
          AND v.embedding IS NOT NULL
          AND (@precio_max IS NULL OR v.precio_venta <= @precio_max)
          AND (@segmento   IS NULL OR mo.segmento    = @segmento)
    ) AS d
    ORDER BY d.distancia, d.vehiculo_id;
GO

-- B: vía SSMS · genera el embedding de la frase con el modelo externo y devuelve el ranking
--    EXECUTE AS ia_servicio: comerciales y mecánicos lo usan sin permisos sobre el modelo
CREATE OR ALTER PROCEDURE ia.sp_buscar_coches
    @consulta   NVARCHAR(4000),
    @precio_max DECIMAL(10,2) = NULL,
    @segmento   NVARCHAR(20)  = NULL,
    @top        INT           = 5
WITH EXECUTE AS 'ia_servicio'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NULLIF(LTRIM(@consulta), N'') IS NULL
        THROW 50303, N'La consulta no puede estar vacía.', 1;

    DECLARE @vector VECTOR(1024);
    BEGIN TRY
        SET @vector = AI_GENERATE_EMBEDDINGS(@consulta USE MODEL EmbeddingsBgeM3);
    END TRY
    BEGIN CATCH
        DECLARE @msg NVARCHAR(2048) = CONCAT(N'No se pudo generar el embedding de la consulta. ',
                                             N'Comprueba Ollama y Caddy. Detalle: ', ERROR_MESSAGE());
        THROW 50304, @msg, 1;
    END CATCH

    SELECT posicion, distancia, marca, modelo, segmento, anio, kilometros, combustible, precio_venta, descripcion
    FROM ia.fn_ranking_coches(@vector, @precio_max, @segmento, @top)
    ORDER BY posicion;
END;
GO

-- C: vía terminal · recibe el vector (array JSON de 1024 valores) y devuelve el mismo ranking
CREATE OR ALTER PROCEDURE ia.sp_buscar_coches_vector
    @vector     NVARCHAR(MAX),
    @precio_max DECIMAL(10,2) = NULL,
    @segmento   NVARCHAR(20)  = NULL,
    @top        INT           = 5
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v VECTOR(1024) = TRY_CAST(@vector AS VECTOR(1024));
    IF @v IS NULL
        THROW 50305, N'El vector recibido no es un array JSON de 1024 valores.', 1;

    SELECT posicion, distancia, marca, modelo, segmento, anio, kilometros, combustible, precio_venta, descripcion
    FROM ia.fn_ranking_coches(@v, @precio_max, @segmento, @top)
    ORDER BY posicion;
END;
GO

-- D: ejemplos con las tres frases de prueba (vía SSMS)
EXEC ia.sp_buscar_coches
     @consulta   = N'familiar, económico y fiable para ciudad y escapadas',
     @precio_max = 14000,
     @top        = 5;

EXEC ia.sp_buscar_coches
     @consulta = N'coche cómodo para viajes largos por autopista',
     @top      = 5;

EXEC ia.sp_buscar_coches
     @consulta = N'aventura por caminos de tierra y fines de semana en el campo',
     @segmento = N'SUV',
     @top      = 5;
GO
