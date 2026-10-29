# 003 · Optimización (bloque D)

## Entrada para specify

```text
Optimizar la consulta del listado del catálogo: coches de un estado, un segmento y un rango de precio, con su marca y modelo.

Historias de usuario:
1. Como comercial, quiero que el listado filtrado del catálogo responda rápido aunque haya muchos coches.
2. Como alumno, quiero medir la consulta antes y después de una mejora y explicar por qué mejora o no.

Criterios de aceptación:
- La prueba usa un volumen ampliado (unos 50.000 vehículos), suficiente para que el plan de ejecución cambie.
- El estado inicial y el final se miden con el plan de ejecución real, el tipo de acceso (scan o seek), el coste, las lecturas lógicas y el tiempo.
- La mejora es un índice compuesto o filtrado, justificado por los filtros de la consulta.
- Hay una tabla comparativa antes y después con valores reales y una explicación.
- Al terminar, los datos de carga se eliminan y el índice se mantiene, para que las features siguientes trabajen con los datos de prueba normales.
```

## Entrada para plan

```text
- database/07_indexes.sql, con bloques:
  A) Limpieza previa: DROP INDEX IF EXISTS del índice de la mejora y borrado de cualquier carga anterior.
  B) Carga de unos 50.000 vehículos con GENERATE_SERIES: matrículas únicas y válidas según el CHECK de 02, modelos, precios, estados y segmentos repartidos de forma realista, y un marcador identificable para borrarlos después.
  C) Consulta ANTES con SET STATISTICS IO, TIME ON.
  D) Creación del índice (compuesto o filtrado). Razona en un comentario las columnas clave y las INCLUDE a partir de los predicados y del JOIN.
  E) Consulta DESPUÉS, idéntica a la de C.
  F) Borrado de los datos de carga.
- Ejecuta cada consulta dos veces y compara la segunda ejecución en ambos casos, con la caché en el mismo estado.
- Captura el plan real con SET STATISTICS XML ON y guárdalo en docs/evidencias/003-plan-antes.sqlplan y docs/evidencias/003-plan-despues.sqlplan. Guarda la salida de STATISTICS IO y TIME en docs/evidencias/003-optimizacion.txt.
- docs/evidencias/003-optimizacion.md: tabla antes y después (operador de acceso, coste estimado del plan, lecturas lógicas, tiempo de CPU y tiempo transcurrido) solo con valores obtenidos, más la explicación. Indica que el alumno debe añadir capturas del plan gráfico de SSMS en docs/img/.
- tests/tests.sql: nuevo bloque de optimización. El índice de la mejora existe (sys.indexes) y, tras borrar la carga de prueba, los recuentos vuelven a los de 03 (228 vehículos).
- Comprueba que, tras 07, todos los bloques anteriores de tests/tests.sql siguen pasando.
```

## Criterio de cierre

- `run_all.ps1` termina sin errores.
- Los dos `.sqlplan` y la tabla comparativa existen con valores reales.
