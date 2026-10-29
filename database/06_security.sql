/* =============================================================================
   Proyecto   : Bajo el Capó · DP-800 (Microsoft SQL AI Developer Associate)
   Script     : database/06_security.sql
   Objetivo   : Seguridad por perfiles con tres mecanismos: mínimo privilegio
                (roles y GRANT/DENY sobre vistas y procedimientos), Row-Level
                Security en clientes y reservas, y Dynamic Data Masking en los
                datos de contacto. Usuarios de demostración sin inicio de sesión.
   Requisitos : 05_procedures.sql ejecutado.
   Ejecución  : SSMS 22, o
                sqlcmd -S localhost -d BajoElCapoDB -E -C -b -I -i database\06_security.sql
                Re-ejecutable: elimina y vuelve a crear todos sus objetos.
   Siguiente  : 07_indexes.sql (demostración en tests/demo_seguridad.sql)
   Autor      : Emmanuel Grande Sierra
   ============================================================================= */

USE BajoElCapoDB;
GO
SET NOCOUNT ON;
GO

-- -----------------------------------------------------------------------------
-- Limpieza (para poder repetir el script)
-- -----------------------------------------------------------------------------

-- A: política y función de predicado de RLS
DROP SECURITY POLICY IF EXISTS seg.politica_comerciales;
DROP FUNCTION IF EXISTS seg.fn_predicado_comercial;
GO

-- B: máscaras de las columnas de contacto (SQL dinámico: DROP MASKED se valida al compilar el lote)
DECLARE @sql NVARCHAR(MAX) = N'';
SELECT @sql += N'ALTER TABLE ventas.Clientes ALTER COLUMN ' + QUOTENAME(name) + N' DROP MASKED;'
FROM sys.masked_columns
WHERE object_id = OBJECT_ID(N'ventas.Clientes') AND is_masked = 1;
EXEC sys.sp_executesql @sql;
GO

-- C: usuarios y roles de demostración (al borrar el usuario se borra su pertenencia a roles)
DECLARE @sql NVARCHAR(MAX) = N'';
SELECT @sql += N'DROP USER ' + QUOTENAME(name) + N';'
FROM sys.database_principals
WHERE type = 'S' AND name IN (N'admin_demo', N'comercial_ana', N'comercial_luis', N'comercial_marta',
                              N'comercial_javier', N'mecanico_demo', N'ia_servicio');
SELECT @sql += N'DROP ROLE ' + QUOTENAME(name) + N';'
FROM sys.database_principals
WHERE type = 'R' AND name IN (N'rol_admin', N'rol_comercial', N'rol_mecanico', N'rol_ia_servicio');
EXEC sys.sp_executesql @sql;
GO

-- -----------------------------------------------------------------------------
-- Mecanismo 1: roles, usuarios y mínimo privilegio
-- -----------------------------------------------------------------------------

-- D: un rol por perfil
CREATE ROLE rol_admin;
CREATE ROLE rol_comercial;
CREATE ROLE rol_mecanico;
CREATE ROLE rol_ia_servicio;
GO

-- E: usuarios sin inicio de sesión (no hay contraseñas); los comerciales se llaman como usuario_bd
CREATE USER admin_demo       WITHOUT LOGIN;
CREATE USER comercial_ana    WITHOUT LOGIN;
CREATE USER comercial_luis   WITHOUT LOGIN;
CREATE USER comercial_marta  WITHOUT LOGIN;
CREATE USER comercial_javier WITHOUT LOGIN;
CREATE USER mecanico_demo    WITHOUT LOGIN;
CREATE USER ia_servicio      WITHOUT LOGIN;
GO
ALTER ROLE rol_admin       ADD MEMBER admin_demo;
ALTER ROLE rol_comercial   ADD MEMBER comercial_ana;
ALTER ROLE rol_comercial   ADD MEMBER comercial_luis;
ALTER ROLE rol_comercial   ADD MEMBER comercial_marta;
ALTER ROLE rol_comercial   ADD MEMBER comercial_javier;
ALTER ROLE rol_mecanico    ADD MEMBER mecanico_demo;
ALTER ROLE rol_ia_servicio ADD MEMBER ia_servicio;
GO

-- F: administrador · control total de la base, incluido ver datos sin máscara
GRANT CONTROL ON DATABASE::BajoElCapoDB TO rol_admin;
GRANT UNMASK TO rol_admin;
GO

-- G: comercial · catálogo sin precio de compra, averías, sus reservas y clientes (RLS), y procedimientos
GRANT SELECT  ON catalogo.vw_catalogo           TO rol_comercial;
GRANT SELECT  ON taller.vw_averias_por_modelo   TO rol_comercial;
GRANT SELECT  ON taller.fn_averias_modelo       TO rol_comercial;
GRANT EXECUTE ON taller.fn_coste_esperado       TO rol_comercial;
GRANT SELECT  ON ventas.vw_reservas             TO rol_comercial;
GRANT SELECT, INSERT, UPDATE ON ventas.Clientes TO rol_comercial;
GRANT EXECUTE ON ventas.sp_registrar_reserva    TO rol_comercial;
GRANT EXECUTE ON ventas.sp_registrar_venta      TO rol_comercial;
GRANT EXECUTE ON SCHEMA::ia                     TO rol_comercial;   -- buscador y asesor (004 y 005)
GO

-- H: mecánico · modelos y averías; nada del esquema ventas
GRANT SELECT  ON catalogo.vw_catalogo           TO rol_mecanico;
GRANT SELECT  ON taller.vw_averias_por_modelo   TO rol_mecanico;
GRANT SELECT  ON taller.fn_averias_modelo       TO rol_mecanico;
GRANT EXECUTE ON taller.fn_coste_esperado       TO rol_mecanico;
GRANT EXECUTE ON SCHEMA::ia                     TO rol_mecanico;    -- asesor de averías (005)
DENY  SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::ventas TO rol_mecanico;
GO

-- I: servicio de IA · solo lectura del contexto; ni datos de ventas ni escrituras
--    (los permisos del modelo externo se conceden en ai/create_external_model.sql)
GRANT SELECT ON catalogo.vw_catalogo         TO rol_ia_servicio;
GRANT SELECT ON taller.vw_averias_por_modelo TO rol_ia_servicio;
DENY  SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::ventas TO rol_ia_servicio;
DENY  INSERT, UPDATE, DELETE ON SCHEMA::catalogo TO rol_ia_servicio;
DENY  INSERT, UPDATE, DELETE ON SCHEMA::taller   TO rol_ia_servicio;
GO

-- -----------------------------------------------------------------------------
-- Mecanismo 2: Row-Level Security
-- -----------------------------------------------------------------------------

-- J: predicado · la fila pasa si es del comercial conectado, o si es administrador o db_owner
CREATE OR ALTER FUNCTION seg.fn_predicado_comercial (@comercial_id INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS permitido
    FROM ventas.Comerciales AS c
    WHERE c.comercial_id = @comercial_id
      AND c.usuario_bd   = USER_NAME()
    UNION ALL
    SELECT 1
    WHERE IS_MEMBER(N'rol_admin') = 1 OR IS_MEMBER(N'db_owner') = 1;
GO

-- K: política · FILTER oculta filas ajenas; BLOCK impide crear o mover filas a otro comercial
CREATE SECURITY POLICY seg.politica_comerciales
    ADD FILTER PREDICATE seg.fn_predicado_comercial(comercial_id) ON ventas.Clientes,
    ADD BLOCK  PREDICATE seg.fn_predicado_comercial(comercial_id) ON ventas.Clientes AFTER INSERT,
    ADD BLOCK  PREDICATE seg.fn_predicado_comercial(comercial_id) ON ventas.Clientes AFTER UPDATE,
    ADD FILTER PREDICATE seg.fn_predicado_comercial(comercial_id) ON ventas.Reservas,
    ADD BLOCK  PREDICATE seg.fn_predicado_comercial(comercial_id) ON ventas.Reservas AFTER INSERT,
    ADD BLOCK  PREDICATE seg.fn_predicado_comercial(comercial_id) ON ventas.Reservas AFTER UPDATE
WITH (STATE = ON);
GO

-- -----------------------------------------------------------------------------
-- Mecanismo 3: Dynamic Data Masking
-- -----------------------------------------------------------------------------

-- L: email y teléfono enmascarados para quien no tiene UNMASK (solo rol_admin y db_owner lo tienen)
ALTER TABLE ventas.Clientes ALTER COLUMN email    ADD MASKED WITH (FUNCTION = 'email()');
ALTER TABLE ventas.Clientes ALTER COLUMN telefono ADD MASKED WITH (FUNCTION = 'partial(0,"XXX-XXX-",3)');
GO

-- M: resumen de lo creado
SELECT r.name AS rol, STRING_AGG(m.name, N', ') AS miembros
FROM sys.database_role_members AS rm
JOIN sys.database_principals   AS r ON r.principal_id = rm.role_principal_id
JOIN sys.database_principals   AS m ON m.principal_id = rm.member_principal_id
WHERE r.name LIKE N'rol[_]%'
GROUP BY r.name
ORDER BY r.name;
GO

PRINT N'Seguridad configurada: 4 roles, 7 usuarios sin login, RLS y DDM.';
GO
