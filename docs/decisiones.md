# Decisiones del proyecto

Registro de decisiones tomadas durante el desarrollo, con su motivo. Orden de prioridad de las
fuentes: enunciado > propuesta > constitución > specs > `docs/prompts/` (ver `CLAUDE.md`).

| # | Fecha | Feature | Decisión | Motivo |
| --- | --- | --- | --- | --- |
| D01 | 2026-10-29 | general | Modelo de respuestas **qwen2.5:3b** en lugar de qwen2.5:7b (propuesta). | La propuesta prevé un modelo de 3B si falta memoria; CLAUDE.md, la constitución, los prompts y `tests/test_conexion_ia.sql` usan 3b, que es el instalado y validado. El enunciado solo exige un «modelo local», así que no afecta a la evaluación. |
| D02 | 2026-10-29 | 001 | Se usan los volúmenes de `03_insert_data.sql` (228 coches, 24 clientes, 44 reservas, 16 ventas) y no los rangos de la propuesta (40–60 coches). | El enunciado pide «datos suficientes»; CLAUDE.md prohíbe regenerar `03`. Más volumen hace más interesantes la búsqueda y la optimización. |
| D03 | 2026-10-29 | 001 | Se mantiene `precio > 0` de `02` aunque la propuesta diga «≥ 0». | `02` está validado por el alumno y es más estricto (un coche a 0 € no tiene sentido). |
| D04 | 2026-10-29 | 000 | Spec Kit 1.2.6 instala los comandos como *skills* en `.claude/skills/`; la sesión en curso no los cargó, así que se siguieron a mano sus `SKILL.md` y sus scripts PowerShell (`create-new-feature-branch.ps1`, `setup-plan.ps1`, `resolve-template.ps1`). | Mismo resultado (specs, ramas y artefactos) sin reiniciar la sesión. |
| D05 | 2026-10-29 | 001 | `run_all.ps1` llama a `sqlcmd` con `-I` (QUOTED_IDENTIFIER ON), `-W` (sin espacios de relleno) y `-f 65001` (UTF-8). | sqlcmd usa QUOTED_IDENTIFIER OFF por defecto y el índice filtrado `ux_reserva_activa` de `02` falla con el error 1934; `-f 65001` conserva acentos y «ñ»; `-W` hace legibles las evidencias. |
| D06 | 2026-10-29 | 001 | `run_all.ps1` sustituye el nombre del equipo por `<equipo>` en todo lo que escribe. | Los mensajes de error de sqlcmd incluyen el nombre de la instancia y no debe llegar a `docs/evidencias/` (regla de CLAUDE.md). |
| D07 | 2026-10-29 | 001 | No existe `docs/notas-instalacion-ia.md`; la evidencia de la fase 0 se genera ejecutando `tests/test_conexion_ia.sql` (`docs/evidencias/000-conexion-ia.txt`). | Los prompts la pedían y la conexión ya funciona. La instalación de Ollama/Caddy del README se redacta con lo que hay en el repositorio y el alumno la revisa. |
| D08 | 2026-10-29 | 001 | La ruta de Caddy no se toca aunque `claude-code-5-prompts.md` sugiera arrancarlo. | CLAUDE.md y el prompt del alumno mandan parar y anotarlo si no responde. |
