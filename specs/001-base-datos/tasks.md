# Tasks: Base de datos del concesionario

**Input**: Design documents from `specs/001-base-datos/`

**Prerequisites**: plan.md, spec.md, research.md

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

- [X] T001 Crear `run_all.ps1` en la raíz con `-Servidor`, `-ConIA` y `-Salida`, orden explícito de scripts, omisión de vacíos y parada en el primer error
- [X] T002 [P] Crear `docs/decisiones.md`, `docs/bloque-b.md` y `docs/estado.md`

## Phase 2: Foundational

- [X] T003 Ejecutar `01` y `02` (validados) desde `run_all.ps1`
- [X] T004 Ejecutar `database/03_insert_data.sql`; si falla, corrección mínima y caso en `docs/bloque-b.md`

## Phase 3: User Story 1 y 2 - Catálogo y averías (P1)

- [X] T005 [US1] [US2] Revisar `database/04_views.sql` contra `02` y ejecutarlo
- [X] T006 [US2] Revisar las funciones de `database/05_procedures.sql` (fn_coste_esperado, fn_averias_modelo)

## Phase 4: User Story 3 y 4 - Reserva y venta (P1/P2)

- [X] T007 [US3] [US4] Revisar procedimientos y trigger de `database/05_procedures.sql` y ejecutarlo

## Phase 5: User Story 5 y 6 - Consultas avanzadas (P2)

- [X] T008 [US5] [US6] Revisar y ejecutar `database/08_advanced_queries.sql`

## Phase 6: User Story 7 - Tests automáticos (P1)

- [X] T009 [US7] Reescribir `tests/tests.sql`: A (9 tablas), B (tablas por esquema), C (recuentos), D (coherencia), E (vistas/funciones y Jogger sin averías), F (flujo reserva, doble reserva 50102, venta y limpieza)
- [X] T010 [US7] Ejecutar `run_all.ps1` desde cero hasta que todo pase

## Phase 7: Polish

- [X] T011 Guardar `docs/evidencias/001-base-datos.txt` (run_all + 08) y `docs/evidencias/000-conexion-ia.txt`
- [X] T012 Actualizar `docs/decisiones.md`, `docs/bloque-b.md` (caso 1) y `docs/estado.md`; commit

## Dependencies & Execution Order

T001 → T003 → T004 → T005–T008 → T009 → T010 → T011 → T012. T002 en paralelo.
