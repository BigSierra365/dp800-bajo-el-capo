-- A: el esquema debe contener las 9 tablas del modelo
USE BajoElCapoDB;
GO
DECLARE @n INT = (SELECT COUNT(*) FROM sys.tables);
DECLARE @msg NVARCHAR(200) = CONCAT(N'Se esperaban 9 tablas y hay ', @n);
IF @n <> 9 THROW 50001, @msg, 1;
PRINT N'OK: las 9 tablas existen';
GO

-- B: Consulta de comprobación de las 9 tablas, agrupadas por esquema
USE BajoElCapoDB;
SELECT s.name AS esquema, t.name AS tabla
FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id
ORDER BY s.name, t.name;