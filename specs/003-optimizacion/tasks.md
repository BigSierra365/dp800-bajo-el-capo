# Tasks: Optimización del listado del catálogo

**Input**: Design documents from `specs/003-optimizacion/`

## Phase 1: User Story 1 - Carga, índice y limpieza (P1)

- [X] T001 [US1] Bloque A de `database/07_indexes.sql`: DROP INDEX IF EXISTS y borrado de cargas previas
- [X] T002 [US1] Bloque B: ~50.000 coches con GENERATE_SERIES, matrículas válidas y marcador `[CARGA]`
- [X] T003 [US1] Bloques C y E: consulta ANTES y DESPUÉS (dos ejecuciones cada una) con STATISTICS IO, TIME
- [X] T004 [US1] Bloque D: índice compuesto razonado; bloque F: borrado de la carga

## Phase 2: User Story 2 - Medición y evidencias (P1)

- [X] T005 [US2] `tests/medir_optimizacion.ps1`: lotes de 07 en una conexión, planes reales y mensajes
- [X] T006 [US2] Guardar `.sqlplan` antes/después, `003-optimizacion.txt` y la tabla `003-optimizacion.md`
- [X] T007 Bloque H en `tests/tests.sql`; `run_all.ps1` desde cero en verde
- [X] T008 Actualizar decisiones, bloque B y estado; commit
