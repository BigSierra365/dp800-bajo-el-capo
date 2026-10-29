# 006 · Documentación final (README e informe)

## Entrada para specify

```text
Documentación final para que otro estudiante pueda reproducir el proyecto y para el informe técnico que se entrega en PDF.

Historias de usuario:
1. Como estudiante, descargo el repositorio y, siguiendo el README, instalo los requisitos (incluidos Ollama y Caddy), creo la base y reproduzco todas las funcionalidades.
2. Como profesor, encuentro en el README y en el informe cada requisito del enunciado con su evidencia.

Criterios de aceptación:
- README.md con todas las secciones del apartado 12 del enunciado: descripción, arquitectura (diagrama), tecnologías, instalación paso a paso, base de datos, funcionalidades DP-800 implementadas (con ✓), ejemplos con resultados reales y conclusiones (qué se ha aprendido, problemas, cómo se resolvieron y mejoras). Indica el nivel 3.
- La instalación incluye Ollama (modelos bge-m3 y qwen2.5:3b), Caddy (contenido del Caddyfile, arranque y confianza en el certificado en Windows), run_all.ps1 con y sin -ConIA, y las dos vías de la IA (SSMS y terminal).
- docs/proyecto.md con las 12 secciones del apartado 13 del enunciado en ese orden, una extensión equivalente a 5 a 10 páginas, poco código y referencias al repositorio. Usa resultados de docs/evidencias y deja marcadores [CAPTURA: …] donde el alumno deba añadir capturas de SSMS.
- docs/bloque-b.md con al menos 3 casos completos.
- Tabla final de cumplimiento contra los apartados 3 a 18 del enunciado, con enlace a la evidencia de cada punto.
- Sección «Estrategia de pruebas» en el README y en el informe, con los tipos de prueba y su evidencia.
- Nada inventado: todas las cifras proceden de docs/evidencias.
```

## Entrada para plan

```text
- README.md:
  - Diagrama de arquitectura en Mermaid (vías SSMS y terminal, Caddy y Ollama).
  - Tecnologías con versiones: SQL Server 2025, SSMS 22, VS Code con la extensión SQL Server, PowerShell y sqlcmd, Ollama, Caddy, Git y GitHub.
  - Instalación numerada: clonar; instalar Ollama y descargar bge-m3 y qwen2.5:3b; configurar Caddy (Caddyfile mínimo con https://localhost:11435, tls internal y reverse_proxy a localhost:11434; arrancarlo con caddy run; confiar en su certificado raíz en el almacén del equipo local); ejecutar run_all.ps1 sin y con -ConIA; probar las dos vías.
  - Solución de problemas con los fallos reales registrados en docs/decisiones.md y docs/estado.md (por ejemplo, la confianza en el certificado de Caddy).
  - Base de datos: tablas, relaciones y diagrama (Mermaid erDiagram).
  - Funcionalidades DP-800 con ✓ por bloque (A a G) y enlace a cada script.
  - Ejemplos copiados de docs/evidencias.
  - Conclusiones y mejoras (índice vectorial y VECTOR_SEARCH cuando salgan de vista previa, búsqueda híbrida, interfaz mínima).
- docs/proyecto.md: portada (título, autor, certificación, fecha y enlace al repositorio) y las secciones 2 a 12 del apartado 13. Redactado para exportar a PDF: encabezados claros, tablas simples, sin HTML.
- docs/bloque-b.md: revisa y completa los casos registrados durante el desarrollo.
- Sección «Estrategia de pruebas» en el README y en docs/proyecto.md. Explica los tipos de prueba y qué bloque de tests/ implementa cada uno, con su salida real de docs/evidencias: estructurales (tablas y esquemas), de datos (recuentos y coherencia), de objetos (vistas y funciones), de integración (flujo reserva-venta), negativas (doble reserva con el error 50102, permisos denegados al mecánico y caso de control del RAG sin averías) y de IA (embeddings y búsqueda). Indica que cada prueba falla con THROW y que run_all.ps1 se detiene en el primer error. Menciona como mejora futura tSQLt o SQL Database Projects con pruebas en CI.
- No crees la presentación: la hace el alumno en presentation/.
- Revisión final del repositorio: sin IPs, rutas absolutas ni secretos, y enlaces relativos que funcionan.
```

## Criterio de cierre

- El README cubre todas las secciones del apartado 12 y `docs/proyecto.md` las 12 del apartado 13.
- La tabla de cumplimiento enlaza una evidencia para cada requisito.
- `docs/estado.md` lista las capturas que tiene que hacer el alumno.
