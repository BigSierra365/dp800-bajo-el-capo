# Tasks: Asesor de averías con RAG

**Input**: Design documents from `specs/005-rag/`

## Phase 1: Foundational

- [X] T001 `ai/rag.sql`: `ia.fn_documentos_rag`, `ia.fn_contexto_rag` e `ia.fn_prompt_sistema`

## Phase 2: User Story 1, 2 y 3 - Vía SSMS (P1)

- [X] T002 [US1] [US2] `ia.sp_asesor_averias` con 4 conjuntos de resultados, EXECUTE AS y THROW 503xx
- [X] T003 [US3] Caso de control: el Jogger pasa por el LLM con el contexto sin averías

## Phase 3: User Story 4 - Vía terminal (P2)

- [X] T004 [US4] `ia.sp_contexto_averias_vector` y `ai/asesor_averias.ps1`

## Phase 4: Tests y evidencias

- [X] T005 Bloque K en `tests/tests_ia.sql`
- [X] T006 `run_all.ps1 -ConIA` desde cero en verde
- [X] T007 Dos preguntas y el caso de control por las dos vías en `docs/evidencias/005-rag.txt`
- [X] T008 Decisiones (pruebas del prompt), bloque B y estado; commit
