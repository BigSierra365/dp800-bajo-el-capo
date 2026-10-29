# Feature Specification: Seguridad por perfiles

**Feature Branch**: `002-seguridad`

**Created**: 2026-10-29

**Status**: Implemented

**Input**: User description: bloque «Entrada para specify» de `docs/prompts/002-seguridad.md`
(cada perfil ve y hace solo lo que necesita).

## Clarifications

### Session 2026-10-29

Respondidas por el agente con las fuentes:

- Q: Los cuatro comerciales tienen 6 clientes cada uno; ¿con qué consulta se demuestra «número de
  filas distinto»? → A: con sus reservas (7, 8, 15 y 14 según `03`); los clientes demuestran que
  cada uno ve solo los suyos (6 de 24).
- Q: ¿Cómo se deniega `ia.sp_generar_embeddings` si se crea en la feature 004? → A: el DENY se
  emite en `ai/generate_embeddings.sql` justo después de crear el procedimiento; `06` concede
  `EXECUTE ON SCHEMA::ia`, que cubre los procedimientos futuros.
- Q: ¿El mecánico puede ver el catálogo? → A: sí, la vista `vw_catalogo` (sin precio de compra);
  necesita modelos y averías y la vista no expone datos de clientes ni márgenes.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Cada comercial ve solo lo suyo (Priority: P1)

Como comercial, solo veo mis clientes y mis reservas.

**Independent Test**: la misma consulta de reservas ejecutada por dos comerciales devuelve un
número de filas distinto, y la de clientes solo devuelve los suyos.

**Acceptance Scenarios**:

1. **Given** dos comerciales, **When** consultan las reservas, **Then** cada uno ve solo las suyas.
2. **Given** un comercial, **When** reserva un coche para un cliente de otro comercial, **Then** el
   cliente «no existe» para él (50103) y no se crea nada.
3. **Given** un comercial, **When** reserva para un cliente suyo, **Then** la reserva se crea.

### User Story 2 - Datos de contacto enmascarados (Priority: P1)

Como comercial, veo el email y el teléfono de los clientes enmascarados; el administrador los ve
completos.

**Independent Test**: comparar la misma consulta como comercial y como administrador.

### User Story 3 - El mecánico no ve datos comerciales (Priority: P1)

Como mecánico, si consulto clientes o reservas recibo un permiso denegado.

**Independent Test**: consulta a clientes como mecánico → error de permiso.

### User Story 4 - Demostración reproducible (Priority: P2)

Como alumno, ejecuto una demostración con las mismas consultas para distintos usuarios.

### Edge Cases

- Re-ejecutar el script de seguridad no falla (idempotente).
- El comercial intenta leer el precio de compra en la tabla de vehículos → permiso denegado.
- El servicio de IA no puede leer clientes.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Cuatro roles: administrador, comercial, mecánico y servicio de IA.
- **FR-002**: Usuarios de demostración sin inicio de sesión (sin contraseñas).
- **FR-003**: Acceso por vistas y procedimientos; sin acceso directo a las tablas de vehículos.
- **FR-004**: Filtrado por filas: cada comercial solo ve y modifica sus clientes y reservas.
- **FR-005**: Email y teléfono enmascarados para quien no tenga permiso de desenmascarar.
- **FR-006**: El mecánico y el servicio de IA no acceden a los datos de ventas.
- **FR-007**: Los procedimientos de reserva y venta siguen funcionando para el comercial.
- **FR-008**: Comerciales y mecánicos podrán ejecutar los procedimientos de IA sin permisos sobre
  el modelo externo.

## Success Criteria *(mandatory)*

- **SC-001**: Al menos tres mecanismos de seguridad demostrados (permisos, filas, máscaras).
- **SC-002**: Dos comerciales obtienen un número distinto de reservas con la misma consulta.
- **SC-003**: El 100 % de los intentos del mecánico sobre clientes o reservas se deniegan.
- **SC-004**: El script se ejecuta dos veces seguidas sin errores.

## Assumptions

- Los nombres de usuario de los comerciales coinciden con `ventas.Comerciales.usuario_bd`.
- `dbo` (quien ejecuta `run_all.ps1`) es miembro de `db_owner` y ve todos los datos.
