# Tasks: Buscador semántico de coches

**Input**: Design documents from `specs/004-busqueda-semantica/`

## Phase 1: Foundational

- [X] T001 Comprobar Ollama (`:11434`) y Caddy (`:11435`) con GET a `/api/tags`
- [X] T002 `ai/create_external_model.sql`: endpoint REST, modelo `EmbeddingsBgeM3` idempotente y permisos de `rol_ia_servicio`
- [X] T003 `ai/generate_embeddings.sql`: `ia.sp_generar_embeddings` por lotes, DENY a comercial y mecánico, EXEC final

## Phase 2: User Story 1 y 2 - Ranking con filtros (P1/P2)

- [X] T004 [US1] [US2] `ai/vector_search.sql`: `ia.fn_ranking_coches`, `ia.sp_buscar_coches` y `ia.sp_buscar_coches_vector`, más 3 frases de ejemplo

## Phase 3: User Story 3 - Vía terminal (P1)

- [X] T005 [US3] `ai/comun.ps1` y `ai/buscar_coches.ps1`

## Phase 4: Tests y evidencias

- [X] T006 `tests/tests_ia.sql`: sin vectores NULL, 1024 dimensiones, el buscador devuelve filas solo disponibles
- [X] T007 `run_all.ps1 -ConIA` desde cero en verde
- [X] T008 [US3] [US4] Tres frases por las dos vías y contraste con 08 E2 en `docs/evidencias/004-busqueda.txt`
- [X] T009 Actualizar decisiones, bloque B y estado; commit
