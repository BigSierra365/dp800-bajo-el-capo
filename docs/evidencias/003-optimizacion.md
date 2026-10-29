# Evidencia 003 · Optimización del listado del catálogo

Valores obtenidos con `tests/medir_optimizacion.ps1`, que ejecuta `database/07_indexes.sql` lote a
lote. Fuentes: planes reales [`003-plan-antes.sqlplan`](003-plan-antes.sqlplan) y
[`003-plan-despues.sqlplan`](003-plan-despues.sqlplan), y mensajes de `STATISTICS IO, TIME` en
[`003-optimizacion.txt`](003-optimizacion.txt). Se compara la **segunda ejecución** de cada
consulta, con la caché caliente en los dos casos.

## Consulta medida

Primera página del listado: 50 SUV disponibles entre 10.000 y 15.000 €, los más baratos primero,
con marca y modelo. Volumen: 50.228 coches (50.000 de carga + 228 de prueba).

```sql
SELECT TOP (50) v.matricula, ma.nombre AS marca, mo.nombre AS modelo, v.anio, v.kilometros, v.precio_venta
FROM catalogo.Vehiculos AS v
JOIN catalogo.Modelos   AS mo ON mo.modelo_id = v.modelo_id
JOIN catalogo.Marcas    AS ma ON ma.marca_id  = mo.marca_id
WHERE v.estado = N'Disponible' AND mo.segmento = N'SUV' AND v.precio_venta BETWEEN 10000 AND 15000
ORDER BY v.precio_venta;
```

## Mejora aplicada

```sql
CREATE INDEX ix_vehiculos_estado_precio
    ON catalogo.Vehiculos (estado, precio_venta)
    INCLUDE (modelo_id, matricula, anio, kilometros);
```

## Antes y después (valores reales)

| Métrica | Antes | Después |
| --- | --- | --- |
| Acceso a `Vehiculos` | Clustered Index Scan (`pk_vehiculos`) | Index Seek (`ix_vehiculos_estado_precio`) |
| Filas leídas en `Vehiculos` | 50.228 | 209 |
| Otros operadores del plan | Hash Match + Sort (Top N) | Nested Loops + Top |
| Coste estimado del plan | 2,41887 | 0,0518114 |
| Coste del operador sobre `Vehiculos` | 2,25113 | 0,0045817 |
| Lecturas lógicas `Vehiculos` | 2.974 | 5 |
| Lecturas lógicas `Modelos` | 2 | 418 |
| Lecturas lógicas `Marcas` | 12 | 100 |
| Lecturas lógicas totales | 2.988 | 523 |
| Tiempo de CPU | 16 ms | 0 ms |
| Tiempo transcurrido | 11 ms | 1 ms |

## Explicación

- **Antes**, no hay ningún índice que empiece por `estado` o `precio_venta`. SQL Server recorre
  toda la tabla (Clustered Index Scan): lee las 50.228 filas, que son anchas porque llevan la
  descripción, el JSON y la columna del vector. Después cruza el resultado con Modelos (Hash Match)
  y ordena para quedarse con 50 (Sort Top N). El coste se concentra en el recorrido (2,25 de 2,42).
- **Después**, el índice tiene `estado` como primera clave (igualdad) y `precio_venta` como segunda
  (rango y orden). El Index Seek salta directamente a «Disponible, 10.000 €» y lee en orden de
  precio. Como el índice ya está ordenado no hace falta un Sort, y el operador Top para en cuanto
  junta 50 SUV: solo ha leído 209 filas. Las columnas `INCLUDE` cubren la consulta, así que no hay
  *key lookups* a la tabla.
- **El precio del cambio**: el plan pasa a un bucle anidado. Por cada una de las 209 filas busca su
  modelo, y por cada SUV busca su marca. Por eso suben las lecturas de `Modelos` (2 → 418) y de
  `Marcas` (12 → 100). Son páginas pequeñas y ya en memoria, y el total baja de 2.988 a 523
  lecturas lógicas (un 82 % menos).
- **Tiempos**: con 50.000 filas, los tiempos son de milisegundos en los dos casos y dependen del
  equipo. Lo comparable es el plan, las filas leídas y las lecturas lógicas: el trabajo del
  recorrido crece con el tamaño de la tabla, mientras que el Seek + Top se mantiene casi igual.
- **Cuándo no mejoraría**: si el filtro de precio abarcara casi toda la tabla, o si se pidieran
  todas las filas en lugar de una página, el bucle anidado perdería ventaja frente al recorrido. El
  optimizador elige el plan con las estadísticas, que se actualizan en `07` con `FULLSCAN`.

## Capturas pendientes (alumno)

Añadir en `docs/img/` las capturas del plan gráfico de SSMS antes y después. Abre los `.sqlplan`
con SSMS, o ejecuta `07` con «Incluir plan de ejecución real» (Ctrl+M).
