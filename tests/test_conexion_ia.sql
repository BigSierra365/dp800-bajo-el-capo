/* =============================================================================
   Proyecto   : Bajo el Capó · DP-800 (Microsoft SQL AI Developer Associate)
   Script     : tests/test_conexion_ia.sql
   Objetivo   : Comprueba la cadena SQL Server -> Caddy (HTTPS) -> Ollama:
                llamada REST, modelo externo de embeddings y respuesta de chat.
   Requisitos : BajoElCapoDB creada, Ollama con los modelos bge-m3 y qwen2.5:3b,
                Caddy en marcha con su certificado raíz de confianza.
   Ejecución  : SSMS 22 (bloque a bloque), o
                sqlcmd -S localhost -d BajoElCapoDB -E -C -b -i tests\test_conexion_ia.sql
   Autor      : Emmanuel Grande Sierra
   ============================================================================= */

USE BajoElCapoDB;
GO

-- A: activa las llamadas REST desde T-SQL (vienen desactivadas en SQL Server 2025)
EXECUTE sp_configure 'external rest endpoint enabled', 1;
RECONFIGURE WITH OVERRIDE;
GO

-- B: llamada REST directa a Ollama a través de Caddy; valida certificado, proxy y modelo
--    rc = 0 significa HTTP 2xx; las dimensiones deben ser 1024
DECLARE @rc INT, @r NVARCHAR(MAX), @dim INT;
EXEC @rc = sys.sp_invoke_external_rest_endpoint
     @url      = N'https://localhost:11435/api/embed',
     @method   = N'POST',
     @payload  = N'{"model":"bge-m3","input":"prueba de conexión"}',
     @timeout  = 230,
     @response = @r OUTPUT;
SELECT @dim = COUNT(*) FROM OPENJSON(@r, '$.result.embeddings[0]');
SELECT @rc AS rc_http, @dim AS dimensiones;
IF @rc <> 0 OR @dim <> 1024
    THROW 50301, N'B: la llamada REST a /api/embed no devolvió un embedding de 1024 dimensiones.', 1;
GO

-- C: modelo externo de embeddings (CREATE EXTERNAL MODEL solo admite EMBEDDINGS;
--    el chat se llama por REST en el bloque E)
IF EXISTS (SELECT 1 FROM sys.external_models WHERE name = N'EmbeddingsBgeM3')
    DROP EXTERNAL MODEL EmbeddingsBgeM3;
GO
CREATE EXTERNAL MODEL EmbeddingsBgeM3
WITH (
    LOCATION   = 'https://localhost:11435/api/embed',
    API_FORMAT = 'Ollama',
    MODEL_TYPE = EMBEDDINGS,
    MODEL      = 'bge-m3'
);
GO

-- D: embedding con AI_GENERATE_EMBEDDINGS, guardado como VECTOR(1024) y comprobado
DECLARE @v VECTOR(1024) =
    AI_GENERATE_EMBEDDINGS(N'familiar, económico y fiable para ciudad y escapadas' USE MODEL EmbeddingsBgeM3);
SELECT VECTORPROPERTY(@v, 'Dimensions') AS dimensiones;
IF VECTORPROPERTY(@v, 'Dimensions') <> 1024
    THROW 50302, N'D: el vector generado no tiene 1024 dimensiones.', 1;
GO

-- E: respuesta de chat de qwen2.5:3b a través de Caddy (el primer uso carga el modelo y tarda)
DECLARE @rc INT, @r NVARCHAR(MAX), @texto NVARCHAR(MAX);
EXEC @rc = sys.sp_invoke_external_rest_endpoint
     @url      = N'https://localhost:11435/api/chat',
     @method   = N'POST',
     @payload  = N'{"model":"qwen2.5:3b","stream":false,"options":{"temperature":0},"messages":[{"role":"user","content":"Responde solo con la palabra: funciona"}]}',
     @timeout  = 230,
     @response = @r OUTPUT;
SET @texto = JSON_VALUE(@r, '$.result.message.content');
SELECT @rc AS rc_http, @texto AS respuesta_del_modelo;
IF @rc <> 0 OR @texto IS NULL
    THROW 50303, N'E: la llamada REST a /api/chat no devolvió texto.', 1;
GO

-- F: limpieza; el modelo definitivo se crea en ai/create_external_model.sql
DROP EXTERNAL MODEL EmbeddingsBgeM3;
GO

PRINT N'Conexión SQL Server -> Caddy -> Ollama verificada.';
GO
