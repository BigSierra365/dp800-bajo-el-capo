/* =============================================================================
   Proyecto   : Bajo el Capó · DP-800 (Microsoft SQL AI Developer Associate)
   Script     : ai/generate_embeddings.sql
   Objetivo   : Genera y guarda los embeddings (VECTOR(1024)) de coches y averías
                con AI_GENERATE_EMBEDDINGS y el modelo externo bge-m3.
                - Coches:  marca, modelo, segmento, combustible y descripción.
                - Averías: título, síntoma, causa y solución.
   Requisitos : ai/create_external_model.sql ejecutado.
   Ejecución  : SSMS 22, o
                sqlcmd -S localhost -d BajoElCapoDB -E -C -b -I -i ai\generate_embeddings.sql
                Re-ejecutable: solo procesa las filas con embedding NULL.
   Siguiente  : ai/vector_search.sql
   Autor      : Emmanuel Grande Sierra
   ============================================================================= */

USE BajoElCapoDB;
GO

-- A: procedimiento por lotes; cada lote es una transacción, así que si Ollama falla a mitad
--    lo ya procesado se queda y una nueva ejecución continúa desde ahí
CREATE OR ALTER PROCEDURE ia.sp_generar_embeddings
    @lote INT = 25
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @filas INT = 1, @coches INT = 0, @averias INT = 0;

    BEGIN TRY
        -- A1: coches
        WHILE @filas > 0
        BEGIN
            BEGIN TRANSACTION;
            UPDATE TOP (@lote) v
            SET embedding = AI_GENERATE_EMBEDDINGS(
                    CONCAT(ma.nombre, N' ', mo.nombre, N'. Segmento: ', mo.segmento,
                           N'. Combustible: ', v.combustible, N'. ', v.descripcion)
                    USE MODEL EmbeddingsBgeM3)
            FROM catalogo.Vehiculos AS v
            JOIN catalogo.Modelos   AS mo ON mo.modelo_id = v.modelo_id
            JOIN catalogo.Marcas    AS ma ON ma.marca_id  = mo.marca_id
            WHERE v.embedding IS NULL;
            SET @filas = @@ROWCOUNT;
            COMMIT TRANSACTION;
            SET @coches += @filas;
        END

        -- A2: averías
        SET @filas = 1;
        WHILE @filas > 0
        BEGIN
            BEGIN TRANSACTION;
            UPDATE TOP (@lote) taller.Averias
            SET embedding = AI_GENERATE_EMBEDDINGS(
                    CONCAT(titulo, N'. Síntoma: ', sintoma, N'. Causa: ', causa, N'. Solución: ', solucion)
                    USE MODEL EmbeddingsBgeM3)
            WHERE embedding IS NULL;
            SET @filas = @@ROWCOUNT;
            COMMIT TRANSACTION;
            SET @averias += @filas;
        END
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @msg NVARCHAR(2048) = CONCAT(
            N'Error al generar embeddings (procesados antes del error: ', @coches, N' coches, ',
            @averias, N' averías). Comprueba Ollama y Caddy. Detalle: ', ERROR_MESSAGE());
        THROW 50302, @msg, 1;
    END CATCH

    SELECT @coches AS coches_procesados, @averias AS averias_procesadas;
END;
GO

-- B: solo el administrador (y el propietario) regeneran embeddings (ver decisión D09)
DENY EXECUTE ON ia.sp_generar_embeddings TO rol_comercial;
DENY EXECUTE ON ia.sp_generar_embeddings TO rol_mecanico;
GO

-- C: generación y comprobación de dimensiones
EXEC ia.sp_generar_embeddings;

SELECT N'Vehiculos' AS tabla, COUNT(*) AS filas, COUNT(embedding) AS con_embedding,
       MIN(VECTORPROPERTY(embedding, 'Dimensions')) AS dimensiones
FROM catalogo.Vehiculos
UNION ALL
SELECT N'Averias', COUNT(*), COUNT(embedding), MIN(VECTORPROPERTY(embedding, 'Dimensions'))
FROM taller.Averias;
GO
