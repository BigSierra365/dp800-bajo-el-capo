/* =============================================================================
   Proyecto   : Bajo el Capó · DP-800 (Microsoft SQL AI Developer Associate)
   Script     : tests/tests.sql
   Objetivo   : Tests automáticos de la base de datos. Cada fallo lanza THROW
                500xx y detiene run_all.ps1 (sqlcmd -b).
   Requisitos : database/01 a 08 ejecutados (lo hace run_all.ps1).
   Ejecución  : .\run_all.ps1, o
                sqlcmd -S localhost -d BajoElCapoDB -E -C -b -f 65001 -i tests\tests.sql
   Siguiente  : tests/tests_ia.sql (solo con run_all.ps1 -ConIA)
   Autor      : Emmanuel Grande Sierra
   ============================================================================= */

USE BajoElCapoDB;
GO
SET NOCOUNT ON;
GO

-- A: estructura · existen las 9 tablas del modelo y ninguna está en dbo
DECLARE @n INT = (SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped = 0);
DECLARE @msg NVARCHAR(200) = CONCAT(N'A: se esperaban 9 tablas y hay ', @n);
IF @n <> 9 THROW 50001, @msg, 1;
IF EXISTS (SELECT 1 FROM sys.objects WHERE schema_id = SCHEMA_ID(N'dbo') AND is_ms_shipped = 0)
    THROW 50002, N'A: hay objetos del proyecto en dbo.', 1;
PRINT N'OK A: las 9 tablas existen y no hay objetos en dbo';
GO

-- B: estructura · tablas por esquema (3 catalogo, 2 taller, 4 ventas)
SELECT s.name AS esquema, COUNT(*) AS tablas
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
GROUP BY s.name
ORDER BY s.name;

IF (SELECT COUNT(*) FROM sys.tables WHERE schema_id = SCHEMA_ID(N'catalogo')) <> 3
OR (SELECT COUNT(*) FROM sys.tables WHERE schema_id = SCHEMA_ID(N'taller'))   <> 2
OR (SELECT COUNT(*) FROM sys.tables WHERE schema_id = SCHEMA_ID(N'ventas'))   <> 4
    THROW 50003, N'B: el reparto de tablas por esquema no es 3/2/4.', 1;
PRINT N'OK B: tablas por esquema correctas';
GO

-- C: datos · recuentos exactos de 03_insert_data.sql
DECLARE @recuentos TABLE (tabla SYSNAME, esperado INT, real INT);
INSERT INTO @recuentos VALUES
    (N'catalogo.Marcas',      8,   (SELECT COUNT(*) FROM catalogo.Marcas)),
    (N'catalogo.Modelos',     24,  (SELECT COUNT(*) FROM catalogo.Modelos)),
    (N'catalogo.Vehiculos',   228, (SELECT COUNT(*) FROM catalogo.Vehiculos)),
    (N'taller.Averias',       57,  (SELECT COUNT(*) FROM taller.Averias)),
    (N'taller.ModeloAveria',  207, (SELECT COUNT(*) FROM taller.ModeloAveria)),
    (N'ventas.Comerciales',   4,   (SELECT COUNT(*) FROM ventas.Comerciales)),
    (N'ventas.Clientes',      24,  (SELECT COUNT(*) FROM ventas.Clientes)),
    (N'ventas.Reservas',      44,  (SELECT COUNT(*) FROM ventas.Reservas)),
    (N'ventas.Ventas',        16,  (SELECT COUNT(*) FROM ventas.Ventas));

SELECT tabla, esperado, real FROM @recuentos;

DECLARE @fallos NVARCHAR(400) =
    (SELECT STRING_AGG(CONCAT(tabla, N'=', real, N' (esperado ', esperado, N')'), N', ')
     FROM @recuentos WHERE esperado <> real);
IF @fallos IS NOT NULL
BEGIN
    SET @fallos = N'C: recuentos incorrectos: ' + @fallos;
    THROW 50010, @fallos, 1;
END
PRINT N'OK C: los 9 recuentos coinciden con 03_insert_data.sql';
GO

-- D: datos · coherencia entre coches, reservas y ventas
-- D1: el estado de cada coche coincide con sus reservas
IF EXISTS (
    SELECT 1
    FROM catalogo.Vehiculos AS v
    WHERE v.estado <> CASE
            WHEN EXISTS (SELECT 1 FROM ventas.Reservas AS r WHERE r.vehiculo_id = v.vehiculo_id AND r.estado = N'Vendida') THEN N'Vendido'
            WHEN EXISTS (SELECT 1 FROM ventas.Reservas AS r WHERE r.vehiculo_id = v.vehiculo_id AND r.estado = N'Activa')  THEN N'Reservado'
            ELSE N'Disponible' END)
    THROW 50011, N'D1: hay coches cuyo estado no coincide con sus reservas.', 1;

-- D2: como mucho una reserva activa por coche
IF EXISTS (SELECT vehiculo_id FROM ventas.Reservas WHERE estado = N'Activa'
           GROUP BY vehiculo_id HAVING COUNT(*) > 1)
    THROW 50012, N'D2: hay coches con más de una reserva activa.', 1;

-- D3: precio final no mayor que el precio de venta, y cada venta viene de una reserva Vendida
IF EXISTS (SELECT 1
           FROM ventas.Ventas      AS ve
           JOIN ventas.Reservas    AS r ON r.reserva_id  = ve.reserva_id
           JOIN catalogo.Vehiculos AS v ON v.vehiculo_id = r.vehiculo_id
           WHERE ve.precio_final > v.precio_venta OR r.estado <> N'Vendida')
    THROW 50013, N'D3: hay ventas con precio final superior al de venta o sin reserva vendida.', 1;

-- D4: el comercial de cada reserva es el asignado a su cliente
IF EXISTS (SELECT 1 FROM ventas.Reservas AS r
           JOIN ventas.Clientes AS c ON c.cliente_id = r.cliente_id
           WHERE c.comercial_id <> r.comercial_id)
    THROW 50014, N'D4: hay reservas gestionadas por un comercial distinto al del cliente.', 1;

SELECT estado, COUNT(*) AS coches FROM catalogo.Vehiculos GROUP BY estado ORDER BY estado;
PRINT N'OK D: coches, reservas y ventas coherentes';
GO

-- E: objetos · vistas y funciones devuelven filas; el Dacia Jogger no tiene averías
IF NOT EXISTS (SELECT 1 FROM catalogo.vw_catalogo WHERE estado = N'Disponible')
    THROW 50020, N'E: vw_catalogo no devuelve coches disponibles.', 1;
IF COL_LENGTH(N'catalogo.vw_catalogo', N'precio_compra') IS NOT NULL
    THROW 50021, N'E: vw_catalogo expone precio_compra.', 1;
IF NOT EXISTS (SELECT 1 FROM taller.vw_averias_por_modelo WHERE riesgo BETWEEN 1 AND 25)
    THROW 50022, N'E: vw_averias_por_modelo no devuelve filas válidas.', 1;
IF NOT EXISTS (SELECT 1 FROM ventas.vw_reservas)
    THROW 50023, N'E: vw_reservas no devuelve filas.', 1;

DECLARE @modelo INT = (SELECT TOP (1) modelo_id FROM taller.ModeloAveria ORDER BY modelo_id);
IF taller.fn_coste_esperado(@modelo) <= 0
    THROW 50024, N'E: fn_coste_esperado no devuelve un coste positivo.', 1;
IF NOT EXISTS (SELECT 1 FROM taller.fn_averias_modelo(@modelo))
    THROW 50025, N'E: fn_averias_modelo no devuelve filas.', 1;

DECLARE @jogger INT = (SELECT mo.modelo_id FROM catalogo.Modelos AS mo
                       JOIN catalogo.Marcas AS ma ON ma.marca_id = mo.marca_id
                       WHERE ma.nombre = N'Dacia' AND mo.nombre = N'Jogger');
IF @jogger IS NULL
    THROW 50026, N'E: no existe el modelo Dacia Jogger.', 1;
IF EXISTS (SELECT 1 FROM taller.ModeloAveria WHERE modelo_id = @jogger)
    THROW 50027, N'E: el Dacia Jogger tiene averías (debe ser el caso de control).', 1;
IF taller.fn_coste_esperado(@jogger) <> 0
    THROW 50028, N'E: el coste esperado del Jogger debería ser 0.', 1;
PRINT N'OK E: vistas y funciones devuelven filas; el Dacia Jogger no tiene averías';
GO

-- F: integración · reserva, doble reserva (50102), venta con precio inválido (50113), venta y limpieza
SET XACT_ABORT OFF;   -- los errores esperados se capturan sin abortar el lote
DECLARE @vehiculo INT, @cliente INT, @otro_cliente INT, @precio DECIMAL(10,2),
        @reserva INT, @venta INT, @error INT;

SELECT TOP (1) @vehiculo = vehiculo_id, @precio = precio_venta
FROM catalogo.Vehiculos WHERE estado = N'Disponible' ORDER BY vehiculo_id;
SELECT TOP (1) @cliente = cliente_id FROM ventas.Clientes ORDER BY cliente_id;
SELECT TOP (1) @otro_cliente = cliente_id FROM ventas.Clientes ORDER BY cliente_id DESC;

BEGIN TRY
    -- F1: reserva válida; el trigger marca el coche como Reservado
    EXEC ventas.sp_registrar_reserva @vehiculo_id = @vehiculo, @cliente_id = @cliente, @reserva_id = @reserva OUTPUT;
    IF (SELECT estado FROM catalogo.Vehiculos WHERE vehiculo_id = @vehiculo) <> N'Reservado'
        THROW 50030, N'F1: el coche no pasó a Reservado.', 1;

    -- F2: segunda reserva del mismo coche: debe fallar con 50102
    SET @error = NULL;
    BEGIN TRY
        EXEC ventas.sp_registrar_reserva @vehiculo_id = @vehiculo, @cliente_id = @otro_cliente;
    END TRY
    BEGIN CATCH
        SET @error = ERROR_NUMBER();
    END CATCH
    IF ISNULL(@error, 0) <> 50102
        THROW 50031, N'F2: la doble reserva no devolvió el error 50102.', 1;
    PRINT N'OK F2: doble reserva rechazada con el error 50102';

    -- F3: venta con precio superior al de venta: debe fallar con 50113
    SET @error = NULL;
    BEGIN TRY
        DECLARE @caro DECIMAL(10,2) = @precio + 1;
        EXEC ventas.sp_registrar_venta @reserva_id = @reserva, @precio_final = @caro;
    END TRY
    BEGIN CATCH
        SET @error = ERROR_NUMBER();
    END CATCH
    IF ISNULL(@error, 0) <> 50113
        THROW 50032, N'F3: la venta con precio inválido no devolvió el error 50113.', 1;

    -- F4: venta válida; reserva Vendida y coche Vendido
    EXEC ventas.sp_registrar_venta @reserva_id = @reserva, @precio_final = @precio, @venta_id = @venta OUTPUT;
    IF (SELECT estado FROM catalogo.Vehiculos WHERE vehiculo_id = @vehiculo) <> N'Vendido'
    OR (SELECT estado FROM ventas.Reservas WHERE reserva_id = @reserva) <> N'Vendida'
        THROW 50033, N'F4: la venta no actualizó la reserva o el coche.', 1;
END TRY
BEGIN CATCH
    -- limpieza también si algo falla, y se relanza el error
    DELETE FROM ventas.Ventas   WHERE venta_id   = @venta;
    DELETE FROM ventas.Reservas WHERE reserva_id = @reserva;
    THROW;
END CATCH

-- F5: limpieza; al borrar la reserva el trigger devuelve el coche a Disponible
DELETE FROM ventas.Ventas   WHERE venta_id   = @venta;
DELETE FROM ventas.Reservas WHERE reserva_id = @reserva;
IF (SELECT estado FROM catalogo.Vehiculos WHERE vehiculo_id = @vehiculo) <> N'Disponible'
    THROW 50034, N'F5: el coche no volvió a Disponible tras la limpieza.', 1;
IF (SELECT COUNT(*) FROM ventas.Reservas) <> 44 OR (SELECT COUNT(*) FROM ventas.Ventas) <> 16
    THROW 50035, N'F5: la limpieza no dejó los recuentos originales.', 1;
PRINT N'OK F: reserva, doble reserva, venta y limpieza correctas';
GO

-- G: seguridad · roles, política RLS activa, columnas enmascaradas y efecto real por usuario
IF (SELECT COUNT(*) FROM sys.database_principals WHERE type = 'R'
    AND name IN (N'rol_admin', N'rol_comercial', N'rol_mecanico', N'rol_ia_servicio')) <> 4
    THROW 50040, N'G: faltan roles de seguridad.', 1;
IF (SELECT COUNT(*) FROM sys.database_principals WHERE type = 'S' AND authentication_type = 0
    AND name IN (N'admin_demo', N'comercial_ana', N'comercial_luis', N'comercial_marta',
                 N'comercial_javier', N'mecanico_demo', N'ia_servicio')) <> 7
    THROW 50041, N'G: faltan usuarios de demostración sin inicio de sesión.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.security_policies WHERE name = N'politica_comerciales' AND is_enabled = 1)
    THROW 50042, N'G: la política de RLS no existe o está desactivada.', 1;
IF (SELECT COUNT(*) FROM sys.masked_columns
    WHERE object_id = OBJECT_ID(N'ventas.Clientes') AND is_masked = 1 AND name IN (N'email', N'telefono')) <> 2
    THROW 50043, N'G: email y teléfono deben estar enmascarados.', 1;

-- G2: dos comerciales ven un número distinto de reservas y la suma de los cuatro es el total
DECLARE @ana INT, @luis INT, @marta INT, @javier INT, @email NVARCHAR(120);
EXECUTE AS USER = N'comercial_ana';    SELECT @ana    = COUNT(*) FROM ventas.vw_reservas;
    SELECT TOP (1) @email = email FROM ventas.Clientes ORDER BY cliente_id;   REVERT;
EXECUTE AS USER = N'comercial_luis';   SELECT @luis   = COUNT(*) FROM ventas.vw_reservas; REVERT;
EXECUTE AS USER = N'comercial_marta';  SELECT @marta  = COUNT(*) FROM ventas.vw_reservas; REVERT;
EXECUTE AS USER = N'comercial_javier'; SELECT @javier = COUNT(*) FROM ventas.vw_reservas; REVERT;
IF @ana = @luis OR @ana + @luis + @marta + @javier <> (SELECT COUNT(*) FROM ventas.Reservas)
    THROW 50044, N'G2: RLS no reparte las reservas entre comerciales.', 1;
IF @email NOT LIKE N'_XXX@XXXX%'
    THROW 50045, N'G2: el comercial ve el email sin máscara.', 1;

-- G3: el mecánico recibe un permiso denegado (229) al consultar clientes
DECLARE @error INT = NULL;
EXECUTE AS USER = N'mecanico_demo';
BEGIN TRY
    DECLARE @n INT = (SELECT COUNT(*) FROM ventas.Clientes);
END TRY
BEGIN CATCH
    SET @error = ERROR_NUMBER();
END CATCH
REVERT;
IF ISNULL(@error, 0) <> 229
    THROW 50046, N'G3: el mecánico no recibió un permiso denegado sobre clientes.', 1;
PRINT N'OK G: roles, RLS, DDM y permisos denegados correctos';
GO

-- H: optimización · el índice de la mejora existe y la carga de 07 se ha borrado
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE object_id = OBJECT_ID(N'catalogo.Vehiculos') AND name = N'ix_vehiculos_estado_precio')
    THROW 50050, N'H: no existe el índice ix_vehiculos_estado_precio.', 1;
IF EXISTS (SELECT 1 FROM catalogo.Vehiculos WHERE descripcion LIKE N'[[]CARGA]%')
OR (SELECT COUNT(*) FROM catalogo.Vehiculos) <> 228
    THROW 50051, N'H: quedan datos de la carga de 07 (se esperaban 228 coches).', 1;
PRINT N'OK H: índice de optimización creado y 228 coches tras borrar la carga';
GO

PRINT N'TESTS: todos los bloques han pasado.';
GO
