# Decisiones técnicas

Decisiones tomadas durante el desarrollo, con su motivo. Cuando el enunciado y la propuesta no
coinciden, manda el enunciado.

| # | Fase | Decisión | Motivo |
| --- | --- | --- | --- |
| D01 | General | Modelo de respuestas **qwen2.5:3b** en lugar de qwen2.5:7b (propuesta). | La propuesta ya contemplaba un modelo de 3B como alternativa más ligera. El enunciado solo exige un «modelo local». Con prompt restrictivo y temperatura 0 cumple, incluido el caso de control. |
| D02 | Base de datos | Volúmenes de `03_insert_data.sql` (228 coches, 24 clientes, 44 reservas, 16 ventas) en lugar de los rangos de la propuesta (40–60 coches). | El enunciado pide «datos suficientes»; más volumen hace más interesantes la búsqueda y la optimización. |
| D03 | Base de datos | Se mantiene `precio > 0` aunque la propuesta diga «≥ 0». | Es más estricto: un coche a 0 € no tiene sentido. |
| D04 | Base de datos | `run_all.ps1` llama a `sqlcmd` con `-I` (QUOTED_IDENTIFIER ON), `-W` (sin espacios de relleno) y `-f 65001` (UTF-8). | sqlcmd usa QUOTED_IDENTIFIER OFF por defecto y el índice filtrado `ux_reserva_activa` falla con el error 1934; `-f 65001` conserva acentos y «ñ»; `-W` hace legible la salida. |
| D05 | Base de datos | `run_all.ps1` sustituye el nombre del equipo por `<equipo>` en todo lo que escribe. | Los mensajes de error de sqlcmd incluyen el nombre de la instancia y no deben llegar a las salidas publicadas. |
| D06 | Seguridad | El `DENY EXECUTE` sobre `ia.sp_generar_embeddings` se emite en `ai/generate_embeddings.sql`, justo después de crear el procedimiento. `06` concede `EXECUTE ON SCHEMA::ia` a comercial y mecánico. | No se puede denegar un objeto que aún no existe. El permiso de esquema cubre los procedimientos de IA que se crean después. |
| D07 | Seguridad | La demostración de «filas distintas» usa las reservas (7, 8, 15 y 14) y no los clientes. | Los cuatro comerciales tienen 6 clientes cada uno: con clientes no se vería un número distinto. |
| D08 | Seguridad | El mecánico puede consultar `catalogo.vw_catalogo`. | Necesita ver modelos; la vista no expone el precio de compra ni datos de clientes. |
| D09 | Optimización | La consulta medida es la **primera página** del listado (`TOP (50)` ordenado por precio). | Es lo que ve un comercial. El índice se razona igual: igualdad en `estado`, rango y orden en `precio_venta`. |
| D10 | Optimización | Los planes reales se capturan con `tests/medir_optimizacion.ps1`. | Así cualquiera puede repetir la medición. Activa `STATISTICS XML` solo en las consultas medidas, para que `run_all.ps1` no imprima XML. |
| D11 | Optimización | Se documenta que las lecturas de Modelos y Marcas suben con el índice (bucle anidado). | El enunciado pide explicar por qué mejora «o no». El total baja de 2.988 a 523 lecturas lógicas. |
| D12 | Búsqueda | `ia.sp_buscar_coches` se ejecuta `WITH EXECUTE AS 'ia_servicio'`. `rol_ia_servicio` tiene `EXECUTE ON EXTERNAL MODEL::EmbeddingsBgeM3` y `EXECUTE ANY EXTERNAL ENDPOINT`. | Comerciales y mecánicos usan la IA sin permisos sobre el modelo (lo comprueba el test J). |
| D13 | Búsqueda | El modelo externo lleva `PARAMETERS = '{"sql_rest_options":{"retry_count":2}}'`. | Ollama tarda en cargar el modelo la primera vez; el reintento evita fallos en esa primera llamada. |
| D14 | Búsqueda | Las funciones de la vía terminal están en `ai/comun.ps1` y los dos scripts lo cargan. | No duplicar código entre buscador y asesor. El ranking sigue estando solo en T-SQL. |
| D15 | Búsqueda | Los `.ps1` se guardan en UTF-8 **con BOM**. | Windows PowerShell 5.1 lee como ANSI los archivos sin BOM y estropea los acentos de las frases. |
| D16 | RAG | El contexto y el prompt de sistema se construyen en T-SQL (`ia.fn_documentos_rag`, `ia.fn_contexto_rag`, `ia.fn_prompt_sistema`). La vía terminal los recibe de `ia.sp_contexto_averias_vector` y solo llama a Ollama. | Garantiza que las dos vías envían exactamente lo mismo al modelo, sin duplicar la lógica de recuperación. |
| D17 | RAG | Prompt final: el restrictivo («Responde solo con el contexto proporcionado. Si no hay datos suficientes, dilo») más tres reglas: citar solo averías y costes del contexto, decir «no hay averías registradas» si la sección es «(ninguna)» y responder en un máximo de cinco frases. | Probado con dos preguntas y el caso de control por las dos vías. Límites observados: algún error gramatical menor y, en la pregunta por síntoma, cita solo una de las averías recuperadas. Ninguno inventa datos. |
| D18 | RAG | Los 4 conjuntos de resultados del asesor se comprueban desde PowerShell, contando las tablas devueltas. `tests_ia.sql` comprueba la recuperación, la respuesta (parámetro `OUTPUT` `@respuesta`) y el caso de control. | T-SQL no puede capturar varios conjuntos de resultados distintos con `INSERT ... EXEC`. |
| D19 | RAG | El JSON del chat se construye con `JSON_OBJECT`, y `"stream": false` se añade con `JSON_MODIFY(..., CAST(0 AS BIT))`. La respuesta se lee con `OPENJSON ... WITH (content NVARCHAR(MAX))`. | `CAST('false' AS JSON)` da el error 13609; `JSON_VALUE` corta a 4000 caracteres. |
| D20 | Documentación | La instalación de Ollama y Caddy se documenta en el README y no se versiona ningún archivo de configuración de esas herramientas. | Cada equipo tiene sus rutas; el README da el Caddyfile mínimo y los pasos, sin rutas personales. |
