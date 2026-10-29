# Feature Specification: Asesor de averías con RAG

**Feature Branch**: `005-rag`

**Created**: 2026-10-29

**Status**: Implemented

**Input**: User description: bloque «Entrada para specify» de `docs/prompts/005-rag.md` (responder
preguntas sobre las averías de un modelo usando solo los datos recuperados de la base de datos).

## Clarifications

### Session 2026-10-29

- Q: ¿Qué preguntas de prueba se usan? → A: (1) «¿Qué averías suele tener y cuánto cuesta
  repararlas?» sobre el Peugeot 308 SW; (2) «Al acelerar noto tirones y el embrague patina, ¿qué
  puede ser y cuánto cuesta arreglarlo?» sin indicar modelo (recuperación general); (3) caso de
  control: la pregunta 1 sobre el Dacia Jogger, que no tiene averías registradas.
- Q: ¿Cómo se garantiza que las dos vías envían lo mismo al modelo? → A: el contexto y el prompt
  de sistema se construyen en SQL Server con funciones compartidas; la vía terminal los recibe ya
  construidos y solo hace las llamadas a Ollama.
- Q: ¿Qué criterio automático se usa para el caso de control? → A: la respuesta no menciona ningún
  título de avería de la base de datos y expresa que no hay datos (contiene «no» y «datos»,
  «información» o «registr»).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Preguntar por las averías de un modelo (Priority: P1)

Como comprador (a través del comercial), pregunto qué averías suele tener un modelo y cuánto
cuestan, y recibo una respuesta basada en las averías registradas, con su coste estimado.

**Acceptance Scenarios**:

1. **Given** un modelo con averías, **When** pregunto, **Then** la respuesta solo cita averías y
   costes presentes en los documentos recuperados.

### User Story 2 - Ver las cuatro partes (Priority: P1)

Como alumno, veo la pregunta, los documentos recuperados, el contexto enviado al modelo y la
respuesta final.

### User Story 3 - Caso de control (Priority: P1)

Como alumno, pregunto por un modelo sin averías registradas y el asistente dice que no tiene datos
en lugar de inventarlos.

### User Story 4 - Dos vías (Priority: P2)

Como alumno, uso el asesor desde SSMS y desde la terminal.

### User Story 5 - LLM frente a RAG (Priority: P3)

Como alumno, explico la diferencia entre un LLM solo y el RAG (base de datos + búsqueda vectorial
+ contexto + LLM). Se documenta en el README y en el informe.

### Edge Cases

- Modelo que no existe: error controlado.
- Fallo del servicio de IA: mensaje claro con código 503xx.

## Requirements *(mandatory)*

- **FR-001**: Recuperación por similitud de las averías más cercanas a la pregunta, limitada al
  modelo si se indica, y de coches disponibles similares.
- **FR-002**: Contexto con título, síntoma, solución, coste estimado, frecuencia, gravedad y riesgo.
- **FR-003**: Prompt restrictivo y temperatura 0.
- **FR-004**: Cuatro partes visibles en las dos vías, con el mismo contexto y el mismo prompt.
- **FR-005**: Comerciales y mecánicos usan el asesor sin permisos directos sobre el modelo.
- **FR-006**: El caso de control llama igualmente al modelo con el contexto sin averías.

## Success Criteria *(mandatory)*

- **SC-001**: Dos preguntas válidas y el caso de control funcionan por las dos vías.
- **SC-002**: La respuesta del caso de control no cita ninguna avería.
- **SC-003**: Las dos vías envían al modelo exactamente el mismo contexto.

## Assumptions

- qwen2.5:3b en Ollama (decisión D01). Si se desvía del contexto, se endurece el prompt antes de
  cambiar de modelo.
