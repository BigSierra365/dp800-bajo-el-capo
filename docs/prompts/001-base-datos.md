# 001 · Base de datos y T-SQL (bloque A)

## Entrada para specify

```text
Base de datos del concesionario de coches de segunda mano Bajo el Capó. Es la base del buscador semántico y del asesor de averías.

Historias de usuario:
1. Como comercial, quiero consultar el catálogo de coches disponibles con marca, modelo, segmento, precio y descripción, sin ver nunca el precio de compra.
2. Como mecánico, quiero ver las averías conocidas de cada modelo con su frecuencia, su gravedad y un nivel de riesgo.
3. Como comercial, quiero reservar un coche para un cliente sin que otro comercial pueda reservarlo a la vez.
4. Como comercial, quiero cerrar la venta de una reserva activa con un precio final válido.
5. Como responsable del concesionario, quiero saber qué modelos cuestan más de mantener que la media de su marca.
6. Como analista, quiero consultas avanzadas: las 3 averías más frecuentes de cada modelo, el precio de cada coche frente a la media de su segmento, los coches con un extra concreto del equipamiento, la validación de teléfonos y la búsqueda por palabras clave.
7. Como alumno, quiero recrear toda la base desde cero con un único comando y comprobar automáticamente que es correcta.

Criterios de aceptación:
- 9 tablas relacionadas con PK, FK, CHECK, UNIQUE y DEFAULT, con relaciones 1:N, N:M (ModeloAveria) y 1:1 (Reservas y Ventas).
- Datos de prueba de un concesionario grande: 8 marcas, 24 modelos, al menos 200 vehículos (228), 57 averías, 207 relaciones modelo-avería, 4 comerciales, 24 clientes, 44 reservas y 16 ventas.
- Al menos un modelo sin ninguna avería registrada (caso de control del RAG).
- Descripciones comerciales variadas y naturales, que describan el uso del coche con palabras distintas a las de las búsquedas de prueba (por ejemplo, un coche familiar descrito como «maletero enorme y siete plazas», no como «familiar»).
- Equipamiento en JSON con una lista de extras; algunos coches con «isofix».
- Algún teléfono con un formato que haya que normalizar, si las restricciones de la tabla lo permiten.
- Reservar un coche no disponible devuelve un error controlado. El estado del coche cambia solo al reservar, cancelar o vender.
- Las consultas avanzadas devuelven resultados con sentido sobre los datos de prueba.
- Un solo comando recrea la base y ejecuta los tests, y todos pasan.
```

## Entrada para plan

```text
Stack: SQL Server 2025 local (nivel de compatibilidad 170), T-SQL, sqlcmd y PowerShell en Windows 11. Base BajoElCapoDB; esquemas catalogo, taller, ventas, ia y seg.

Archivos:
- database/01_create_database.sql y 02_create_tables.sql: ya validados; no los cambies salvo contradicción con las fuentes. Lee 02 para conocer columnas, CHECK (formato de matrícula, email, segmentos y estados) y nombres exactos.
- database/03_insert_data.sql: ya escrito (no lo regeneres). Las FK se resuelven por nombre o clave natural; usuario_bd de los comerciales: comercial_ana, comercial_luis, comercial_marta y comercial_javier (los usuarios de la feature 002 deben llamarse igual). Como 05 se ejecuta después, el propio 03 fija el estado de los coches según sus reservas. Si algo falla al ejecutarlo, corrige lo mínimo y regístralo en docs/bloque-b.md.
- database/04_views.sql, 05_procedures.sql y 08_advanced_queries.sql: ya escritos. Revísalos contra 02 y las fuentes, corrige solo errores y ejecútalos.
- database/06_security.sql y 07_indexes.sql: vacíos hasta las features 002 y 003. run_all.ps1 debe omitir los archivos vacíos.
- tests/tests.sql: bloques A (las 9 tablas existen), B (tablas por esquema), C (recuentos exactos de 03: 8, 24, 228, 57, 207, 4, 24, 44 y 16), D (coherencia: estado de cada coche frente a sus reservas, una sola reserva activa por coche, precio final no mayor que el precio de venta), E (vistas y funciones devuelven filas) y F (flujo de reserva, doble reserva que debe fallar con el error 50102, venta y limpieza de los datos del test). Cada fallo lanza THROW 500xx.
- run_all.ps1 (raíz): parámetros -Servidor (por defecto localhost) y -ConIA (switch). Ejecuta 01 contra master; después, en orden explícito, database/02 a 08; luego, solo con -ConIA, tests/test_conexion_ia.sql (ya escrito) y después ai/create_external_model.sql, ai/generate_embeddings.sql, ai/vector_search.sql y ai/rag.sql; después tests/tests.sql y, con -ConIA, tests/tests_ia.sql. Usa sqlcmd -S $Servidor -E -C -b -i, rutas relativas a la ubicación del script, y se detiene en el primer error.
- docs/evidencias/001-base-datos.txt: salida real de run_all.ps1 y de 08_advanced_queries.sql.
- docs/decisiones.md, docs/bloque-b.md y docs/estado.md: créalos si no existen.
```

## Criterio de cierre

- `run_all.ps1` termina sin errores y todos los bloques de `tests/tests.sql` pasan.
- Hay al menos un modelo sin averías.
- `docs/evidencias/001-base-datos.txt` contiene salidas reales.
