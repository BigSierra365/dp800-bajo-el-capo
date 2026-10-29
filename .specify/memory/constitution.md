# Constitución de Bajo el Capó

Proyecto Bajo el Capó (DP-800, Práctica 09): buscador semántico y asesor de averías para un
concesionario de coches de segunda mano, con SQL Server 2025 en local e IA local con Ollama.
Nivel 3. Autor: Emmanuel Grande Sierra.

## Core Principles

### I. Requisitos del enunciado primero

`referencias/enunciado-practica-09.md` es obligatorio y MUST prevalecer sobre cualquier otra fuente.
`referencias/propuesta-bajo-el-capo.md` define el alcance y las tecnologías. Nada fuera de alcance
se añade sin anotarlo en `docs/decisiones.md`.

### II. Local y sin secretos

SQL Server 2025, Ollama y Caddy se ejecutan en el equipo del alumno. Prohibidos Azure y Microsoft
Fabric. El repositorio MUST NOT contener contraseñas, claves, IPs personales ni rutas absolutas.
La instalación de Ollama y Caddy no se versiona: se documenta en el README.

### III. Reproducible desde cero

Scripts numerados y re-ejecutables cuando sea posible. Un único comando (`run_all.ps1`) MUST
recrear la base y ejecutar los tests; con `-ConIA` incluye la parte de IA.

### IV. Demostrar que funciona

Cada funcionalidad se presenta como código, ejecución, resultado y explicación. Cada una MUST
tener un test y una evidencia real en `docs/evidencias/`. Nunca se inventan resultados, tiempos
ni cifras.

### V. Calidad del T-SQL

Esquemas propios (`catalogo`, `taller`, `ventas`, `ia`, `seg`), ningún objeto en `dbo`, cabecera
en cada script, bloques etiquetados A, B, C con comentarios breves, `CREATE OR ALTER`,
transacciones con `TRY/CATCH` y `THROW` con códigos documentados (500xx tests, 501xx
procedimientos, 502xx seguridad, 503xx IA) y nada de `SELECT *`.

### VI. Mínimo privilegio

Los usuarios acceden por vistas y procedimientos según su rol, sin acceso directo a las tablas
base. Row-Level Security y Dynamic Data Masking MUST proteger los datos de clientes.

### VII. IA local y honesta

bge-m3 (1024 dimensiones) para embeddings y qwen2.5:3b para respuestas, ambos en Ollama.
Distancia coseno. Dos vías (SSMS y terminal) con la misma lógica de recuperación en T-SQL.
El RAG MUST usar un prompt restrictivo, temperatura 0 y un caso de control sin datos.

### VIII. Pequeño y bien explicado

La solución mínima que cumple cada bloque del enunciado (A a G), sin interfaz gráfica ni extras
no pedidos.

### IX. Trazabilidad del desarrollo con IA

Specs, planes, tareas, decisiones y casos del bloque B quedan documentados en el repositorio
(`specs/`, `docs/decisiones.md`, `docs/bloque-b.md`).

### X. Autonomía con frenos

El agente decide con las fuentes y registra la decisión. Solo se detiene en los casos que indica
`CLAUDE.md`: Ollama o Caddy caídos, contradicción que afecte a la evaluación, test que falla tras
3 intentos, o acciones que requieren instalar software o tocar la configuración del sistema.

## Restricciones técnicas

- Windows 11, SQL Server 2025 (nivel de compatibilidad 170), SSMS 22, PowerShell y sqlcmd.
- Base de datos `BajoElCapoDB`; vectores `VECTOR(1024)`; similitud con `VECTOR_DISTANCE('cosine', ...)`.
- SQL Server llama a los modelos por HTTPS a través de Caddy (`https://localhost:11435`); la vía
  terminal llama a Ollama en `http://localhost:11434`.

## Flujo de desarrollo

- Spec-Driven Development con Spec Kit, ruta corta: specify → plan → tasks → implement.
- Una rama por feature (001 a 006), cada una a partir de la anterior; commits pequeños con
  mensajes convencionales en español. El merge a `main` lo autoriza el alumno.
- Cierre de feature: tests en verde con `run_all.ps1`, evidencias reales, `docs/decisiones.md`,
  `docs/bloque-b.md` y `docs/estado.md` actualizados, y commit.

## Governance

Orden de prioridad de las fuentes: enunciado, propuesta, esta constitución, specs y
`docs/prompts/`. Esta constitución y `CLAUDE.md` deben decir lo mismo; si una cambia, se actualizan
las dos y el cambio se anota en `docs/decisiones.md`. Versionado semántico: MAJOR para eliminar o
redefinir principios, MINOR para añadirlos, PATCH para aclaraciones. Cada plan de feature incluye
una comprobación de cumplimiento de estos principios.

**Version**: 1.0.0 | **Ratified**: 2026-10-29 | **Last Amended**: 2026-10-29
