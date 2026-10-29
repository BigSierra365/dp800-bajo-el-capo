# Los 5 prompts para Claude Code

Pégalos en orden, uno por uno, en Claude Code (VS Code). Espera a que termine cada uno antes de pegar el siguiente.

**Antes del prompt 1:** descomprime el paquete en la raíz del repositorio y acepta sobrescribir (`database/03`, `04`, `05` y `08`, `CLAUDE.md`, `docs/prompts/` y `referencias/propuesta-bajo-el-capo.md`). Pon el selector de permisos de Claude Code en **Auto** y, cuando pregunte por `sqlcmd`, `powershell` u `ollama`, elige permitir siempre. Caddy debe estar en marcha (`caddy start --config "$env:USERPROFILE\caddy\Caddyfile"`) y la prueba de conexión superada.

| Prompt | Qué hace | Tiempo orientativo |
| --- | --- | --- |
| 1 | Conexión SQL Server → Caddy → Ollama (a mano, con la guía) | 20–30 min |
| 2 | Spec Kit + feature 001 (base de datos) | 45–60 min |
| 3 | Features 002 (seguridad) y 003 (optimización) | 45–60 min |
| 4 | Features 004 (búsqueda semántica) y 005 (RAG) | 60–75 min |
| 5 | Feature 006 (README e informe), revisión final y entrega | 30–45 min |

---

## Prompt 1 · Conexión de la IA (Caddy + Ollama + SQL Server): ya hecho a mano

No lo pegues. La conexión se deja funcionando antes de empezar con `docs/notas-instalacion-ia.md` y `tests/test_conexion_ia.sql`. Antes del prompt 2, guarda la salida real del test en `docs/evidencias/000-conexion-ia.txt`.

Empieza directamente por el prompt 2. Son 4 prompts.

---

## Prompt 2 · Spec Kit y feature 001 (base de datos)

```text
Trabaja en español según CLAUDE.md. Te autorizo a instalar uv y specify-cli si faltan.

1. Git: crea un .gitignore que incluya referencias/ si no está. Haz un primer commit en main con el estado actual (mensaje: "chore: punto de partida del proyecto").
2. Instala Spec Kit: uv tool install specify-cli. Mira specify init --help y elige los flags correctos para Claude Code y scripts de PowerShell (por ejemplo specify init . --integration claude --script ps, o en versiones anteriores --here --ai claude). Inicialízalo en este repositorio sin sobrescribir CLAUDE.md, docs/ ni database/. Comprueba qué comandos /speckit tienes disponibles.
3. Ejecuta /speckit.constitution con el bloque de docs/prompts/00-constitucion.md.
4. Feature 001 con la ruta corta: /speckit.specify con el bloque «Entrada para specify» de docs/prompts/001-base-datos.md, /speckit.plan con su bloque «Entrada para plan», /speckit.tasks y /speckit.implement.
5. En implement: crea run_all.ps1 y tests/tests.sql, ejecuta run_all.ps1 desde cero (01 a 05 y 08) y corrige hasta que todos los tests pasen. Si /speckit.converge existe, ejecútalo.
6. Cierra la feature según CLAUDE.md (evidencias, decisiones, bloque-b, estado y commit). Registra en docs/bloque-b.md el caso 1: los datos de 03 generados con Claude en el chat (petición, qué se generó, qué se aceptó, qué se corrigió y cómo se verificó con los tests).
7. Resume en 5 líneas.
```

---

## Prompt 3 · Features 002 (seguridad) y 003 (optimización)

```text
Trabaja en español según CLAUDE.md y continúa desde docs/estado.md.

Para cada feature, 002 y después 003, usa la ruta corta de Spec Kit con su archivo de docs/prompts/: /speckit.specify con el bloque «Entrada para specify», /speckit.plan con el bloque «Entrada para plan», /speckit.tasks y /speckit.implement. Cada feature parte de la rama de la anterior.

- 002: crea database/06_security.sql y tests/demo_seguridad.sql. Ejecuta run_all.ps1 desde cero y la demo, y guarda la salida real en docs/evidencias/002-seguridad.txt.
- 003: crea database/07_indexes.sql. Guarda los planes reales (.sqlplan), la salida de STATISTICS IO y TIME y la tabla antes/después con valores reales en docs/evidencias/. Comprueba que run_all.ps1 sigue pasando todos los tests después de 07. Cada feature añade sus propios bloques a tests/tests.sql (seguridad en 002, optimización en 003); no los dejes para el final.

Cierra cada feature según CLAUDE.md, con su commit. No me preguntes salvo en los casos de CLAUDE.md. Al terminar, resume en 5 líneas y lista las capturas de SSMS que debo hacer (plan gráfico antes y después, demo de seguridad).
```

---

## Prompt 4 · Features 004 (búsqueda semántica) y 005 (RAG)

```text
Trabaja en español según CLAUDE.md y continúa desde docs/estado.md. Usa docs/notas-instalacion-ia.md y tests/test_conexion_ia.sql (sintaxis y rutas JSON que ya funcionan; el chat usa qwen2.5:3b). Antes de empezar, comprueba que Caddy está arrancado; si no, arráncalo con caddy start --config "$env:USERPROFILE\caddy\Caddyfile".

Para cada feature, 004 y después 005, usa la ruta corta de Spec Kit con su archivo de docs/prompts/: /speckit.specify, /speckit.plan, /speckit.tasks y /speckit.implement.

- 004: ai/create_external_model.sql, ai/generate_embeddings.sql, ai/vector_search.sql, ai/buscar_coches.ps1 y tests/tests_ia.sql. Ejecuta run_all.ps1 -ConIA desde cero. Prueba tres frases por SSMS y por terminal, y guarda docs/evidencias/004-busqueda.txt.
- 005: ai/rag.sql y ai/asesor_averias.ps1. Prueba dos preguntas y el caso de control (Dacia Jogger, sin averías) por las dos vías, y guarda docs/evidencias/005-rag.txt.

Si la generación de embeddings de los 228 coches tarda mucho, procesa por lotes y sigue. Cierra cada feature según CLAUDE.md, con su commit. Resume en 5 líneas.
```

---

## Prompt 5 · Feature 006 (documentación), revisión final y entrega

```text
Trabaja en español según CLAUDE.md y continúa desde docs/estado.md.

1. Feature 006 con la ruta corta de Spec Kit y docs/prompts/006-documentacion.md: README.md completo (apartado 12 del enunciado, con la instalación de Ollama y Caddy a partir de docs/notas-instalacion-ia.md) y docs/proyecto.md (las 12 secciones del apartado 13, listo para exportar a PDF). Todas las cifras salen de docs/evidencias. Completa docs/bloque-b.md con al menos 3 casos. Incluye una sección «Estrategia de pruebas» en el README y en el informe: tipos de prueba (estructurales, de datos, de objetos, de integración, negativas y de IA), el bloque de tests/ que implementa cada una y su salida real.
2. Revisión final: ejecuta run_all.ps1 -ConIA desde cero; comprueba que no hay IPs, rutas absolutas ni secretos en el repositorio; comprueba la tabla de cumplimiento contra referencias/enunciado-practica-09.md.
3. Te autorizo a fusionar las ramas de las features en main, en orden. Si existe el remoto origin, haz push de main; si no existe, dame los comandos para crear el repositorio en GitHub y subirlo.
4. Dame la lista final de lo que tengo que hacer yo: capturas que faltan (marcadores [CAPTURA: …]), exportar docs/proyecto.md a PDF y la presentación.
```
