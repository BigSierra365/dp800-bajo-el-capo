/* =============================================================================
   Proyecto   : Bajo el Capó · DP-800 (Microsoft SQL AI Developer Associate)
   Script     : tests/tests_ia.sql
   Objetivo   : Tests de la parte de IA: embeddings, buscador semántico y asesor
                de averías (RAG). Cada fallo lanza THROW 500xx.
   Requisitos : scripts de ai/ ejecutados. Ollama y Caddy en marcha.
   Ejecución  : .\run_all.ps1 -ConIA, o
                sqlcmd -S localhost -d BajoElCapoDB -E -C -b -I -f 65001 -i tests\tests_ia.sql
   Autor      : Emmanuel Grande Sierra
   ============================================================================= */

USE BajoElCapoDB;
GO
SET NOCOUNT ON;
GO

-- I: embeddings · ningún coche ni avería sin vector y todos con 1024 dimensiones
IF EXISTS (SELECT 1 FROM catalogo.Vehiculos WHERE embedding IS NULL)
OR EXISTS (SELECT 1 FROM taller.Averias     WHERE embedding IS NULL)
    THROW 50060, N'I: hay coches o averías sin embedding.', 1;
IF EXISTS (SELECT 1 FROM catalogo.Vehiculos WHERE VECTORPROPERTY(embedding, 'Dimensions') <> 1024)
OR EXISTS (SELECT 1 FROM taller.Averias     WHERE VECTORPROPERTY(embedding, 'Dimensions') <> 1024)
    THROW 50061, N'I: hay vectores que no tienen 1024 dimensiones.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.external_models WHERE name = N'EmbeddingsBgeM3')
    THROW 50062, N'I: no existe el modelo externo EmbeddingsBgeM3.', 1;
PRINT N'OK I: 228 coches y 57 averías con embedding de 1024 dimensiones';
GO

-- J: buscador · devuelve el top pedido, solo coches disponibles, ordenado por distancia y con filtros
CREATE TABLE #ranking (
    posicion INT, distancia DECIMAL(6,4), marca NVARCHAR(50), modelo NVARCHAR(60), segmento NVARCHAR(20),
    anio SMALLINT, kilometros INT, combustible NVARCHAR(15), precio_venta DECIMAL(10,2), descripcion NVARCHAR(1000));

INSERT INTO #ranking
EXEC ia.sp_buscar_coches @consulta = N'aventura por caminos de tierra y fines de semana en el campo',
                         @segmento = N'SUV', @precio_max = 20000, @top = 5;

IF (SELECT COUNT(*) FROM #ranking) <> 5
    THROW 50063, N'J: el buscador no devolvió 5 resultados.', 1;
IF EXISTS (SELECT 1 FROM #ranking WHERE segmento <> N'SUV' OR precio_venta > 20000)
    THROW 50064, N'J: el buscador no respeta los filtros de segmento y precio.', 1;
IF EXISTS (SELECT 1 FROM #ranking AS a JOIN #ranking AS b ON b.posicion = a.posicion + 1 WHERE b.distancia < a.distancia)
    THROW 50065, N'J: el ranking no está ordenado por distancia.', 1;
IF EXISTS (SELECT 1 FROM #ranking AS r
           WHERE NOT EXISTS (SELECT 1 FROM catalogo.vw_catalogo AS c
                             WHERE c.estado = N'Disponible' AND c.descripcion = r.descripcion AND c.precio_venta = r.precio_venta))
    THROW 50066, N'J: el ranking contiene coches no disponibles.', 1;

-- J2: un comercial usa el buscador sin permisos sobre el modelo externo (EXECUTE AS ia_servicio)
TRUNCATE TABLE #ranking;
EXECUTE AS USER = N'comercial_ana';
INSERT INTO #ranking EXEC ia.sp_buscar_coches @consulta = N'coche cómodo para viajes largos por autopista', @top = 3;
REVERT;
IF (SELECT COUNT(*) FROM #ranking) <> 3
    THROW 50067, N'J2: un comercial no puede usar el buscador.', 1;
DROP TABLE #ranking;
PRINT N'OK J: buscador con top, filtros, orden por distancia y uso por un comercial';
GO

-- K: RAG · recuperación, respuesta y caso de control
-- K1: la recuperación limita las averías al modelo; el Jogger no recupera ninguna
DECLARE @v VECTOR(1024) = AI_GENERATE_EMBEDDINGS(N'¿Qué averías suele tener y cuánto cuesta repararlas?' USE MODEL EmbeddingsBgeM3);
IF (SELECT COUNT(*) FROM ia.fn_documentos_rag(@v, N'Peugeot 308 SW', 5) WHERE tipo = N'avería') <> 5
    THROW 50070, N'K1: no se recuperaron 5 averías del Peugeot 308 SW.', 1;
IF EXISTS (SELECT 1 FROM ia.fn_documentos_rag(@v, N'Peugeot 308 SW', 5) AS d
           WHERE d.tipo = N'avería'
             AND NOT EXISTS (SELECT 1 FROM taller.vw_averias_por_modelo AS a
                             WHERE a.marca = N'Peugeot' AND a.modelo = N'308 SW'
                               AND d.documento LIKE CONCAT(N'Avería: ', a.titulo, N'.%')))
    THROW 50071, N'K1: se recuperaron averías que no son del Peugeot 308 SW.', 1;
IF EXISTS (SELECT 1 FROM ia.fn_documentos_rag(@v, N'Dacia Jogger', 5) WHERE tipo = N'avería')
    THROW 50072, N'K1: el Dacia Jogger no debería recuperar averías.', 1;
IF ia.fn_contexto_rag(@v, N'Dacia Jogger', 5) NOT LIKE N'%(ninguna)%'
    THROW 50073, N'K1: el contexto del Jogger debería indicar (ninguna).', 1;
GO

-- K2: un mecánico usa el asesor (EXECUTE AS ia_servicio) y recibe una respuesta con texto
DECLARE @respuesta NVARCHAR(MAX);
EXECUTE AS USER = N'mecanico_demo';
EXEC ia.sp_asesor_averias @pregunta = N'¿Qué averías suele tener y cuánto cuesta repararlas?',
                          @modelo = N'Peugeot 308 SW', @respuesta = @respuesta OUTPUT;
REVERT;
IF NULLIF(LTRIM(@respuesta), N'') IS NULL
    THROW 50074, N'K2: el asesor no devolvió respuesta.', 1;
GO

-- K3: caso de control · criterio: la respuesta del Jogger no cita ningún título de avería de la
--     base de datos y dice que no hay datos («no» + «datos», «información» o «registr»)
DECLARE @respuesta NVARCHAR(MAX);
EXEC ia.sp_asesor_averias @pregunta = N'¿Qué averías suele tener y cuánto cuesta repararlas?',
                          @modelo = N'Dacia Jogger', @respuesta = @respuesta OUTPUT;
IF EXISTS (SELECT 1 FROM taller.Averias WHERE @respuesta LIKE CONCAT(N'%', titulo, N'%'))
    THROW 50075, N'K3: el caso de control cita averías que no están en su contexto.', 1;
IF NOT (@respuesta LIKE N'%no %' AND (@respuesta LIKE N'%datos%' OR @respuesta LIKE N'%información%' OR @respuesta LIKE N'%registr%'))
    THROW 50076, N'K3: el caso de control no indica que no hay datos.', 1;
PRINT CONCAT(N'Respuesta del caso de control: ', @respuesta);
PRINT N'OK K: RAG con recuperación por modelo, uso por un mecánico y caso de control sin inventar';
GO
