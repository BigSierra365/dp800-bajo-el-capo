# Estado del proyecto

| Campo | Valor |
| --- | --- |
| Feature actual | 006 · documentación (cerrada). Las 6 features están terminadas y fusionadas en `main` |
| Último paso completado | Revisión final: `run_all.ps1 -ConIA` desde cero en verde (A–K); sin IPs, rutas personales, secretos ni nombre de instancia |
| Siguiente paso | Tareas del alumno (ver abajo) |
| Bloqueos | Ninguno. Ollama y Caddy respondieron durante toda la sesión |

## Historial

- 2026-10-29 · Spec Kit 1.2.6 inicializado (Claude, PowerShell, extensión git). Constitución v1.0.0.
- 2026-10-29 · 001 cerrada: tests A–F en verde con `run_all.ps1`.
- 2026-10-29 · 002 cerrada: RLS, DDM y GRANT/DENY; bloque G en verde.
- 2026-10-29 · 003 cerrada: Clustered Index Scan -> Index Seek; bloque H en verde. 07 funcionó al primer intento (sin caso de bloque B).
- 2026-10-29 · 004 cerrada: 228 coches y 57 averías con vector; tres frases con el mismo top por SSMS y terminal.
- 2026-10-29 · 005 cerrada: RAG por las dos vías con contexto idéntico; el Jogger responde «No hay averías registradas para ese modelo.»
- 2026-10-29 · 006 cerrada: README, informe `docs/proyecto.md`, tabla de cumplimiento y revisión final (`docs/evidencias/006-run_all-final.txt`).

## Pendiente del alumno

Capturas de SSMS (marcadores `[CAPTURA: …]` de `docs/proyecto.md`, en `docs/img/`):

1. Plan gráfico antes y después de `07` (o abrir los `.sqlplan` de `docs/evidencias/`).
2. Demo de seguridad: filas por usuario, máscaras y permisos denegados.
3. Buscador por SSMS y por terminal (frase 1).
4. Asesor por SSMS (Peugeot 308 SW) y por terminal (caso de control, Dacia Jogger).
5. Diagrama de base de datos de SSMS, salida final de `run_all.ps1 -ConIA` y una consulta de `08`.

Otras tareas:

- Revisar la instalación de Ollama y Caddy del README contra las notas reales (decisión D07).
- Exportar `docs/proyecto.md` a PDF y rellenar el enlace al repositorio.
- Preparar la presentación en `presentation/`.
- Crear el repositorio en GitHub y hacer push: no hay remoto `origin`.

Los pasos detallados están en `guia-manual-alumno.txt`, que no se publica.
