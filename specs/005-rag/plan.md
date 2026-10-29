# Implementation Plan: Asesor de averías con RAG

**Branch**: `005-rag` | **Date**: 2026-10-29 | **Spec**: [spec.md](spec.md)

## Summary

Recuperación y construcción del contexto en T-SQL con funciones compartidas por las dos vías:

- `ia.fn_documentos_rag(@vector, @modelo, @top)`: averías más cercanas (limitadas al modelo vía
  `taller.ModeloAveria` si se indica) y hasta 3 coches disponibles similares, como líneas de texto.
- `ia.fn_contexto_rag(...)`: agrupa los documentos en el texto de contexto.
- `ia.fn_prompt_sistema()`: prompt restrictivo único.
- `ia.sp_contexto_averias_vector(@vector, @modelo, @top, @pregunta)`: vía terminal; devuelve los
  documentos, el prompt y el mensaje que hay que enviar.
- `ia.sp_asesor_averias(@pregunta, @modelo, @top, @respuesta OUTPUT)`: vía SSMS con
  `EXECUTE AS 'ia_servicio'`. Genera el embedding, recupera, construye el contexto y llama a
  `/api/chat` con `sp_invoke_external_rest_endpoint` (qwen2.5:3b, `stream` false, temperatura 0).
  Devuelve 4 conjuntos de resultados: pregunta, documentos, contexto y respuesta.
- `ai/asesor_averias.ps1`: misma recuperación (vector de Ollama), mismo contexto y prompt, y chat
  directo a Ollama.

## Technical Context

**Language/Version**: T-SQL (SQL Server 2025), PowerShell 5.1

**Research**: ruta JSON de la respuesta `$.result.message.content`, ya validada en
`tests/test_conexion_ia.sql` (bloque E). Se lee con `OPENJSON ... WITH (content NVARCHAR(MAX))`
porque `JSON_VALUE` corta a 4000 caracteres. `sp_invoke_external_rest_endpoint` necesita
`EXECUTE ANY EXTERNAL ENDPOINT`, concedido a `rol_ia_servicio` en 004.

**Errores**: 50306 modelo inexistente, 50307 HTTP distinto de 2xx, 50308 fallo de la llamada o
respuesta sin texto.

**Testing**: bloque K de `tests/tests_ia.sql`: documentos para un modelo con averías, ninguna
avería para el Jogger, respuesta no vacía y criterio del caso de control. La comprobación de los 4
conjuntos de resultados se hace en el script de evidencias (PowerShell cuenta las tablas del
DataSet), porque T-SQL no puede capturar varios conjuntos con `INSERT ... EXEC`.

## Constitution Check

VII (prompt restrictivo, temperatura 0, caso de control, dos vías con la misma recuperación) y VI
(EXECUTE AS). Sin violaciones.

## Project Structure

```text
ai/rag.sql
ai/asesor_averias.ps1
tests/tests_ia.sql            # + bloque K
docs/evidencias/005-rag.txt
```
