<#
=============================================================================
   Proyecto   : Bajo el Capó · DP-800 (Microsoft SQL AI Developer Associate)
   Script     : run_all.ps1
   Objetivo   : Recrea BajoElCapoDB desde cero y ejecuta los tests. Con -ConIA
                añade la parte de IA (modelo externo, embeddings, búsqueda y RAG).
   Requisitos : sqlcmd y autenticación de Windows con permisos de sysadmin.
                Con -ConIA: Ollama (bge-m3, qwen2.5:3b) y Caddy en https://localhost:11435.
   Ejecución  : .\run_all.ps1
                .\run_all.ps1 -ConIA
                .\run_all.ps1 -ConIA -Salida docs\evidencias\run_all.txt
   Aviso      : Es destructivo: 01 borra y recrea BajoElCapoDB.
   Autor      : Emmanuel Grande Sierra
=============================================================================
#>
[CmdletBinding()]
param(
    [string]$Servidor = 'localhost',
    [switch]$ConIA,
    [string]$Salida
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$raiz = $PSScriptRoot
$base = 'BajoElCapoDB'

# A: salida a consola y, si se indica, también a un archivo (ruta relativa a la raíz)
if ($Salida) {
    if (-not [System.IO.Path]::IsPathRooted($Salida)) { $Salida = Join-Path $raiz $Salida }
    New-Item -ItemType Directory -Force -Path (Split-Path $Salida) | Out-Null
    Set-Content -Path $Salida -Value '' -Encoding UTF8
}
function Escribir([string]$texto) {
    $texto = $texto -replace [regex]::Escape($env:COMPUTERNAME), '<equipo>'   # sin nombre de instancia en evidencias
    Write-Host $texto
    if ($Salida) { Add-Content -Path $Salida -Value $texto -Encoding UTF8 }
}

# B: ejecuta un script con sqlcmd; omite los vacíos y se detiene en el primer error
function Ejecutar([string]$relativa, [string]$bd = $base) {
    $ruta = Join-Path $raiz $relativa
    if (-not (Test-Path $ruta)) { throw "No existe $relativa" }
    if ([string]::IsNullOrWhiteSpace((Get-Content -Raw -Path $ruta))) {
        Escribir "--- $relativa (vacío, se omite)"
        return
    }
    Escribir "=== $relativa"
    $inicio = Get-Date
    $lineas = & sqlcmd -S $Servidor -d $bd -E -C -b -I -W -f 65001 -i $ruta
    $codigo = $LASTEXITCODE
    foreach ($l in $lineas) { Escribir $l }
    $segundos = [math]::Round(((Get-Date) - $inicio).TotalSeconds, 1)
    if ($codigo -ne 0) {
        Escribir "*** ERROR en $relativa (código $codigo). Ejecución detenida."
        exit $codigo
    }
    Escribir "--- OK $relativa ($segundos s)"
}

Escribir "Bajo el Capó · run_all.ps1 · servidor: $Servidor · ConIA: $($ConIA.IsPresent)"

# C: base de datos, desde cero (01 se ejecuta contra master)
Ejecutar 'database\01_create_database.sql' 'master'
'02_create_tables', '03_insert_data', '04_views', '05_procedures',
'06_security', '07_indexes', '08_advanced_queries' |
    ForEach-Object { Ejecutar "database\$_.sql" }

# D: parte de IA (solo con -ConIA): primero la prueba de conexión SQL Server -> Caddy -> Ollama
if ($ConIA) {
    Ejecutar 'tests\test_conexion_ia.sql'
    'create_external_model', 'generate_embeddings', 'vector_search', 'rag' |
        ForEach-Object { Ejecutar "ai\$_.sql" }
}

# E: tests
Ejecutar 'tests\tests.sql'
if ($ConIA) { Ejecutar 'tests\tests_ia.sql' }

Escribir 'RESULTADO: todos los scripts y tests terminaron sin errores.'
