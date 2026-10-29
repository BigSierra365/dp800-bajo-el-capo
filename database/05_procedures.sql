/* =============================================================================
   Proyecto   : Bajo el Capó · DP-800 (Microsoft SQL AI Developer Associate)
   Script     : database/05_procedures.sql
   Objetivo   : Crea los objetos de programación: funciones, procedimientos
                almacenados y el trigger que mantiene el estado de los coches.
   Requisitos : 04_views.sql ejecutado.
   Ejecución  : SSMS 22, o
                sqlcmd -S localhost -d BajoElCapoDB -E -C -b -i database\05_procedures.sql
   Siguiente  : 06_security.sql
   Autor      : Emmanuel Grande Sierra
   ============================================================================= */

USE BajoElCapoDB;
GO

-- -----------------------------------------------------------------------------
-- Funciones
-- -----------------------------------------------------------------------------

-- A: coste esperado de mantenimiento de un modelo = Σ coste × frecuencia / 5
--    (escalar; SQL Server la puede "inlinear" al usarla dentro de consultas)
CREATE OR ALTER FUNCTION taller.fn_coste_esperado (@modelo_id INT)
RETURNS DECIMAL(10,2)
AS
BEGIN
    RETURN (
        SELECT CAST(ISNULL(SUM(a.coste_estimado * mam.frecuencia / 5.0), 0) AS DECIMAL(10,2))
        FROM taller.ModeloAveria AS mam
        JOIN taller.Averias      AS a ON a.averia_id = mam.averia_id
        WHERE mam.modelo_id = @modelo_id
    );
END;
GO
-- Ejemplo: SELECT nombre, taller.fn_coste_esperado(modelo_id) FROM catalogo.Modelos;

-- B: averías de un modelo ordenables por riesgo (función de tabla en línea; la reutiliza el RAG)
CREATE OR ALTER FUNCTION taller.fn_averias_modelo (@modelo_id INT)
RETURNS TABLE
AS
RETURN
    SELECT
        a.averia_id,
        a.titulo,
        a.sintoma,
        a.solucion,
        a.coste_estimado,
        mam.frecuencia,
        mam.gravedad,
        mam.frecuencia * mam.gravedad AS riesgo
    FROM taller.ModeloAveria AS mam
    JOIN taller.Averias      AS a ON a.averia_id = mam.averia_id
    WHERE mam.modelo_id = @modelo_id;
GO
-- Ejemplo: SELECT TOP (3) titulo, riesgo FROM taller.fn_averias_modelo(1) ORDER BY riesgo DESC;

-- -----------------------------------------------------------------------------
-- Procedimientos
-- -----------------------------------------------------------------------------

-- C: registra una reserva; bloquea el coche para que dos comerciales no lo reserven a la vez
CREATE OR ALTER PROCEDURE ventas.sp_registrar_reserva
    @vehiculo_id INT,
    @cliente_id  INT,
    @reserva_id  INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- C1: el coche existe y está disponible (UPDLOCK + HOLDLOCK lo bloquea hasta el COMMIT)
        DECLARE @estado NVARCHAR(12);
        SELECT @estado = estado
        FROM catalogo.Vehiculos WITH (UPDLOCK, HOLDLOCK)
        WHERE vehiculo_id = @vehiculo_id;

        IF @estado IS NULL
            THROW 50101, N'El vehículo no existe.', 1;
        IF @estado <> N'Disponible'
            THROW 50102, N'El vehículo no está disponible.', 1;

        -- C2: la reserva la gestiona el comercial asignado al cliente
        DECLARE @comercial_id INT;
        SELECT @comercial_id = comercial_id
        FROM ventas.Clientes
        WHERE cliente_id = @cliente_id;

        IF @comercial_id IS NULL
            THROW 50103, N'El cliente no existe.', 1;

        -- C3: crea la reserva; el trigger tr_reservas_estado marca el coche como Reservado
        INSERT INTO ventas.Reservas (vehiculo_id, cliente_id, comercial_id)
        VALUES (@vehiculo_id, @cliente_id, @comercial_id);

        SET @reserva_id = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
-- Ejemplo:
-- DECLARE @id INT;
-- EXEC ventas.sp_registrar_reserva @vehiculo_id = 1, @cliente_id = 1, @reserva_id = @id OUTPUT;
-- SELECT @id AS reserva_creada;

-- D: cierra la venta de una reserva activa; precio final entre 0 y el precio de venta
CREATE OR ALTER PROCEDURE ventas.sp_registrar_venta
    @reserva_id   INT,
    @precio_final DECIMAL(10,2),
    @venta_id     INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- D1: la reserva existe, está activa y el precio es válido
        DECLARE @estado NVARCHAR(12), @precio_venta DECIMAL(10,2);
        SELECT @estado = r.estado, @precio_venta = v.precio_venta
        FROM ventas.Reservas    AS r WITH (UPDLOCK, HOLDLOCK)
        JOIN catalogo.Vehiculos AS v ON v.vehiculo_id = r.vehiculo_id
        WHERE r.reserva_id = @reserva_id;

        IF @estado IS NULL
            THROW 50111, N'La reserva no existe.', 1;
        IF @estado <> N'Activa'
            THROW 50112, N'La reserva no está activa.', 1;
        IF @precio_final <= 0 OR @precio_final > @precio_venta
            THROW 50113, N'El precio final debe estar entre 0 y el precio de venta.', 1;

        -- D2: cierra la reserva y registra la venta; el trigger marca el coche como Vendido
        UPDATE ventas.Reservas SET estado = N'Vendida' WHERE reserva_id = @reserva_id;

        INSERT INTO ventas.Ventas (reserva_id, precio_final)
        VALUES (@reserva_id, @precio_final);

        SET @venta_id = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
-- Ejemplo: EXEC ventas.sp_registrar_venta @reserva_id = 1, @precio_final = 11500;

-- -----------------------------------------------------------------------------
-- Trigger
-- -----------------------------------------------------------------------------

-- E: recalcula el estado de cada coche afectado a partir de todas sus reservas
--    (Vendida → Vendido, Activa → Reservado, si no → Disponible); admite varias filas a la vez
CREATE OR ALTER TRIGGER ventas.tr_reservas_estado
ON ventas.Reservas
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- E1: coches tocados por la operación (filas nuevas y antiguas)
    WITH afectados AS (
        SELECT vehiculo_id FROM inserted
        UNION
        SELECT vehiculo_id FROM deleted
    )
    -- E2: estado según la reserva de mayor prioridad que tenga cada coche
    UPDATE v
    SET estado = CASE
            WHEN EXISTS (SELECT 1 FROM ventas.Reservas AS r
                         WHERE r.vehiculo_id = v.vehiculo_id AND r.estado = N'Vendida') THEN N'Vendido'
            WHEN EXISTS (SELECT 1 FROM ventas.Reservas AS r
                         WHERE r.vehiculo_id = v.vehiculo_id AND r.estado = N'Activa')  THEN N'Reservado'
            ELSE N'Disponible'
        END
    FROM catalogo.Vehiculos AS v
    JOIN afectados          AS a ON a.vehiculo_id = v.vehiculo_id;
END;
GO
-- Ejemplo: UPDATE ventas.Reservas SET estado = N'Cancelada' WHERE reserva_id = 1;  -- el coche vuelve a Disponible

PRINT N'Funciones, procedimientos y trigger creados.';
GO
