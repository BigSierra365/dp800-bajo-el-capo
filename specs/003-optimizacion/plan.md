# Implementation Plan: Optimización del listado del catálogo

**Branch**: `003-optimizacion` | **Date**: 2026-10-29 | **Spec**: [spec.md](spec.md)

## Summary

`database/07_indexes.sql` carga ~50.000 coches con `GENERATE_SERIES`, mide la consulta del catálogo,
crea `ix_vehiculos_estado_precio` y vuelve a medir; al final borra la carga. Un script de medición
(`tests/medir_optimizacion.ps1`) ejecuta los mismos lotes de `07` en una conexión, activa
`STATISTICS XML` solo en los bloques C y E y guarda los planes `.sqlplan` y los mensajes de
`STATISTICS IO, TIME`.

## Technical Context

**Language/Version**: T-SQL (SQL Server 2025), PowerShell 5.1 con `System.Data.SqlClient`

**Testing**: bloque H de `tests/tests.sql` (índice existe, 228 coches)

**Constraints**: datos de carga marcados con `[CARGA]` en la descripción; matrículas válidas según
el CHECK de `02` y sin colisión con las existentes

## Diseño

- Consulta: coches `Disponible` de segmento `SUV` con precio entre 10.000 y 15.000 €, con marca y
  modelo, ordenados por precio.
- Índice: `catalogo.Vehiculos (estado, precio_venta) INCLUDE (modelo_id, anio, kilometros,
  matricula)`. `estado` va primero (igualdad), `precio_venta` después (rango y orden); las INCLUDE
  cubren el resto de columnas que lee la consulta, así se evitan los *key lookups*. El segmento se
  resuelve en `Modelos` (24 filas) con el JOIN.
- Se ejecuta cada consulta dos veces y se compara la segunda.

## Constitution Check

IV (valores reales en evidencias, nada inventado) y III (re-ejecutable) se cumplen. Sin violaciones.

## Project Structure

```text
database/07_indexes.sql
tests/medir_optimizacion.ps1
tests/tests.sql                         # + bloque H
docs/evidencias/003-plan-antes.sqlplan
docs/evidencias/003-plan-despues.sqlplan
docs/evidencias/003-optimizacion.txt
docs/evidencias/003-optimizacion.md
```
