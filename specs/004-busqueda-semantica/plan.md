# Implementation Plan: Buscador semántico de coches

**Branch**: `004-busqueda-semantica` | **Date**: 2026-10-29 | **Spec**: [spec.md](spec.md)

## Summary

Modelo externo `EmbeddingsBgeM3` (Ollama vía Caddy). `ia.sp_generar_embeddings` rellena los vectores
de coches y averías por lotes. Una función de tabla `ia.fn_ranking_coches` concentra el ranking y la
usan `ia.sp_buscar_coches` (vía SSMS: genera el vector dentro de SQL Server) e
`ia.sp_buscar_coches_vector` (vía terminal: recibe el vector de `ai/buscar_coches.ps1`).

## Technical Context

**Language/Version**: T-SQL (SQL Server 2025), PowerShell 5.1

**Primary Dependencies**: Ollama (bge-m3, 1024 dim.) en `http://localhost:11434`; Caddy en
`https://localhost:11435` (SQL Server solo llama por HTTPS)

**Testing**: `tests/tests_ia.sql` (solo con `run_all.ps1 -ConIA`)

## Research (sintaxis verificada en Microsoft Learn, 2026-10-29)

- `CREATE EXTERNAL MODEL ... WITH (LOCATION = 'https://localhost:11435/api/embed', API_FORMAT =
  'Ollama', MODEL_TYPE = EMBEDDINGS, MODEL = 'bge-m3')`. Solo HTTPS con TLS.
- Usar el modelo: `GRANT EXECUTE ON EXTERNAL MODEL::<nombre> TO <principal>`.
- `AI_GENERATE_EMBEDDINGS(source USE MODEL model)`; requiere `external rest endpoint enabled`.
- `sp_invoke_external_rest_endpoint` requiere `EXECUTE ANY EXTERNAL ENDPOINT`; devuelve 0 si HTTP 2xx
  y la respuesta va dentro de `$.result`.
- Métrica: `VECTOR_DISTANCE('cosine', ...)`, de 0 (mismo significado) a 2 (opuesto). Compara la
  dirección de los vectores y no su longitud. bge-m3 está entrenado para similitud coseno.
- Búsqueda exacta (sin índice vectorial): 228 vectores; `VECTOR_SEARCH` y el índice DiskANN están
  en vista previa.

## Diseño

- Texto del vector: coches = marca + modelo + segmento + combustible + descripción; averías =
  título + síntoma + causa + solución.
- `ia.fn_ranking_coches(@vector VECTOR(1024), @precio_max, @segmento, @top)`: solo `Disponible`,
  filtros opcionales, `ROW_NUMBER()` por distancia (desempate por `vehiculo_id`).
- `ia.sp_buscar_coches` con `EXECUTE AS 'ia_servicio'`: comerciales y mecánicos lo ejecutan sin
  permisos sobre el modelo. `rol_ia_servicio` recibe `EXECUTE` sobre el modelo y
  `EXECUTE ANY EXTERNAL ENDPOINT`.
- `DENY EXECUTE ON ia.sp_generar_embeddings` a comercial y mecánico (decisión D09).
- Errores de IA: `THROW 50301`–`50305`.
- `ai/comun.ps1`: funciones compartidas por los dos scripts de terminal (embedding con Ollama y
  llamada parametrizada a SQL Server).

## Constitution Check

VII (bge-m3, coseno, dos vías con el mismo ranking), II (todo en `localhost`), IV (evidencia real).
Sin violaciones.

## Project Structure

```text
ai/create_external_model.sql
ai/generate_embeddings.sql
ai/vector_search.sql
ai/comun.ps1
ai/buscar_coches.ps1
tests/tests_ia.sql
docs/evidencias/004-busqueda.txt
```
