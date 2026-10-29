/* =============================================================================
   Proyecto   : Bajo el Capó · DP-800 (Microsoft SQL AI Developer Associate)
   Script     : ai/rag.sql
   Objetivo   : Asesor de averías con RAG. La recuperación (búsqueda vectorial), el
                contexto y el prompt se construyen aquí y los usan las dos vías:
                - SSMS:     ia.sp_asesor_averias (embedding, recuperación y llamada a
                            qwen2.5:3b dentro de SQL Server, vía Caddy).
                - Terminal: ai/asesor_averias.ps1 con ia.sp_contexto_averias_vector.
   Requisitos : ai/vector_search.sql ejecutado. Ollama (qwen2.5:3b) y Caddy en marcha.
   Ejecución  : SSMS 22, o
                sqlcmd -S localhost -d BajoElCapoDB -E -C -b -I -i ai\rag.sql
   Siguiente  : tests/tests_ia.sql
   Autor      : Emmanuel Grande Sierra
   ============================================================================= */

USE BajoElCapoDB;
GO

-- A: documentos recuperados · averías más cercanas a la pregunta (solo las del modelo si se
--    indica, mediante taller.ModeloAveria) y hasta 3 coches disponibles similares, como texto
CREATE OR ALTER FUNCTION ia.fn_documentos_rag
(
    @vector VECTOR(1024),
    @modelo NVARCHAR(100),
    @top    INT
)
RETURNS TABLE
AS
RETURN
    WITH modelo_sel AS (
        SELECT mo.modelo_id
        FROM catalogo.Modelos AS mo
        JOIN catalogo.Marcas  AS ma ON ma.marca_id = mo.marca_id
        WHERE @modelo IS NOT NULL
          AND (mo.nombre = @modelo OR CONCAT(ma.nombre, N' ', mo.nombre) = @modelo)
    ),
    averias AS (
        SELECT TOP (@top)
            a.averia_id, a.titulo, a.sintoma, a.solucion, a.coste_estimado,
            mam.frecuencia, mam.gravedad,
            VECTOR_DISTANCE('cosine', a.embedding, @vector) AS distancia
        FROM taller.Averias AS a
        LEFT JOIN taller.ModeloAveria AS mam
               ON mam.averia_id = a.averia_id
              AND mam.modelo_id IN (SELECT modelo_id FROM modelo_sel)
        WHERE @modelo IS NULL OR mam.modelo_id IS NOT NULL
        ORDER BY distancia, a.averia_id
    ),
    coches AS (
        SELECT TOP (3)
            v.vehiculo_id, ma.nombre AS marca, mo.nombre AS modelo, v.anio, v.kilometros,
            v.combustible, v.precio_venta,
            VECTOR_DISTANCE('cosine', v.embedding, @vector) AS distancia
        FROM catalogo.Vehiculos AS v
        JOIN catalogo.Modelos   AS mo ON mo.modelo_id = v.modelo_id
        JOIN catalogo.Marcas    AS ma ON ma.marca_id  = mo.marca_id
        WHERE v.estado = N'Disponible'
          AND (@modelo IS NULL OR v.modelo_id IN (SELECT modelo_id FROM modelo_sel))
        ORDER BY distancia, v.vehiculo_id
    )
    SELECT N'avería' AS tipo,
           ROW_NUMBER() OVER (ORDER BY distancia, averia_id) AS posicion,
           CAST(distancia AS DECIMAL(6,4)) AS distancia,
           CONCAT(N'Avería: ', titulo, N'. Síntoma: ', sintoma, N' Solución: ', solucion,
                  N' Coste estimado: ', CAST(coste_estimado AS INT), N' €.',
                  CASE WHEN frecuencia IS NOT NULL
                       THEN CONCAT(N' Frecuencia ', frecuencia, N'/5, gravedad ', gravedad,
                                   N'/5, riesgo ', frecuencia * gravedad, N'/25.') END,
                  CASE WHEN @modelo IS NULL
                       THEN CONCAT(N' Modelos afectados: ',
                                   (SELECT STRING_AGG(CONCAT(ma2.nombre, N' ', mo2.nombre), N', ')
                                    FROM taller.ModeloAveria AS m2
                                    JOIN catalogo.Modelos AS mo2 ON mo2.modelo_id = m2.modelo_id
                                    JOIN catalogo.Marcas  AS ma2 ON ma2.marca_id  = mo2.marca_id
                                    WHERE m2.averia_id = averias.averia_id), N'.') END) AS documento
    FROM averias
    UNION ALL
    SELECT N'coche',
           ROW_NUMBER() OVER (ORDER BY distancia, vehiculo_id),
           CAST(distancia AS DECIMAL(6,4)),
           CONCAT(N'Coche disponible: ', marca, N' ', modelo, N' de ', anio, N', ', kilometros,
                  N' km, ', combustible, N', ', CAST(precio_venta AS INT), N' €.')
    FROM coches;
GO

-- B: contexto · los documentos agrupados por secciones; si no hay averías lo dice «(ninguna)»
CREATE OR ALTER FUNCTION ia.fn_contexto_rag
(
    @vector VECTOR(1024),
    @modelo NVARCHAR(100),
    @top    INT
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @averias NVARCHAR(MAX), @coches NVARCHAR(MAX);
    SELECT @averias = STRING_AGG(CAST(CONCAT(N'- ', documento) AS NVARCHAR(MAX)), NCHAR(10))
                      WITHIN GROUP (ORDER BY posicion)
    FROM ia.fn_documentos_rag(@vector, @modelo, @top) WHERE tipo = N'avería';
    SELECT @coches  = STRING_AGG(CAST(CONCAT(N'- ', documento) AS NVARCHAR(MAX)), NCHAR(10))
                      WITHIN GROUP (ORDER BY posicion)
    FROM ia.fn_documentos_rag(@vector, @modelo, @top) WHERE tipo = N'coche';

    RETURN CONCAT(N'AVERÍAS REGISTRADAS EN BAJO EL CAPÓ', CASE WHEN @modelo IS NOT NULL THEN CONCAT(N' PARA ', @modelo) END, N':', NCHAR(10),
                  ISNULL(@averias, N'(ninguna)'), NCHAR(10), NCHAR(10),
                  N'COCHES DISPONIBLES RELACIONADOS:', NCHAR(10),
                  ISNULL(@coches, N'(ninguno)'));
END;
GO

-- C: prompt de sistema restrictivo, único para las dos vías
CREATE OR ALTER FUNCTION ia.fn_prompt_sistema ()
RETURNS NVARCHAR(1000)
AS
BEGIN
    RETURN N'Eres el asesor de averías del concesionario Bajo el Capó. '
         + N'Responde solo con el contexto proporcionado. Si no hay datos suficientes, dilo. '
         + N'Cita únicamente averías y costes que aparezcan en el contexto; no inventes averías, causas ni precios. '
         + N'Si la sección de averías dice (ninguna), responde que no hay averías registradas para ese modelo. '
         + N'Responde en español, en un máximo de cinco frases.';
END;
GO

-- D: vía terminal · recibe el vector de la pregunta y devuelve los documentos, el prompt y el
--    mensaje que hay que enviar al modelo (así las dos vías envían exactamente lo mismo)
CREATE OR ALTER PROCEDURE ia.sp_contexto_averias_vector
    @vector   NVARCHAR(MAX),
    @modelo   NVARCHAR(100)  = NULL,
    @top      INT            = 5,
    @pregunta NVARCHAR(4000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v VECTOR(1024) = TRY_CAST(@vector AS VECTOR(1024));
    IF @v IS NULL
        THROW 50305, N'El vector recibido no es un array JSON de 1024 valores.', 1;
    IF @modelo IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM catalogo.Modelos AS mo JOIN catalogo.Marcas AS ma ON ma.marca_id = mo.marca_id
        WHERE mo.nombre = @modelo OR CONCAT(ma.nombre, N' ', mo.nombre) = @modelo)
        THROW 50306, N'El modelo indicado no existe en el catálogo.', 1;

    DECLARE @contexto NVARCHAR(MAX) = ia.fn_contexto_rag(@v, @modelo, @top);

    SELECT tipo, posicion, distancia, documento
    FROM ia.fn_documentos_rag(@v, @modelo, @top)
    ORDER BY CASE tipo WHEN N'avería' THEN 1 ELSE 2 END, posicion;

    SELECT ia.fn_prompt_sistema() AS prompt_sistema,
           CONCAT(N'Contexto:', NCHAR(10), @contexto, NCHAR(10), NCHAR(10), N'Pregunta: ', @pregunta) AS mensaje_usuario;
END;
GO

-- E: vía SSMS · RAG completo dentro de SQL Server; cuatro conjuntos de resultados:
--    1 pregunta, 2 documentos recuperados, 3 contexto enviado, 4 respuesta
--    EXECUTE AS ia_servicio: comerciales y mecánicos no necesitan permisos sobre el modelo
CREATE OR ALTER PROCEDURE ia.sp_asesor_averias
    @pregunta  NVARCHAR(4000),
    @modelo    NVARCHAR(100) = NULL,
    @top       INT           = 5,
    @respuesta NVARCHAR(MAX) = NULL OUTPUT
WITH EXECUTE AS 'ia_servicio'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- E1: validaciones
    IF NULLIF(LTRIM(@pregunta), N'') IS NULL
        THROW 50303, N'La pregunta no puede estar vacía.', 1;
    IF @modelo IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM catalogo.Modelos AS mo JOIN catalogo.Marcas AS ma ON ma.marca_id = mo.marca_id
        WHERE mo.nombre = @modelo OR CONCAT(ma.nombre, N' ', mo.nombre) = @modelo)
        THROW 50306, N'El modelo indicado no existe en el catálogo.', 1;

    -- E2: embedding de la pregunta
    DECLARE @v VECTOR(1024), @msg NVARCHAR(2048);
    BEGIN TRY
        SET @v = AI_GENERATE_EMBEDDINGS(@pregunta USE MODEL EmbeddingsBgeM3);
    END TRY
    BEGIN CATCH
        SET @msg = CONCAT(N'No se pudo generar el embedding de la pregunta. Comprueba Ollama y Caddy. Detalle: ', ERROR_MESSAGE());
        THROW 50304, @msg, 1;
    END CATCH

    -- E3: contexto y mensajes (la misma construcción que usa la vía terminal)
    DECLARE @sistema NVARCHAR(1000) = ia.fn_prompt_sistema();
    DECLARE @mensaje NVARCHAR(MAX)  = CONCAT(N'Contexto:', NCHAR(10), ia.fn_contexto_rag(@v, @modelo, @top),
                                             NCHAR(10), NCHAR(10), N'Pregunta: ', @pregunta);

    -- E4: llamada a qwen2.5:3b por Caddy (stream false, temperatura 0); también si no hay averías,
    --     para demostrar que el prompt restrictivo evita que invente
    DECLARE @payload NVARCHAR(MAX) = CAST(JSON_OBJECT(
        'model'   : 'qwen2.5:3b',
        'options' : JSON_OBJECT('temperature' : 0),
        'messages': JSON_ARRAY(JSON_OBJECT('role' : 'system', 'content' : @sistema),
                               JSON_OBJECT('role' : 'user',   'content' : @mensaje))) AS NVARCHAR(MAX));
    SET @payload = JSON_MODIFY(@payload, '$.stream', CAST(0 AS BIT));

    DECLARE @rc INT, @r NVARCHAR(MAX);
    BEGIN TRY
        EXEC @rc = sys.sp_invoke_external_rest_endpoint
             @url      = N'https://localhost:11435/api/chat',
             @method   = N'POST',
             @payload  = @payload,
             @timeout  = 230,
             @response = @r OUTPUT;
    END TRY
    BEGIN CATCH
        SET @msg = CONCAT(N'No se pudo llamar al modelo de chat. Comprueba Ollama y Caddy. Detalle: ', ERROR_MESSAGE());
        THROW 50308, @msg, 1;
    END CATCH
    IF @rc <> 0
    BEGIN
        SET @msg = CONCAT(N'El modelo de chat respondió con el código HTTP ', @rc, N'.');
        THROW 50307, @msg, 1;
    END

    -- ruta comprobada en una respuesta real (tests/test_conexion_ia.sql); OPENJSON no corta a 4000
    SELECT @respuesta = content
    FROM OPENJSON(@r, '$.result.message') WITH (content NVARCHAR(MAX) '$.content');
    IF NULLIF(LTRIM(@respuesta), N'') IS NULL
        THROW 50308, N'La respuesta del modelo de chat no contiene texto.', 1;

    -- E5: las cuatro partes del RAG
    SELECT @pregunta AS pregunta, @modelo AS modelo;
    SELECT tipo, posicion, distancia, documento
    FROM ia.fn_documentos_rag(@v, @modelo, @top)
    ORDER BY CASE tipo WHEN N'avería' THEN 1 ELSE 2 END, posicion;
    SELECT @sistema AS prompt_sistema, @mensaje AS contexto_enviado;
    SELECT @respuesta AS respuesta;
END;
GO

-- F: ejemplos · dos preguntas y el caso de control (Dacia Jogger, sin averías registradas)
EXEC ia.sp_asesor_averias
     @pregunta = N'¿Qué averías suele tener y cuánto cuesta repararlas?',
     @modelo   = N'Peugeot 308 SW';

EXEC ia.sp_asesor_averias
     @pregunta = N'Al acelerar noto tirones y el embrague patina, ¿qué puede ser y cuánto cuesta arreglarlo?';

EXEC ia.sp_asesor_averias
     @pregunta = N'¿Qué averías suele tener y cuánto cuesta repararlas?',
     @modelo   = N'Dacia Jogger';
GO
