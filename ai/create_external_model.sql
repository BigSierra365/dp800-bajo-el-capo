/* =============================================================================
   Proyecto   : Bajo el Capó · DP-800 (Microsoft SQL AI Developer Associate)
   Script     : ai/create_external_model.sql
   Objetivo   : Registra en SQL Server el modelo de embeddings bge-m3 de Ollama
                (a través de Caddy, porque SQL Server solo llama por HTTPS) y da al
                servicio de IA los permisos para usarlo.
   Requisitos : database/06_security.sql ejecutado (rol_ia_servicio).
                Ollama con bge-m3 y Caddy en https://localhost:11435 con su
                certificado raíz de confianza en el equipo.
   Ejecución  : SSMS 22, o
                sqlcmd -S localhost -d BajoElCapoDB -E -C -b -I -i ai\create_external_model.sql
                Re-ejecutable.
   Siguiente  : ai/generate_embeddings.sql
   Autor      : Emmanuel Grande Sierra
   ============================================================================= */

USE BajoElCapoDB;
GO

-- A: activa las llamadas REST desde T-SQL (vienen desactivadas en SQL Server 2025)
EXECUTE sp_configure 'external rest endpoint enabled', 1;
RECONFIGURE WITH OVERRIDE;
GO

-- B: modelo externo de embeddings (bge-m3 devuelve vectores de 1024 dimensiones)
--    Se borra y se crea de nuevo para que el script se pueda repetir.
IF EXISTS (SELECT 1 FROM sys.external_models WHERE name = N'EmbeddingsBgeM3')
    DROP EXTERNAL MODEL EmbeddingsBgeM3;
GO
CREATE EXTERNAL MODEL EmbeddingsBgeM3
WITH (
    LOCATION   = 'https://localhost:11435/api/embed',
    API_FORMAT = 'Ollama',
    MODEL_TYPE = EMBEDDINGS,
    MODEL      = 'bge-m3',
    PARAMETERS = '{"sql_rest_options":{"retry_count":2}}'   -- reintenta si Ollama está cargando el modelo
);
GO

-- C: permisos del servicio de IA · usar el modelo y llamar a endpoints REST (el chat del RAG)
--    Comerciales y mecánicos no los reciben: usan los procedimientos de ia, que se ejecutan
--    con el contexto de ia_servicio.
GRANT EXECUTE ON EXTERNAL MODEL::EmbeddingsBgeM3 TO rol_ia_servicio;
GRANT EXECUTE ANY EXTERNAL ENDPOINT TO rol_ia_servicio;
GO

-- D: comprobación · el modelo existe y genera un vector de 1024 dimensiones
SELECT name AS modelo, api_format, model_type_desc, model, location
FROM sys.external_models
WHERE name = N'EmbeddingsBgeM3';

DECLARE @v VECTOR(1024) = AI_GENERATE_EMBEDDINGS(N'prueba del modelo externo' USE MODEL EmbeddingsBgeM3);
IF @v IS NULL OR VECTORPROPERTY(@v, 'Dimensions') <> 1024
    THROW 50301, N'El modelo externo EmbeddingsBgeM3 no devolvió un vector de 1024 dimensiones. Comprueba Ollama y Caddy.', 1;
PRINT N'Modelo externo EmbeddingsBgeM3 creado y comprobado (1024 dimensiones).';
GO
