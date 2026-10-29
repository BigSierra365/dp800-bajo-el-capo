# Implementation Plan: Base de datos del concesionario

**Branch**: `001-base-datos` | **Date**: 2026-10-29 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-base-datos/spec.md` y bloque «Entrada para plan»
de `docs/prompts/001-base-datos.md`.

## Summary

Revisar y ejecutar los scripts ya escritos (`03`, `04`, `05`, `08`), crear `run_all.ps1` (recrea la
base y ejecuta los tests, con `-ConIA` para la parte de IA) y reescribir `tests/tests.sql` con
bloques A–F que fallan con `THROW 500xx`.

## Technical Context

**Language/Version**: T-SQL (SQL Server 2025, nivel 170) y PowerShell 5.1

**Primary Dependencies**: sqlcmd (autenticación de Windows, `-C` por el certificado local)

**Storage**: `BajoElCapoDB` (collation `Modern_Spanish_CI_AS`), esquemas catalogo, taller, ventas, ia, seg

**Testing**: `tests/tests.sql` ejecutado por `run_all.ps1`; cada fallo lanza `THROW 500xx`

**Target Platform**: Windows 11 local

**Project Type**: scripts de base de datos

**Performance Goals**: no aplica en esta feature (ver 003)

**Constraints**: sin rutas absolutas ni secretos; `01`/`02` intocables; `03` no se regenera

**Scale/Scope**: 9 tablas, 228 vehículos, 3 vistas, 2 funciones, 2 procedimientos, 1 trigger

## Constitution Check

| Principio | Cumplimiento |
| --- | --- |
| I. Enunciado primero | Bloque A completo: tablas, constraints, índices, datos, objetos y consultas avanzadas |
| II. Local y sin secretos | sqlcmd `-E` contra `localhost`; rutas con `$PSScriptRoot` |
| III. Reproducible | `run_all.ps1` recrea desde `01` y se para en el primer error |
| IV. Demostrar | `docs/evidencias/001-base-datos.txt` con salida real |
| V. Calidad T-SQL | Cabeceras, bloques A, B, C…, `THROW 500xx`, sin `SELECT *` |
| VI–VII | Fuera de alcance (002, 004, 005) |
| VIII. Pequeño | Solo lo pedido |
| IX. Trazabilidad | spec, plan, tasks, `decisiones.md`, `bloque-b.md` (caso 1) |

Sin violaciones.

## Project Structure

### Documentation (this feature)

```text
specs/001-base-datos/
├── spec.md
├── plan.md
├── research.md
├── tasks.md
└── checklists/requirements.md
```

### Source Code (repository root)

```text
run_all.ps1                     # nuevo
database/01..05, 08             # existentes (revisar y ejecutar)
database/06, 07                 # vacíos: run_all.ps1 los omite
tests/tests.sql                 # reescrito (bloques A–F)
tests/test_conexion_ia.sql      # existente (solo con -ConIA)
docs/evidencias/001-base-datos.txt
docs/decisiones.md, docs/bloque-b.md, docs/estado.md
```

**Structure Decision**: estructura de la propuesta (apartado 11); el modelo de datos es el de
`database/02_create_tables.sql`, sin cambios, por eso no se genera `data-model.md` aparte.

## Complexity Tracking

Sin violaciones que justificar.
