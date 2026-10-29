# CLAUDE.md · Bajo el Capó (DP-800, Práctica 09)

Proyecto académico de Emmanuel Grande Sierra: buscador semántico y asesor de averías para un concesionario de coches de segunda mano, con SQL Server 2025 en local e IA local con Ollama. Nivel 3.

## Fuentes de verdad (por orden de prioridad)

1. `referencias/enunciado-practica-09.md`: requisitos obligatorios del profesor.
2. `referencias/propuesta-bajo-el-capo.md`: propuesta revisada (qué se construye y con qué tecnologías).
3. `.specify/memory/constitution.md`: principios del proyecto (Spec Kit).
4. `specs/NNN-*/`: spec, plan y tareas de cada feature.
5. `docs/prompts/`: entradas preparadas para los comandos de Spec Kit.

Si dos fuentes se contradicen, manda la de mayor prioridad. Anota la decisión en `docs/decisiones.md`.

## Estado de partida

- `database/01_create_database.sql` y `02_create_tables.sql`: validados por el alumno en SSMS. No los cambies salvo contradicción con las fuentes 1 o 2.
- `database/03_insert_data.sql`: datos de prueba ya escritos (generados con Claude en el chat; es el caso 1 del bloque B). No lo regeneres: si falla, corrige lo mínimo y regístralo en `docs/bloque-b.md`. Recuentos: 8 marcas, 24 modelos, 228 vehículos, 57 averías, 207 relaciones modelo-avería, 4 comerciales, 24 clientes, 44 reservas y 16 ventas. El Dacia Jogger no tiene averías (caso de control del RAG).
- `database/04_views.sql`, `05_procedures.sql` y `08_advanced_queries.sql`: escritos, sin ejecutar. Revísalos y ejecútalos en la feature 001.
- El resto de scripts está vacío.
- Plazo: el proyecto se entrega hoy. Prioriza que funcione y quede documentado; usa la ruta corta de Spec Kit (specify → plan → tasks → implement).
- Ollama (modelos bge-m3 y qwen2.5:3b) y Caddy los instala y configura el alumno fuera del repositorio. No crees archivos de instalación ni de configuración de Ollama o Caddy; se documentan solo en el README (feature 006).

## Modo de trabajo autónomo

- No preguntes lo que puedas resolver con las fuentes. Decide, anota la decisión con su motivo en `docs/decisiones.md` y sigue.
- Detente y pregunta solo si:
  1. Ollama o Caddy no responden y hace falta una acción del alumno en su equipo.
  2. El enunciado y la propuesta se contradicen en algo que afecta a la evaluación.
  3. Un test sigue fallando tras 3 intentos de corrección.
  4. La acción requiere instalar software, cambiar la configuración del sistema o tocar certificados.
- Lleva el progreso en `docs/estado.md`: feature actual, último paso completado, siguiente paso y bloqueos. Si la sesión se reinicia, continúa desde ahí.
- Con Spec Kit: si un comando pide aclaraciones, respóndelas tú con las fuentes y registra la respuesta en la spec.
- Las excepciones a estas reglas solo valen si el alumno las autoriza de forma explícita en su prompt (por ejemplo, instalar Spec Kit, configurar Caddy o hacer merge y push al final). La autorización vale solo para esa tarea.

## Ejecución en el equipo del alumno

- Puedes ejecutar `sqlcmd -S localhost -E -C -b` contra `BajoElCapoDB` (autenticación de Windows).
- Puedes recrear la base desde cero con `run_all.ps1` (incluye `01`, que borra y recrea `BajoElCapoDB`). No toques ninguna otra base de datos.
- Puedes ejecutar comandos de diagnóstico de solo lectura: `ollama list`, peticiones GET a `http://localhost:11434/api/tags` y a `https://localhost:11435/api/tags`.
- No instales ni desinstales software, no cambies variables de entorno del sistema y no importes certificados. Si hace falta, escribe el comando exacto en `docs/estado.md` y detente.
- Guarda las salidas reales en `docs/evidencias/` (texto de sqlcmd y planes `.sqlplan`). Nunca escribas resultados, tiempos ni cifras que no hayas obtenido ejecutando.

## Reglas no negociables

- Todo local: sin Azure, sin Microsoft Fabric y sin servicios en la nube.
- Sin secretos, contraseñas, IPs personales ni rutas absolutas en el repositorio. Usa `localhost` y rutas relativas.
- Base de datos `BajoElCapoDB`. Esquemas: `catalogo`, `taller`, `ventas`, `ia` y `seg`. Ningún objeto del proyecto en `dbo`.
- Git: una rama por feature (la que crea Spec Kit), cada una a partir de la anterior. Commits pequeños con mensajes convencionales en español (`feat:`, `fix:`, `test:`, `docs:`). No hagas push ni merge a `main`: eso lo revisa el alumno.
- `referencias/` no se publica (está en `.gitignore`).

## Estilo T-SQL

- Cabecera en cada script con el formato de `04_views.sql`: Proyecto, Script, Objetivo, Requisitos, Ejecución, Siguiente y Autor (Emmanuel Grande Sierra).
- `CREATE OR ALTER` para vistas, funciones, procedimientos y triggers. Scripts re-ejecutables cuando sea posible.
- Etiqueta cada bloque con A, B, C… y un comentario breve que diga qué obtiene. Comentarios breves y útiles, no densos.
- `SET NOCOUNT ON`, `SET XACT_ABORT ON`, `TRY/CATCH` y `THROW` con códigos documentados: 500xx tests, 501xx procedimientos, 502xx seguridad, 503xx IA.
- Nunca `SELECT *`. Identificadores en español, como en `02_create_tables.sql`.
- Vectores `VECTOR(1024)`; distancia coseno con `VECTOR_DISTANCE('cosine', ...)`.

## Capa de IA

- Embeddings: bge-m3 (1024 dimensiones). Respuestas del RAG: qwen2.5:3b. Ambos en Ollama.
- **Vía SSMS:** SQL Server llama a `https://localhost:11435` (Caddy con `tls internal`), que reenvía a Ollama en `http://localhost:11434`. SQL Server solo admite HTTPS para modelos externos.
- **Vía terminal:** scripts PowerShell en `ai/` que llaman a Ollama directamente en `http://localhost:11434` y a SQL Server para la recuperación.
- Las dos vías comparten la misma lógica de recuperación en T-SQL. No dupliques el ranking.
- Comprueba en Microsoft Learn la sintaxis de `CREATE EXTERNAL MODEL`, `AI_GENERATE_EMBEDDINGS` y `sp_invoke_external_rest_endpoint` antes de escribirla.
- Prompt del RAG siempre restrictivo: «Responde solo con el contexto proporcionado. Si no hay datos suficientes, dilo». Temperatura 0.

## Bloque B (desarrollo asistido por IA)

- El proyecto se desarrolla con Claude Code y Spec Kit; esa es la evidencia del bloque B.
- Cada vez que un código generado falle un test o haya que corregirlo, añade una entrada en `docs/bloque-b.md` con: entrada usada (prompt o spec), qué se generó, qué se aceptó, qué se corrigió y cómo se verificó. Al final debe haber al menos 3 casos completos.

## Cierre de cada feature

1. Tests en verde con `run_all.ps1` (y `-ConIA` desde la feature 004). Cada feature añade sus propios bloques a `tests/` al implementarse; no se dejan para el final.
2. Evidencias reales en `docs/evidencias/NNN-*`.
3. `docs/decisiones.md`, `docs/bloque-b.md` y `docs/estado.md` actualizados.
4. Commit en la rama de la feature.
5. Resumen corto: qué se hizo, qué debe revisar el alumno y siguiente feature.
