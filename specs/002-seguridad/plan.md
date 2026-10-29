# Implementation Plan: Seguridad por perfiles

**Branch**: `002-seguridad` | **Date**: 2026-10-29 | **Spec**: [spec.md](spec.md)

**Input**: spec y bloque «Entrada para plan» de `docs/prompts/002-seguridad.md`.

## Summary

`database/06_security.sql` idempotente con roles, usuarios WITHOUT LOGIN, GRANT/DENY sobre vistas
y procedimientos, Row-Level Security sobre Clientes y Reservas y Dynamic Data Masking en email y
teléfono. `tests/demo_seguridad.sql` lo demuestra con `EXECUTE AS USER`; `tests/tests.sql` añade el
bloque G.

## Technical Context

**Language/Version**: T-SQL (SQL Server 2025)

**Testing**: bloque G de `tests/tests.sql` + `tests/demo_seguridad.sql` (evidencia)

**Constraints**: sin contraseñas; script re-ejecutable; los objetos de `seg` con SCHEMABINDING

## Diseño

| Rol | Permisos |
| --- | --- |
| `rol_admin` | `CONTROL` sobre la base y `UNMASK`; el predicado RLS lo deja pasar |
| `rol_comercial` | `SELECT` en `vw_catalogo`, `vw_averias_por_modelo`, `vw_reservas`, `fn_averias_modelo`; `EXECUTE` en `fn_coste_esperado`, `sp_registrar_reserva`, `sp_registrar_venta`; `SELECT/INSERT/UPDATE` en `ventas.Clientes` (filtrado por RLS); `EXECUTE ON SCHEMA::ia` |
| `rol_mecanico` | `SELECT` en `vw_catalogo`, `vw_averias_por_modelo`, `fn_averias_modelo`; `EXECUTE` en `fn_coste_esperado`; `DENY SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::ventas`; `EXECUTE ON SCHEMA::ia` |
| `rol_ia_servicio` | `SELECT` en `vw_catalogo` y `vw_averias_por_modelo`; `DENY` sobre el esquema `ventas` y sobre `INSERT/UPDATE/DELETE` en `catalogo` y `taller`. Los permisos del modelo externo y del endpoint se conceden en `ai/create_external_model.sql` |

- Usuarios: `admin_demo`, `comercial_ana`, `comercial_luis`, `comercial_marta`,
  `comercial_javier`, `mecanico_demo`, `ia_servicio`.
- RLS: `seg.fn_predicado_comercial(@comercial_id)` (en línea, SCHEMABINDING) compara
  `ventas.Comerciales.usuario_bd` con `USER_NAME()` y deja pasar a `rol_admin` y `db_owner`.
  `seg.politica_comerciales` con FILTER y BLOCK (AFTER INSERT, AFTER UPDATE) sobre Clientes y
  Reservas.
- DDM: `email()` en `email`; `partial(0,"XXX-XXX-",3)` en `telefono`.
- Los procedimientos, vistas y el trigger son de `dbo`: el encadenamiento de propiedad permite que
  el comercial reserve sin permisos sobre las tablas, y RLS sigue filtrando sus clientes.

## Constitution Check

VI (mínimo privilegio, RLS, DDM) y II (sin contraseñas) se cumplen; V (cabecera, bloques, códigos
502xx en la demo/tests). Sin violaciones.

## Project Structure

```text
database/06_security.sql      # nuevo
tests/demo_seguridad.sql      # nuevo
tests/tests.sql               # + bloque G
docs/evidencias/002-seguridad.txt
```
