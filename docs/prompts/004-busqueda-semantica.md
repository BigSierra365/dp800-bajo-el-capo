# 004 · Embeddings y búsqueda semántica (bloques E y F)

## Entrada para specify

```text
Buscador semántico de coches en lenguaje natural.

Historias de usuario:
1. Como comercial, escribo una frase como «familiar, económico y fiable para ciudad y escapadas» y obtengo un ranking de coches disponibles parecidos en significado, aunque la descripción no contenga esas palabras.
2. Como comercial, puedo limitar el resultado por precio máximo, segmento y número de resultados.
3. Como alumno, quiero hacer la misma búsqueda de dos formas: desde SSMS con T-SQL y desde la terminal con un script que usa el modelo de Ollama.
4. Como alumno, quiero demostrar la diferencia con la búsqueda por palabras clave.

Criterios de aceptación:
- Todos los vehículos y averías de prueba tienen un embedding de 1024 dimensiones.
- Queda explicado qué modelo se usa (bge-m3), qué columnas forman el texto del embedding, la dimensión, cómo se generan y cómo se guardan.
- El ranking muestra posición, distancia coseno, marca, modelo, precio y descripción, solo de coches disponibles.
- Al menos tres frases de prueba dan resultados coherentes. Para la misma frase, la vía SSMS y la vía terminal devuelven el mismo top.
- La métrica de similitud (distancia coseno) queda justificada.
- Si Ollama o Caddy no están disponibles, el error es claro y la base no queda en mal estado.
```

## Entrada para plan

```text
Requisito previo (sin crear archivos): comprueba con comandos de solo lectura que Ollama responde en http://localhost:11434 con los modelos bge-m3 y qwen2.5:3b, y que https://localhost:11435 (Caddy) responde con un certificado de confianza para SQL Server. Si algo falla, diagnostica, escribe en docs/estado.md los pasos exactos que debe hacer el alumno y detente.

- ai/create_external_model.sql: activa 'external rest endpoint enabled' (sp_configure y RECONFIGURE); crea el modelo externo de embeddings para bge-m3 (API_FORMAT Ollama, MODEL_TYPE EMBEDDINGS, LOCATION https://localhost:11435/api/embed); idempotente; concede a rol_ia_servicio los permisos necesarios. Verifica la sintaxis exacta en Microsoft Learn.
- ai/generate_embeddings.sql: procedimiento ia.sp_generar_embeddings que rellena embedding donde sea NULL. Vehículos: marca, modelo, segmento, combustible y descripción. Averías: título, síntoma, causa y solución. Usa AI_GENERATE_EMBEDDINGS con el modelo externo, por lotes, e informa de las filas procesadas. Al final del script, EXEC del procedimiento.
- ai/vector_search.sql: una única lógica de ranking (por ejemplo, la función de tabla ia.fn_ranking_coches(@vector, @precio_max, @segmento, @top)) usada por dos procedimientos:
  - ia.sp_buscar_coches (@consulta NVARCHAR(4000), @precio_max, @segmento, @top = 5): genera el embedding de la consulta dentro de SQL Server (vía SSMS).
  - ia.sp_buscar_coches_vector (@vector NVARCHAR(MAX) con el array JSON de 1024 valores): para la vía terminal.
  Al final, ejemplos de llamada con tres frases.
- ai/buscar_coches.ps1: parámetros -Consulta, -PrecioMax, -Segmento, -Top y -Servidor (localhost por defecto). Pide el embedding a Ollama (POST http://localhost:11434/api/embed con el modelo bge-m3), llama a ia.sp_buscar_coches_vector pasando el vector como parámetro de la consulta (no en la línea de comandos, por su longitud) y muestra el ranking en una tabla. Sin rutas absolutas.
- tests/tests_ia.sql (nuevo): sin embeddings NULL, dimensión 1024 e ia.sp_buscar_coches devuelve filas. Solo se ejecuta con run_all.ps1 -ConIA.
- Evidencias: docs/evidencias/004-busqueda.txt con las tres frases por las dos vías y el contraste con la búsqueda por palabras clave de 08_advanced_queries.sql (bloque E2).
```

## Criterio de cierre

- `run_all.ps1 -ConIA` termina sin errores.
- Las tres frases dan el mismo top por SSMS y por terminal, y está guardado en `docs/evidencias/004-busqueda.txt`.
