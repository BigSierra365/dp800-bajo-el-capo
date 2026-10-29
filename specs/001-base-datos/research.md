# Research: Base de datos del concesionario

## Ejecución de scripts

- **Decision**: `sqlcmd -S <servidor> -E -C -b -f 65001 -i <script>`; `01` contra `master`, el
  resto contra `BajoElCapoDB`.
- **Rationale**: `-b` devuelve código de salida distinto de 0 ante un error (permite detener
  `run_all.ps1`); `-f 65001` lee los scripts en UTF-8 y conserva acentos y «ñ»; `-C` confía en el
  certificado autofirmado de la instancia local.
- **Alternatives considered**: `Invoke-Sqlcmd` (requiere el módulo SqlServer, que no está en el
  repositorio ni es obligatorio).

## Scripts vacíos

- **Decision**: `run_all.ps1` omite los archivos vacíos (longitud 0 o solo espacios).
- **Rationale**: lo pide el plan de 001; así el mismo comando sirve en todas las features.

## Tests

- **Decision**: un único `tests/tests.sql` con bloques etiquetados y `THROW 500xx` por fallo; el
  flujo de reserva/venta se ejecuta y se deshace borrando sus filas al final.
- **Rationale**: sin dependencias externas (tSQLt queda como mejora futura).
- **Alternatives considered**: transacción con ROLLBACK para el flujo (descartado: el procedimiento
  hace su propio COMMIT y el error 50102 con `XACT_ABORT` aborta la transacción externa).

## Orden respecto al trigger

- **Decision**: se mantiene el orden `03` antes de `05`; `03` fija el estado de los coches en su
  bloque K.
- **Rationale**: así está escrito y documentado en `03`; el trigger de `05` mantiene el estado en
  adelante.
