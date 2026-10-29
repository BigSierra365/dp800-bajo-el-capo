# Bloque B · Desarrollo SQL asistido por IA

Herramientas: Claude (chat) para los datos de prueba y Claude Code con GitHub Spec Kit para el
resto del proyecto (specs, planes y tareas en `specs/`). Para cada caso se documenta la entrada,
lo que generó la IA, lo que se aceptó, lo que se corrigió y cómo se verificó.

---

## Caso 1 · Datos de prueba (`database/03_insert_data.sql`)

- **Herramienta**: Claude (chat), antes de empezar con Claude Code.
- **Entrada**: petición de un script de datos de prueba para las 9 tablas de
  `02_create_tables.sql`, con un concesionario grande (8 marcas, 24 modelos, más de 200 coches,
  57 averías…), descripciones comerciales naturales que no repitan las palabras de las búsquedas
  de prueba, equipamiento en JSON con «isofix» en algunos coches, teléfonos con formatos a
  normalizar, un modelo sin averías (Dacia Jogger) y claves foráneas resueltas por nombre.
- **Qué generó**: un script de 897 líneas en un solo lote y una transacción, con protección
  (`THROW 50090` si ya hay datos), FK resueltas con JOIN por clave natural y un bloque K que fija el
  estado de los coches según sus reservas (porque el trigger se crea después, en `05`).
- **Qué se aceptó**: todo el script, sin cambios.
- **Qué se corrigió**: nada en el script. Sí hubo que corregir la forma de ejecutarlo: sqlcmd con
  `QUOTED_IDENTIFIER OFF` hacía fallar `02` (error 1934 por el índice filtrado), y se añadió `-I`
  en `run_all.ps1` (ver caso 3).
- **Cómo se verificó**: `tests/tests.sql` bloque C (los 9 recuentos exactos: 8, 24, 228, 57, 207,
  4, 24, 44 y 16) y bloque D (estado de cada coche coherente con sus reservas, una reserva activa
  por coche, precio final ≤ precio de venta, comercial de la reserva = comercial del cliente).
  Evidencia: `docs/evidencias/001-base-datos.txt`.

---

## Caso 2 · Ficha JSON de un coche (`database/08_advanced_queries.sql`, bloque D2)

- **Herramienta**: Claude (chat) generó `08`; Claude Code lo revisó y ejecutó en la feature 001.
- **Entrada**: «consultas avanzadas, una por técnica, ligadas a una pregunta de negocio: CTE,
  window functions, correlacionada, JSON y expresiones regulares» (spec de 001, historia 6).
- **Qué generó**: `JSON_OBJECT` con un campo `averias_top` calculado con una subconsulta
  `JSON_ARRAYAGG(f.titulo ORDER BY f.riesgo DESC)`.
- **Qué se aceptó**: el resto de las consultas (A, B, C, D1, E1, E2), que se ejecutaron sin error y
  con resultados con sentido.
- **Qué se corrigió**: el campo `averias_top` salía como **texto escapado**
  (`"averias_top":"[\"Embrague…`) en lugar de como array. Primer intento: `JSON_QUERY(...)`, que
  funciona sin `ORDER BY` pero no con él (seguía escapado). Solución: `CAST((subconsulta) AS JSON)`.
- **Cómo se verificó**: ejecución real; la salida pasa a ser `"averias_top":["Embrague de la caja
  DSG7 con tirones", …]` (ver `docs/evidencias/001-base-datos.txt`).

---

## Caso 3 · Script de reproducción (`run_all.ps1`)

- **Herramienta**: Claude Code (implement de la feature 001).
- **Entrada**: bloque «Entrada para plan» de `docs/prompts/001-base-datos.md` (parámetros
  `-Servidor` y `-ConIA`, orden de scripts, omitir vacíos, parar en el primer error).
- **Qué generó**: el script con `sqlcmd -S $Servidor -E -C -b -f 65001 -i`.
- **Qué se aceptó**: estructura, orden y parada en el primer error.
- **Qué se corrigió** (tres fallos detectados al ejecutarlo):
  1. `02` fallaba con el error 1934 (`QUOTED_IDENTIFIER`): sqlcmd lo desactiva por defecto → `-I`.
  2. Los scripts vacíos no se omitían: `Get-Content -Raw` devuelve `$null` en un archivo vacío y
     `$null -match '^\s*$'` no es verdadero → `[string]::IsNullOrWhiteSpace(...)`.
  3. Los mensajes de error incluían el nombre del equipo → se sustituye por `<equipo>` antes de
     escribir (no debe llegar a las evidencias).
- **Cómo se verificó**: `.\run_all.ps1` desde cero termina con «RESULTADO: todos los scripts y
  tests terminaron sin errores»; `06` y `07` aparecen como «vacío, se omite»; `grep` del nombre del
  equipo en `docs/evidencias/` sin resultados.

---

## Caso 4 · Seguridad (`database/06_security.sql` y `tests/demo_seguridad.sql`)

- **Herramienta**: Claude Code (implement de la feature 002).
- **Entrada**: bloque «Entrada para plan» de `docs/prompts/002-seguridad.md` (script idempotente,
  4 roles, usuarios WITHOUT LOGIN, RLS con FILTER y BLOCK, DDM, demo con EXECUTE AS).
- **Qué generó**: el script de seguridad, la demo y el bloque G de tests.
- **Qué se aceptó**: roles, permisos, función de predicado, política, máscaras y bloque G.
- **Qué se corrigió**:
  1. La limpieza de máscaras fallaba con el error 16007 («la columna no tiene una función de
     máscara») aunque estuviera dentro de un `IF`: `sys.masked_columns` lista todas las columnas
     (hay que filtrar `is_masked = 1`) y, además, `ALTER COLUMN ... DROP MASKED` se valida al
     compilar el lote. Se cambió a SQL dinámico generado desde `sys.masked_columns`.
  2. En la demo, el intento de reserva rechazado estaba dentro de la transacción de la demo; el
     `CATCH` de `sp_registrar_reserva` hace `ROLLBACK` y deshizo también la transacción externa,
     así que la reserva válida posterior se **comitió** de verdad. Se borró esa reserva y se movió
     el intento rechazado fuera de la transacción.
- **Cómo se verificó**: `06` ejecutado dos veces seguidas con código 0; demo con filas distintas por
  comercial (7/8/15/14), email y teléfono enmascarados, errores 229 para mecánico, comercial e IA, y
  el error 50103 al reservar para un cliente ajeno; tras la demo siguen existiendo 44 reservas;
  bloque G de `tests/tests.sql` en verde. Evidencia: `docs/evidencias/002-seguridad.txt`.

---

## Caso 5 · Buscador semántico (`ai/`, `tests/tests_ia.sql`)

- **Herramienta**: Claude Code (implement de la feature 004).
- **Entrada**: bloque «Entrada para plan» de `docs/prompts/004-busqueda-semantica.md`.
- **Qué generó**: el modelo externo, `ia.sp_generar_embeddings`, la función `ia.fn_ranking_coches`,
  los dos procedimientos de búsqueda, `ai/comun.ps1`, `ai/buscar_coches.ps1` y `tests/tests_ia.sql`.
- **Qué se aceptó**: todo el T-SQL de `ai/`, que funcionó al primer intento (incluido
  `EXECUTE AS 'ia_servicio'` con `AI_GENERATE_EMBEDDINGS`).
- **Qué se corrigió**:
  1. `tests/tests_ia.sql` no compilaba (error 113, «falta la marca de fin de comentario»): la
     cabecera decía `ai/*.sql`, y ese `/*` abre un comentario anidado dentro del bloque de la
     cabecera. Se reescribió como «scripts de ai/».
  2. El script que generaba la evidencia estaba en UTF-8 sin BOM. PowerShell 5.1 lo leyó como ANSI
     y envió las frases a Ollama como «econÃ³mico»: el top salía distinto. Se descartó esa
     evidencia, se guardó el script con BOM y se regeneró (decisión D18).
- **Cómo se verificó**: `run_all.ps1 -ConIA` desde cero en verde (bloques I y J). Para las tres
  frases, una comparación automática de posición, marca, modelo, precio y distancia entre la vía
  SSMS y la vía terminal da «MISMO TOP en las dos vías». Evidencia: `docs/evidencias/004-busqueda.txt`.
