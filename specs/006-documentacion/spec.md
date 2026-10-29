# Feature Specification: Documentación final

**Feature Branch**: `006-documentacion`

**Created**: 2026-10-29

**Status**: Implemented

**Input**: User description: bloque «Entrada para specify» de `docs/prompts/006-documentacion.md`
(README reproducible e informe técnico para exportar a PDF).

## Clarifications

### Session 2026-10-29

- Q: No existe `docs/notas-instalacion-ia.md`; ¿de dónde sale la instalación de Ollama y Caddy?
  → A: de lo que hay en el repositorio (`tests/test_conexion_ia.sql`, el Caddyfile mínimo de
  `docs/prompts/006-documentacion.md` y las versiones medidas en el equipo). El alumno la revisa
  contra sus notas reales (decisión D07).
- Q: ¿Qué enlace al repositorio va en la portada? → A: un marcador que rellena el alumno al crear
  el repositorio en GitHub (no hay remoto `origin`).
- Q: ¿Dónde va la «Estrategia de pruebas» del informe sin romper el orden de las 12 secciones?
  → A: como subapartado de la sección 6 (Funcionalidades implementadas).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Reproducir el proyecto (Priority: P1)

Como estudiante, descargo el repositorio y, siguiendo el README, instalo los requisitos (incluidos
Ollama y Caddy), creo la base y reproduzco todas las funcionalidades.

**Independent Test**: seguir la instalación del README en orden y llegar a «RESULTADO: todos los
scripts y tests terminaron sin errores» con `run_all.ps1 -ConIA`.

### User Story 2 - Evaluar (Priority: P1)

Como profesor, encuentro en el README y en el informe cada requisito del enunciado con su evidencia.

**Independent Test**: la tabla de cumplimiento enlaza una evidencia para cada apartado del 3 al 18.

### Edge Cases

- Ningún documento contiene IPs, rutas absolutas personales, secretos ni el nombre de la instancia.
- Todas las cifras proceden de `docs/evidencias/`.

## Requirements *(mandatory)*

- **FR-001**: README con las secciones del apartado 12 y el nivel 3.
- **FR-002**: Instalación con Ollama, Caddy, `run_all.ps1` con y sin `-ConIA` y las dos vías de IA.
- **FR-003**: `docs/proyecto.md` con las 12 secciones del apartado 13 y marcadores `[CAPTURA: …]`.
- **FR-004**: `docs/bloque-b.md` con al menos 3 casos completos.
- **FR-005**: Tabla de cumplimiento de los apartados 3 a 18 con enlace a la evidencia.
- **FR-006**: Sección «Estrategia de pruebas» en el README y en el informe.

## Success Criteria *(mandatory)*

- **SC-001**: El 100 % de los apartados 3–18 del enunciado tienen una evidencia enlazada.
- **SC-002**: Ninguna cifra de los documentos falta en `docs/evidencias/`.
- **SC-003**: La búsqueda de IPs, rutas absolutas y secretos no da resultados indebidos.

## Assumptions

- La presentación y la exportación a PDF las hace el alumno.
