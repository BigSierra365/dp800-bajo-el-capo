/* =============================================================================
   Proyecto   : Bajo el Capó · DP-800 (Microsoft SQL AI Developer Associate)
   Script     : database/01_create_database.sql
   Objetivo   : Crea la base de datos BajoElCapoDB y sus esquemas.
   Requisitos : SQL Server 2025 (17.x), nivel de compatibilidad 170
                (regex, tipo VECTOR y tipo JSON nativos).
   Ejecución  : SSMS 22 con un usuario sysadmin, o
                sqlcmd -S localhost -d master -E -C -b -i database\01_create_database.sql
   Siguiente  : 02_create_tables.sql
   Aviso      : Es destructivo. Si BajoElCapoDB ya existe, se elimina y se recrea.
   Autor      : Emmanuel Grande Sierra
   ============================================================================= */

-- A: elimina la BD si existe, para que el script se pueda repetir desde cero
USE master;
GO
IF DB_ID(N'BajoElCapoDB') IS NOT NULL
BEGIN
    ALTER DATABASE BajoElCapoDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE BajoElCapoDB;
END
GO

-- B: crea la BD con collation en español y nivel 170 (necesario para regex, VECTOR y JSON)
CREATE DATABASE BajoElCapoDB COLLATE Modern_Spanish_CI_AS;
GO
ALTER DATABASE BajoElCapoDB SET COMPATIBILITY_LEVEL = 170;
GO
USE BajoElCapoDB;
GO

-- C: un esquema por dominio, para poder asignar permisos por esquema
CREATE SCHEMA catalogo;   -- marcas, modelos y vehículos en stock
GO
CREATE SCHEMA taller;     -- averías conocidas por modelo
GO
CREATE SCHEMA ventas;     -- comerciales, clientes, reservas y ventas
GO
CREATE SCHEMA ia;         -- procedimientos de búsqueda semántica y RAG
GO
CREATE SCHEMA seg;        -- función de predicado de Row-Level Security
GO

PRINT N'BajoElCapoDB creada correctamente con 5 esquemas.';
GO