# 002 · Seguridad (bloque C)

## Entrada para specify

```text
Seguridad del concesionario: cada perfil ve y hace solo lo que necesita.

Perfiles:
- Administrador: todo.
- Comercial: usa el catálogo, el buscador y el asesor; gestiona sus reservas y sus clientes. Nunca ve el precio de compra ni los clientes de otros comerciales.
- Mecánico: consulta modelos y averías y usa el asesor. Nunca ve clientes, reservas ni precios de compra.
- Servicio de IA: usa el modelo externo y lee el contexto necesario. Nunca modifica datos ni ve clientes.

Historias de usuario:
1. Como comercial, solo veo mis clientes y mis reservas.
2. Como comercial, veo el email y el teléfono de los clientes enmascarados; el administrador los ve completos.
3. Como mecánico, si intento consultar clientes o reservas, recibo un permiso denegado.
4. Como alumno, quiero una demostración que ejecute las mismas consultas con distintos usuarios y muestre resultados distintos o permisos denegados.

Criterios de aceptación:
- Al menos tres mecanismos: mínimo privilegio con GRANT/DENY (acceso por vistas y procedimientos), Row-Level Security y Dynamic Data Masking.
- La misma consulta devuelve un número de filas distinto para dos comerciales.
- Un usuario sin UNMASK ve los datos enmascarados.
- El mecánico recibe un error de permiso al consultar clientes.
- Los procedimientos de reserva y venta siguen funcionando cuando los ejecuta un comercial, solo sobre sus clientes.
- Los procedimientos de IA (features 004 y 005) quedarán accesibles para comerciales y mecánicos sin permisos directos sobre el modelo externo.
- No hay contraseñas: los usuarios de demostración no tienen inicio de sesión.
- El script se puede ejecutar varias veces y la demostración deja evidencias.
```

## Entrada para plan

```text
- database/06_security.sql, idempotente: elimina, si existen, la política de seguridad, la función de predicado, las máscaras, los usuarios y los roles, y los vuelve a crear.
- Roles: rol_admin, rol_comercial, rol_mecanico y rol_ia_servicio.
- Usuarios WITHOUT LOGIN: admin_demo, uno por cada valor de ventas.Comerciales.usuario_bd, mecanico_demo e ia_servicio.
- Permisos según la tabla de roles de la propuesta: GRANT SELECT sobre las vistas y EXECUTE sobre los procedimientos que corresponden a cada rol; sin acceso directo a las tablas base. DENY sobre el esquema ventas a rol_mecanico. GRANT EXECUTE ON SCHEMA::ia a rol_comercial y rol_mecanico (los procedimientos de IA se crean más tarde), con DENY sobre ia.sp_generar_embeddings.
- Row-Level Security: función de predicado en línea en el esquema seg, con SCHEMABINDING, que compara ventas.Comerciales.usuario_bd con USER_NAME() y deja pasar a los miembros de rol_admin y de db_owner. Política con FILTER y BLOCK sobre ventas.Clientes y ventas.Reservas.
- Dynamic Data Masking: email con email() y teléfono con partial(). UNMASK solo para rol_admin.
- Comprueba que el trigger tr_reservas_estado, las vistas y los procedimientos de reserva y venta siguen funcionando con RLS activo.
- tests/demo_seguridad.sql: para cada usuario, EXECUTE AS USER, las mismas consultas y REVERT; los permisos denegados se capturan con TRY/CATCH y se muestra el mensaje. Guarda la salida real en docs/evidencias/002-seguridad.txt.
- tests/tests.sql: nuevo bloque de seguridad que comprueba los roles, que la política está activa y las columnas enmascaradas (sys.masked_columns).
- Añade 06_security.sql a run_all.ps1 en su posición.
```

## Criterio de cierre

- `run_all.ps1` termina sin errores.
- `docs/evidencias/002-seguridad.txt` muestra filas distintas para dos comerciales, datos enmascarados y al menos un permiso denegado.
