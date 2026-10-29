/* =============================================================================
   Proyecto   : Bajo el Capó · DP-800 (Microsoft SQL AI Developer Associate)
   Script     : tests/demo_seguridad.sql
   Objetivo   : Demuestra que distintos usuarios tienen distintos permisos: las
                mismas consultas con EXECUTE AS USER muestran filas distintas
                (RLS), datos enmascarados (DDM) o permisos denegados (DENY).
   Requisitos : database/06_security.sql ejecutado. No deja cambios en los datos.
   Ejecución  : SSMS 22 (bloque a bloque para las capturas), o
                sqlcmd -S localhost -d BajoElCapoDB -E -C -I -W -i tests\demo_seguridad.sql
   Autor      : Emmanuel Grande Sierra
   ============================================================================= */

USE BajoElCapoDB;
GO
SET NOCOUNT ON;
GO

-- A: RLS · la misma consulta de reservas y clientes con cada usuario
PRINT N'--- A: RLS · misma consulta con distintos usuarios ---';
DECLARE @usuarios TABLE (orden INT, usuario SYSNAME);
INSERT INTO @usuarios VALUES (1, N'admin_demo'), (2, N'comercial_ana'), (3, N'comercial_luis'),
                             (4, N'comercial_marta'), (5, N'comercial_javier');
DECLARE @resultado TABLE (usuario SYSNAME, reservas_visibles INT, clientes_visibles INT);
DECLARE @u SYSNAME, @i INT = 1, @r INT, @c INT;
WHILE @i <= 5
BEGIN
    SELECT @u = usuario FROM @usuarios WHERE orden = @i;
    EXECUTE AS USER = @u;
        SELECT @r = COUNT(*) FROM ventas.vw_reservas;
        SELECT @c = COUNT(*) FROM ventas.Clientes;
    REVERT;
    INSERT INTO @resultado VALUES (@u, @r, @c);
    SET @i += 1;
END
SELECT usuario, reservas_visibles, clientes_visibles FROM @resultado;
GO

-- B: RLS · detalle de lo que ve un comercial (solo sus reservas)
PRINT N'--- B: reservas que ve comercial_ana ---';
EXECUTE AS USER = N'comercial_ana';
    SELECT USER_NAME() AS usuario, reserva_id, estado, marca, modelo, cliente, comercial
    FROM ventas.vw_reservas
    ORDER BY reserva_id;
REVERT;
GO

-- C: DDM · los mismos clientes vistos por el administrador y por un comercial
PRINT N'--- C: DDM · administrador (sin máscara) frente a comercial (enmascarado) ---';
EXECUTE AS USER = N'admin_demo';
    SELECT TOP (3) USER_NAME() AS usuario, nombre, email, telefono
    FROM ventas.Clientes
    WHERE comercial_id = (SELECT comercial_id FROM ventas.Comerciales WHERE usuario_bd = N'comercial_ana')
    ORDER BY cliente_id;
REVERT;
EXECUTE AS USER = N'comercial_ana';
    SELECT TOP (3) USER_NAME() AS usuario, nombre, email, telefono
    FROM ventas.Clientes
    ORDER BY cliente_id;
REVERT;
GO

-- D: mínimo privilegio · el mecánico consulta averías, pero no clientes ni reservas
PRINT N'--- D: mecánico · averías sí, clientes y reservas no ---';
EXECUTE AS USER = N'mecanico_demo';
    SELECT TOP (3) USER_NAME() AS usuario, marca, modelo, titulo, riesgo
    FROM taller.vw_averias_por_modelo
    ORDER BY riesgo DESC, titulo;
REVERT;
GO
EXECUTE AS USER = N'mecanico_demo';
BEGIN TRY
    SELECT COUNT(*) AS clientes FROM ventas.Clientes;
END TRY
BEGIN CATCH
    PRINT CONCAT(N'mecanico_demo -> ventas.Clientes: DENEGADO (error ', ERROR_NUMBER(), N'): ', ERROR_MESSAGE());
END CATCH
BEGIN TRY
    SELECT COUNT(*) AS reservas FROM ventas.vw_reservas;
END TRY
BEGIN CATCH
    PRINT CONCAT(N'mecanico_demo -> ventas.vw_reservas: DENEGADO (error ', ERROR_NUMBER(), N'): ', ERROR_MESSAGE());
END CATCH
REVERT;
GO

-- E: mínimo privilegio · el comercial no puede leer la tabla de vehículos (precio de compra)
PRINT N'--- E: comercial · precio de compra no accesible ---';
EXECUTE AS USER = N'comercial_ana';
BEGIN TRY
    SELECT TOP (1) matricula, precio_compra FROM catalogo.Vehiculos;
END TRY
BEGIN CATCH
    PRINT CONCAT(N'comercial_ana -> catalogo.Vehiculos.precio_compra: DENEGADO (error ', ERROR_NUMBER(), N'): ', ERROR_MESSAGE());
END CATCH
SELECT TOP (3) USER_NAME() AS usuario, marca, modelo, precio_venta
FROM catalogo.vw_catalogo
WHERE estado = N'Disponible'
ORDER BY precio_venta;
REVERT;
GO

-- F: el servicio de IA no ve clientes
PRINT N'--- F: servicio de IA · sin acceso a clientes ---';
EXECUTE AS USER = N'ia_servicio';
BEGIN TRY
    SELECT COUNT(*) AS clientes FROM ventas.Clientes;
END TRY
BEGIN CATCH
    PRINT CONCAT(N'ia_servicio -> ventas.Clientes: DENEGADO (error ', ERROR_NUMBER(), N'): ', ERROR_MESSAGE());
END CATCH
REVERT;
GO

-- G: procedimientos con RLS · un comercial reserva para su cliente, pero no para el de otro
--    El intento rechazado va fuera de la transacción (el CATCH del procedimiento haría ROLLBACK
--    de todo); la reserva válida va dentro de una transacción que se deshace al final.
PRINT N'--- G: reserva con RLS activo (se deshace al final) ---';
SET XACT_ABORT OFF;
DECLARE @vehiculo INT = (SELECT TOP (1) vehiculo_id FROM catalogo.Vehiculos WHERE estado = N'Disponible' ORDER BY vehiculo_id);
DECLARE @propio INT = (SELECT TOP (1) c.cliente_id FROM ventas.Clientes AS c
                       JOIN ventas.Comerciales AS co ON co.comercial_id = c.comercial_id
                       WHERE co.usuario_bd = N'comercial_ana' ORDER BY c.cliente_id);
DECLARE @ajeno INT  = (SELECT TOP (1) c.cliente_id FROM ventas.Clientes AS c
                       JOIN ventas.Comerciales AS co ON co.comercial_id = c.comercial_id
                       WHERE co.usuario_bd = N'comercial_luis' ORDER BY c.cliente_id);
DECLARE @reserva INT;

EXECUTE AS USER = N'comercial_ana';
BEGIN TRY
    EXEC ventas.sp_registrar_reserva @vehiculo_id = @vehiculo, @cliente_id = @ajeno;
    PRINT N'comercial_ana -> reserva para cliente de comercial_luis: CREADA (no debería)';
END TRY
BEGIN CATCH
    PRINT CONCAT(N'comercial_ana -> reserva para cliente de comercial_luis: RECHAZADA (error ', ERROR_NUMBER(), N'): ', ERROR_MESSAGE());
END CATCH
REVERT;

BEGIN TRANSACTION;
EXECUTE AS USER = N'comercial_ana';
EXEC ventas.sp_registrar_reserva @vehiculo_id = @vehiculo, @cliente_id = @propio, @reserva_id = @reserva OUTPUT;
SELECT USER_NAME() AS usuario, reserva_id, estado, marca, modelo, cliente
FROM ventas.vw_reservas WHERE reserva_id = @reserva;
REVERT;
ROLLBACK TRANSACTION;
PRINT N'Reserva de demostración deshecha (ROLLBACK).';
GO

PRINT N'Demostración de seguridad terminada.';
GO
