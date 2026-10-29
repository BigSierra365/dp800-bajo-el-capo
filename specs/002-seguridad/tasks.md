# Tasks: Seguridad por perfiles

**Input**: Design documents from `specs/002-seguridad/`

## Phase 1: Foundational

- [X] T001 Limpieza idempotente en `database/06_security.sql` (política, predicado, máscaras, usuarios, roles)
- [X] T002 Roles y usuarios WITHOUT LOGIN con su pertenencia

## Phase 2: User Story 3 - Mínimo privilegio (P1)

- [X] T003 [US3] GRANT/DENY por rol según el plan

## Phase 3: User Story 1 - RLS (P1)

- [X] T004 [US1] Función de predicado `seg.fn_predicado_comercial` y política `seg.politica_comerciales`

## Phase 4: User Story 2 - DDM (P1)

- [X] T005 [US2] Máscaras en email y teléfono; UNMASK a `rol_admin`

## Phase 5: User Story 4 - Demo y tests (P2)

- [X] T006 [US4] `tests/demo_seguridad.sql` con EXECUTE AS / REVERT y TRY/CATCH
- [X] T007 [US4] Bloque G en `tests/tests.sql` (roles, política activa, columnas enmascaradas, filtrado real)
- [X] T008 Ejecutar `run_all.ps1` desde cero, ejecutar `06` dos veces y la demo; guardar `docs/evidencias/002-seguridad.txt`
- [X] T009 Actualizar decisiones, bloque B y estado; commit
