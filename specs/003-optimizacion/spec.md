# Feature Specification: Optimización del listado del catálogo

**Feature Branch**: `003-optimizacion`

**Created**: 2026-10-29

**Status**: Implemented

**Input**: User description: bloque «Entrada para specify» de `docs/prompts/003-optimizacion.md`
(optimizar el listado de coches de un estado, un segmento y un rango de precio, con marca y modelo).

## Clarifications

### Session 2026-10-29

- Q: ¿Qué filtros concretos usa la consulta de referencia? → A: estado «Disponible», segmento
  «SUV» y precio entre 10.000 y 15.000 €, ordenado por precio (caso típico de un comercial).
- Q: ¿Índice compuesto o filtrado? → A: compuesto sobre los filtros del propio coche (estado y
  precio) con columnas incluidas para cubrir la consulta; el segmento está en la tabla de modelos
  (24 filas) y no puede ir en un índice de vehículos.
- Q: ¿Cómo se capturan los planes reales? → A: con un script de medición reproducible
  (`tests/medir_optimizacion.ps1`) que ejecuta los mismos bloques de `07` en una sola conexión.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Listado rápido con mucho stock (Priority: P1)

Como comercial, quiero que el listado filtrado responda rápido aunque haya muchos coches.

**Independent Test**: con unos 50.000 coches cargados, la consulta lee menos páginas después de la
mejora que antes.

**Acceptance Scenarios**:

1. **Given** unos 50.000 coches, **When** ejecuto el listado sin la mejora, **Then** se recorre toda
   la tabla de vehículos.
2. **Given** la mejora aplicada, **When** ejecuto el mismo listado, **Then** se accede solo al rango
   de coches que cumplen los filtros y bajan las lecturas.

### User Story 2 - Medir y explicar (Priority: P1)

Como alumno, mido la consulta antes y después y explico por qué mejora o no.

**Independent Test**: existe una tabla antes/después con valores reales (operador, coste, lecturas,
CPU y tiempo) y los planes de ejecución reales guardados.

### Edge Cases

- Re-ejecutar el script no deja datos de carga ni duplica el índice.
- Las features siguientes trabajan con los 228 coches originales.

## Requirements *(mandatory)*

- **FR-001**: Carga temporal de unos 50.000 vehículos válidos e identificables.
- **FR-002**: Medición antes y después con plan real, tipo de acceso, coste, lecturas lógicas y tiempo.
- **FR-003**: Mejora mediante un índice compuesto o filtrado, justificada por los filtros.
- **FR-004**: Tabla comparativa con valores reales y explicación.
- **FR-005**: Al terminar, los datos de carga se borran y el índice se mantiene.

## Success Criteria *(mandatory)*

- **SC-001**: Las lecturas lógicas sobre vehículos bajan después de la mejora.
- **SC-002**: El tipo de acceso pasa de recorrido completo a búsqueda por rango.
- **SC-003**: Tras el script vuelve a haber exactamente 228 coches.

## Assumptions

- Se compara la segunda ejecución de cada consulta, con la caché caliente en ambos casos.
- Los tiempos dependen del equipo; lo comparable son las lecturas y el plan.
