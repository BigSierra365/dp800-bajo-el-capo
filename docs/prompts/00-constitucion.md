# 00 · Constitución del proyecto

Entrada para `/speckit.constitution`. Se ejecuta una sola vez, antes de la primera feature.

```text
Proyecto Bajo el Capó (DP-800, Práctica 09): buscador semántico y asesor de averías para un concesionario de coches de segunda mano, con SQL Server 2025 en local e IA local con Ollama. Nivel 3. Autor: Emmanuel Grande Sierra.

Principios:

I. Requisitos del enunciado primero. referencias/enunciado-practica-09.md es obligatorio y manda sobre todo lo demás. referencias/propuesta-bajo-el-capo.md define el alcance y las tecnologías. Nada fuera de alcance sin anotarlo en docs/decisiones.md.

II. Local y sin secretos. SQL Server 2025, Ollama y Caddy en el equipo del alumno. Ni Azure ni Microsoft Fabric. Sin contraseñas, claves, IPs personales ni rutas absolutas en el repositorio. La instalación de Ollama y Caddy no se versiona: se documenta en el README.

III. Reproducible desde cero. Scripts numerados y re-ejecutables cuando sea posible. Un único comando (run_all.ps1) recrea la base y ejecuta los tests; con -ConIA incluye la parte de IA.

IV. Demostrar que funciona. Código, ejecución, resultado y explicación. Cada funcionalidad tiene un test y una evidencia real en docs/evidencias. Nunca se inventan resultados, tiempos ni cifras.

V. Calidad del T-SQL. Esquemas propios (catalogo, taller, ventas, ia, seg), cabecera en cada script, bloques etiquetados A, B, C con comentarios breves, CREATE OR ALTER, transacciones con TRY/CATCH y THROW con códigos documentados, nada de SELECT *.

VI. Mínimo privilegio. Los usuarios acceden por vistas y procedimientos según su rol. Row-Level Security y Dynamic Data Masking protegen los datos de clientes.

VII. IA local y honesta. bge-m3 (1024 dimensiones) para embeddings y qwen2.5:3b para respuestas. Distancia coseno. Dos vías (SSMS y terminal) con la misma lógica de recuperación. RAG con prompt restrictivo, temperatura 0 y caso de control sin datos.

VIII. Pequeño y bien explicado. La solución mínima que cumple cada bloque del enunciado (A a G), sin interfaz gráfica ni extras no pedidos.

IX. Trazabilidad del desarrollo con IA. Specs, planes, tareas, decisiones y casos del bloque B quedan documentados en el repositorio.

X. Autonomía con frenos. El agente decide con las fuentes y registra la decisión. Solo se detiene en los casos que indica CLAUDE.md.

Gobierno: esta constitución y CLAUDE.md deben decir lo mismo. Si cambian, se actualizan los dos.
```
