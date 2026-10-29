# Feature Specification: Buscador semántico de coches

**Feature Branch**: `004-busqueda-semantica`

**Created**: 2026-10-29

**Status**: Implemented

**Input**: User description: bloque «Entrada para specify» de `docs/prompts/004-busqueda-semantica.md`
(buscador de coches en lenguaje natural, por significado y no por palabras).

## Clarifications

### Session 2026-10-29

- Q: ¿Qué tres frases de prueba se usan? → A: (1) «familiar, económico y fiable para ciudad y
  escapadas» con precio máximo 14.000 €; (2) «coche cómodo para viajes largos por autopista»;
  (3) «aventura por caminos de tierra y fines de semana en el campo» limitada al segmento SUV.
  Cubren los tres filtros (precio, segmento y número de resultados).
- Q: ¿Cómo usan comerciales y mecánicos el buscador sin permisos sobre el modelo externo? → A: el
  procedimiento de la vía SSMS se ejecuta con el contexto del usuario de servicio de IA (decidido
  en la propuesta, apartado 7).
- Q: ¿Qué pasa si el servicio de IA no responde? → A: error controlado con un código 503xx; la
  generación de embeddings trabaja por lotes, así que lo ya procesado se conserva y una nueva
  ejecución continúa desde donde quedó.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Buscar por significado (Priority: P1)

Como comercial, escribo una frase como «familiar, económico y fiable para ciudad y escapadas» y
obtengo un ranking de coches disponibles parecidos en significado, aunque la descripción no use
esas palabras.

**Independent Test**: la frase devuelve un ranking con posición, distancia, marca, modelo, precio y
descripción, solo de coches disponibles.

**Acceptance Scenarios**:

1. **Given** todos los coches con su representación vectorial, **When** busco una frase, **Then**
   obtengo los coches más parecidos ordenados de más a menos parecido.
2. **Given** una búsqueda, **When** reviso los resultados, **Then** todos están disponibles.

### User Story 2 - Filtros (Priority: P2)

Como comercial, limito el resultado por precio máximo, segmento y número de resultados.

### User Story 3 - Dos vías (Priority: P1)

Como alumno, hago la misma búsqueda desde SSMS y desde la terminal, y obtengo el mismo top.

### User Story 4 - Contraste con palabras clave (Priority: P2)

Como alumno, demuestro la diferencia con la búsqueda por palabras clave de `08` (bloque E2).

### Edge Cases

- El servicio de IA no responde: error claro (503xx) y la base de datos queda coherente.
- Filtros que no dejan ningún coche: ranking vacío, sin error.

## Requirements *(mandatory)*

- **FR-001**: Todos los coches y averías tienen un vector de 1024 dimensiones.
- **FR-002**: Queda documentado el modelo, las columnas que forman el texto, la dimensión, y cómo
  se generan y guardan los vectores.
- **FR-003**: El ranking muestra posición, distancia coseno, marca, modelo, precio y descripción,
  solo de coches disponibles.
- **FR-004**: Una única lógica de ranking sirve a las dos vías.
- **FR-005**: La métrica de similitud está justificada.
- **FR-006**: Los errores del servicio de IA se controlan con un mensaje claro.

## Success Criteria *(mandatory)*

- **SC-001**: El 100 % de los coches y averías tienen un vector de 1024 dimensiones.
- **SC-002**: Las tres frases de prueba devuelven resultados coherentes con su intención.
- **SC-003**: Para cada frase, las dos vías devuelven los mismos coches en el mismo orden.

## Assumptions

- Ollama (bge-m3) y Caddy están en marcha, verificados en la fase 0.
- El volumen (228 coches) permite búsqueda exacta; el índice vectorial queda como mejora.
