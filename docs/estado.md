# Estado del proyecto

| Campo | Valor |
| --- | --- |
| Feature actual | 004 · búsqueda semántica (cerrada) |
| Último paso completado | `run_all.ps1 -ConIA` en verde (I, J); evidencia 004 con mismo top en las dos vías |
| Siguiente paso | Feature 005 · RAG (rama `005-rag` desde `004-busqueda-semantica`) |
| Bloqueos | Ninguno. Ollama y Caddy responden. |

## Historial

- 2026-10-29 · Spec Kit 1.2.6 inicializado (Claude, PowerShell, extensión git). Constitución v1.0.0.
- 2026-10-29 · 001 cerrada: tests A–F en verde con `run_all.ps1`.
- 2026-10-29 · 002 cerrada: RLS, DDM y GRANT/DENY; bloque G en verde.
- 2026-10-29 · 003 cerrada: Clustered Index Scan -> Index Seek; bloque H en verde. 07 funcionó al primer intento (sin caso de bloque B).
- 2026-10-29 · 004 cerrada: 228 coches y 57 averías con vector; tres frases con el mismo top por SSMS y terminal.

## Capturas pendientes del alumno

Ver `guia-manual-alumno.txt` (no se publica).
