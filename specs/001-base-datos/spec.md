# Feature Specification: Base de datos del concesionario

**Feature Branch**: `001-base-datos`

**Created**: 2026-10-29

**Status**: Implemented

**Input**: User description: bloque «Entrada para specify» de `docs/prompts/001-base-datos.md`
(base de datos del concesionario de coches de segunda mano Bajo el Capó, base del buscador
semántico y del asesor de averías).

## Clarifications

### Session 2026-10-29

Respondidas por el agente con las fuentes (CLAUDE.md, modo autónomo):

- Q: ¿Qué volumen de datos de prueba se usa, el de la propuesta (40–60 coches) o el de `03`?
  → A: El de `03_insert_data.sql` (228 coches, 24 clientes, 44 reservas). El enunciado pide
  «datos suficientes» y CLAUDE.md prohíbe regenerar `03`. Registrado en `docs/decisiones.md`.
- Q: ¿Qué modelo es el caso de control sin averías? → A: Dacia Jogger.
- Q: ¿Qué error devuelve la doble reserva? → A: 50102 («El vehículo no está disponible»).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Catálogo sin precio de compra (Priority: P1)

Como comercial, consulto el catálogo de coches disponibles con marca, modelo, segmento, precio y
descripción, sin ver nunca el precio de compra.

**Why this priority**: es la base del buscador y del día a día comercial.

**Independent Test**: consultar la vista del catálogo y comprobar que devuelve filas y que no
tiene columna de precio de compra.

**Acceptance Scenarios**:

1. **Given** la base cargada, **When** consulto el catálogo filtrando por disponibles, **Then**
   obtengo coches con marca, modelo, segmento, precio de venta y descripción.
2. **Given** el catálogo, **When** reviso sus columnas, **Then** no aparece el precio de compra.

---

### User Story 2 - Averías por modelo con riesgo (Priority: P1)

Como mecánico, veo las averías conocidas de cada modelo con su frecuencia, su gravedad y un nivel
de riesgo.

**Why this priority**: es el conocimiento que usará el asesor de averías (RAG).

**Independent Test**: consultar la vista de averías por modelo y comprobar riesgo = frecuencia ×
gravedad.

**Acceptance Scenarios**:

1. **Given** un modelo con averías, **When** consulto sus averías, **Then** veo frecuencia,
   gravedad y riesgo entre 1 y 25.
2. **Given** el Dacia Jogger, **When** consulto sus averías, **Then** no hay ninguna.

---

### User Story 3 - Reserva sin conflictos (Priority: P1)

Como comercial, reservo un coche para un cliente sin que otro comercial pueda reservarlo a la vez.

**Why this priority**: integridad del negocio.

**Independent Test**: reservar un coche disponible y volver a reservarlo.

**Acceptance Scenarios**:

1. **Given** un coche disponible, **When** lo reservo, **Then** se crea la reserva y el coche pasa a
   Reservado.
2. **Given** un coche reservado, **When** otro intenta reservarlo, **Then** recibe un error
   controlado (50102) y no se crea nada.

---

### User Story 4 - Cierre de venta (Priority: P2)

Como comercial, cierro la venta de una reserva activa con un precio final válido.

**Independent Test**: vender una reserva activa con precio válido y comprobar que el coche pasa a
Vendido; un precio superior al de venta se rechaza.

**Acceptance Scenarios**:

1. **Given** una reserva activa, **When** registro la venta con precio entre 0 y el precio de venta,
   **Then** se crea la venta, la reserva pasa a Vendida y el coche a Vendido.
2. **Given** una reserva activa, **When** el precio supera el de venta, **Then** error 50113.

---

### User Story 5 - Coste de mantenimiento por marca (Priority: P2)

Como responsable, sé qué modelos cuestan más de mantener que la media de su marca.

**Independent Test**: ejecutar la consulta correlacionada de `08` y obtener filas.

---

### User Story 6 - Consultas avanzadas (Priority: P2)

Como analista, dispongo de: las 3 averías más frecuentes por modelo, precio frente a la media del
segmento, coches con un extra concreto (isofix), validación de teléfonos y búsqueda por palabras
clave.

**Independent Test**: ejecutar `08_advanced_queries.sql` y obtener resultados con sentido.

---

### User Story 7 - Recrear y comprobar con un comando (Priority: P1)

Como alumno, recreo toda la base desde cero con un único comando y compruebo automáticamente que
es correcta.

**Independent Test**: ejecutar `run_all.ps1` y ver todos los bloques de tests en verde.

### Edge Cases

- Reservar un coche inexistente → 50101; cliente inexistente → 50103.
- Vender una reserva no activa → 50112; inexistente → 50111.
- Ejecutar `03` sobre una base con datos → 50090 (protección).
- Cancelar una reserva → el coche vuelve a Disponible (trigger).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 9 tablas relacionadas con PK, FK, CHECK, UNIQUE y DEFAULT; relaciones 1:N, N:M
  (ModeloAveria) y 1:1 (Reservas–Ventas).
- **FR-002**: Datos de prueba exactos: 8 marcas, 24 modelos, 228 vehículos, 57 averías,
  207 relaciones modelo-avería, 4 comerciales, 24 clientes, 44 reservas y 16 ventas.
- **FR-003**: Al menos un modelo sin averías (Dacia Jogger).
- **FR-004**: Equipamiento en JSON con lista de extras; algunos coches con «isofix».
- **FR-005**: Algunos teléfonos con formato a normalizar.
- **FR-006**: El catálogo no expone el precio de compra.
- **FR-007**: Reservar un coche no disponible devuelve un error controlado; el estado del coche
  cambia solo al reservar, cancelar o vender.
- **FR-008**: Las consultas avanzadas (CTE, window functions, correlacionada, JSON, regex)
  devuelven resultados.
- **FR-009**: Un solo comando recrea la base y ejecuta los tests, deteniéndose en el primer error.

### Key Entities

- **Marca, Modelo, Vehículo**: catálogo; un vehículo tiene descripción comercial y equipamiento.
- **Avería, ModeloAvería**: averías conocidas y su frecuencia/gravedad por modelo.
- **Comercial, Cliente, Reserva, Venta**: ciclo comercial; cada cliente pertenece a un comercial.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El comando único termina sin errores y el 100 % de los bloques de tests pasan.
- **SC-002**: Los 9 recuentos coinciden exactamente con FR-002.
- **SC-003**: La doble reserva se rechaza en el 100 % de los intentos con el error 50102.
- **SC-004**: Las 7 consultas avanzadas devuelven al menos una fila.

## Assumptions

- `01` y `02` están validados por el alumno y no se modifican.
- `03` no se regenera; si falla se corrige lo mínimo y se registra en el bloque B.
- Seguridad (002), optimización (003) e IA (004–005) quedan fuera de esta feature.
