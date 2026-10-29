/* =============================================================================
   Proyecto   : Bajo el Capó · DP-800 (Microsoft SQL AI Developer Associate)
   Script     : database/02_create_tables.sql
   Objetivo   : Crea las 9 tablas con sus claves, restricciones e índices.
   Requisitos : BD recién creada con 01_create_database.sql (no es repetible
                por sí solo: fallaría al encontrar las tablas ya creadas).
   Ejecución  : SSMS 22, o
                sqlcmd -S localhost -d BajoElCapoDB -E -C -b -i database\02_create_tables.sql
   Siguiente  : 03_insert_data.sql
   Autor      : Emmanuel Grande Sierra
   ============================================================================= */

USE BajoElCapoDB;
GO

-- -----------------------------------------------------------------------------
-- Catálogo de vehículos
-- -----------------------------------------------------------------------------

-- A: marcas; relación 1:N con modelos
CREATE TABLE catalogo.Marcas (
    marca_id INT IDENTITY(1,1) CONSTRAINT pk_marcas PRIMARY KEY,
    nombre   NVARCHAR(50) NOT NULL CONSTRAINT uq_marcas_nombre UNIQUE,
    pais     NVARCHAR(50) NOT NULL
);

-- B: modelos de cada marca; anio_fin NULL indica que sigue en producción
CREATE TABLE catalogo.Modelos (
    modelo_id   INT IDENTITY(1,1) CONSTRAINT pk_modelos PRIMARY KEY,
    marca_id    INT NOT NULL CONSTRAINT fk_modelos_marca REFERENCES catalogo.Marcas(marca_id),
    nombre      NVARCHAR(60) NOT NULL,
    segmento    NVARCHAR(20) NOT NULL
        CONSTRAINT ck_modelos_segmento CHECK (segmento IN
            (N'Utilitario', N'Compacto', N'Berlina', N'Familiar', N'SUV', N'Monovolumen', N'Deportivo')),
    anio_inicio SMALLINT NOT NULL,
    anio_fin    SMALLINT NULL,
    CONSTRAINT ck_modelos_anios CHECK (anio_fin IS NULL OR anio_fin >= anio_inicio),
    CONSTRAINT uq_modelos_marca_nombre UNIQUE (marca_id, nombre)
);

-- C: vehículos en stock; matrícula validada con regex y embedding del texto comercial
CREATE TABLE catalogo.Vehiculos (
    vehiculo_id   INT IDENTITY(1,1) CONSTRAINT pk_vehiculos PRIMARY KEY,
    modelo_id     INT NOT NULL CONSTRAINT fk_vehiculos_modelo REFERENCES catalogo.Modelos(modelo_id),
    matricula     CHAR(7) NOT NULL CONSTRAINT uq_vehiculos_matricula UNIQUE,
    anio          SMALLINT NOT NULL CONSTRAINT ck_vehiculos_anio CHECK (anio BETWEEN 1990 AND 2027),
    kilometros    INT NOT NULL CONSTRAINT ck_vehiculos_km CHECK (kilometros >= 0),
    combustible   NVARCHAR(15) NOT NULL
        CONSTRAINT ck_vehiculos_combustible CHECK (combustible IN
            (N'Gasolina', N'Diésel', N'Híbrido', N'Eléctrico', N'GLP')),
    precio_venta  DECIMAL(10,2) NOT NULL CONSTRAINT ck_vehiculos_pventa CHECK (precio_venta > 0),
    precio_compra DECIMAL(10,2) NOT NULL CONSTRAINT ck_vehiculos_pcompra CHECK (precio_compra > 0),
    descripcion   NVARCHAR(1000) NOT NULL,
    equipamiento  JSON NULL,                            -- extras del coche en formato JSON
    estado        NVARCHAR(12) NOT NULL CONSTRAINT df_vehiculos_estado DEFAULT N'Disponible'
        CONSTRAINT ck_vehiculos_estado CHECK (estado IN (N'Disponible', N'Reservado', N'Vendido')),
    fecha_alta    DATE NOT NULL CONSTRAINT df_vehiculos_alta DEFAULT (CAST(SYSDATETIME() AS DATE)),
    embedding     VECTOR(1024) NULL,                    -- 1024 = dimensión del modelo bge-m3
    CONSTRAINT ck_vehiculos_matricula
        CHECK (REGEXP_LIKE(matricula, '^[0-9]{4}[BCDFGHJKLMNPRSTVWXYZ]{3}$'))
);

-- -----------------------------------------------------------------------------
-- Averías conocidas
-- -----------------------------------------------------------------------------

-- D: catálogo de averías; el embedding se calcula con título, síntoma, causa y solución
CREATE TABLE taller.Averias (
    averia_id      INT IDENTITY(1,1) CONSTRAINT pk_averias PRIMARY KEY,
    titulo         NVARCHAR(120) NOT NULL CONSTRAINT uq_averias_titulo UNIQUE,
    sintoma        NVARCHAR(500) NOT NULL,
    causa          NVARCHAR(500) NOT NULL,
    solucion       NVARCHAR(500) NOT NULL,
    coste_estimado DECIMAL(8,2) NOT NULL CONSTRAINT ck_averias_coste CHECK (coste_estimado >= 0),
    embedding      VECTOR(1024) NULL
);

-- E: tabla puente N:M entre modelos y averías, con frecuencia y gravedad (1 a 5)
CREATE TABLE taller.ModeloAveria (
    modelo_id  INT NOT NULL CONSTRAINT fk_ma_modelo REFERENCES catalogo.Modelos(modelo_id),
    averia_id  INT NOT NULL CONSTRAINT fk_ma_averia REFERENCES taller.Averias(averia_id),
    frecuencia TINYINT NOT NULL CONSTRAINT ck_ma_frecuencia CHECK (frecuencia BETWEEN 1 AND 5),
    gravedad   TINYINT NOT NULL CONSTRAINT ck_ma_gravedad CHECK (gravedad BETWEEN 1 AND 5),
    CONSTRAINT pk_modeloaveria PRIMARY KEY (modelo_id, averia_id)
);

-- -----------------------------------------------------------------------------
-- Ventas
-- -----------------------------------------------------------------------------

-- F: comerciales; usuario_bd es el nombre de su usuario en la BD (lo usa Row-Level Security)
CREATE TABLE ventas.Comerciales (
    comercial_id INT IDENTITY(1,1) CONSTRAINT pk_comerciales PRIMARY KEY,
    nombre       NVARCHAR(80) NOT NULL,
    usuario_bd   SYSNAME NOT NULL CONSTRAINT uq_comerciales_usuario UNIQUE
);

-- G: clientes asignados a cada comercial; email validado con regex
CREATE TABLE ventas.Clientes (
    cliente_id   INT IDENTITY(1,1) CONSTRAINT pk_clientes PRIMARY KEY,
    comercial_id INT NOT NULL CONSTRAINT fk_clientes_comercial REFERENCES ventas.Comerciales(comercial_id),
    nombre       NVARCHAR(100) NOT NULL,
    email        NVARCHAR(120) NOT NULL
        CONSTRAINT ck_clientes_email CHECK (REGEXP_LIKE(email, '^[^@\s]+@[^@\s]+\.[^@\s]+$')),
    telefono     NVARCHAR(20) NULL
);

-- H: reservas; el índice único filtrado impide dos reservas activas sobre el mismo coche
CREATE TABLE ventas.Reservas (
    reserva_id   INT IDENTITY(1,1) CONSTRAINT pk_reservas PRIMARY KEY,
    vehiculo_id  INT NOT NULL CONSTRAINT fk_reservas_vehiculo REFERENCES catalogo.Vehiculos(vehiculo_id),
    cliente_id   INT NOT NULL CONSTRAINT fk_reservas_cliente REFERENCES ventas.Clientes(cliente_id),
    comercial_id INT NOT NULL CONSTRAINT fk_reservas_comercial REFERENCES ventas.Comerciales(comercial_id),
    fecha        DATETIME2(0) NOT NULL CONSTRAINT df_reservas_fecha DEFAULT SYSDATETIME(),
    estado       NVARCHAR(12) NOT NULL CONSTRAINT df_reservas_estado DEFAULT N'Activa'
        CONSTRAINT ck_reservas_estado CHECK (estado IN (N'Activa', N'Cancelada', N'Vendida'))
);
CREATE UNIQUE INDEX ux_reserva_activa ON ventas.Reservas (vehiculo_id) WHERE estado = N'Activa';

-- I: ventas cerradas; relación 1:1 con la reserva que las origina
CREATE TABLE ventas.Ventas (
    venta_id     INT IDENTITY(1,1) CONSTRAINT pk_ventas PRIMARY KEY,
    reserva_id   INT NOT NULL CONSTRAINT uq_ventas_reserva UNIQUE
        CONSTRAINT fk_ventas_reserva REFERENCES ventas.Reservas(reserva_id),
    fecha        DATE NOT NULL CONSTRAINT df_ventas_fecha DEFAULT (CAST(SYSDATETIME() AS DATE)),
    precio_final DECIMAL(10,2) NOT NULL CONSTRAINT ck_ventas_precio CHECK (precio_final > 0)
);

-- -----------------------------------------------------------------------------
-- Índices
-- -----------------------------------------------------------------------------

-- J: índices de apoyo a las claves foráneas (el de optimización se crea más adelante,
--    en 07_indexes.sql, para poder medir el rendimiento antes y después)
CREATE INDEX ix_modelos_marca      ON catalogo.Modelos (marca_id);
CREATE INDEX ix_vehiculos_modelo   ON catalogo.Vehiculos (modelo_id);
CREATE INDEX ix_ma_averia          ON taller.ModeloAveria (averia_id);
CREATE INDEX ix_clientes_comercial ON ventas.Clientes (comercial_id);
CREATE INDEX ix_reservas_cliente   ON ventas.Reservas (cliente_id);
CREATE INDEX ix_reservas_comercial ON ventas.Reservas (comercial_id);
GO

PRINT N'9 tablas creadas correctamente.';
GO