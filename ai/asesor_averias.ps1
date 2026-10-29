<#
=============================================================================
   Proyecto   : Bajo el Capó · DP-800 (Microsoft SQL AI Developer Associate)
   Script     : ai/asesor_averias.ps1
   Objetivo   : Asesor de averías (RAG) por la vía terminal. Embedding de la
                pregunta con Ollama (bge-m3), recuperación y contexto en SQL Server
                (ia.sp_contexto_averias_vector, la misma lógica que la vía SSMS) y
                respuesta de qwen2.5:3b con Ollama (temperatura 0).
   Requisitos : ai/rag.sql ejecutado; Ollama en http://localhost:11434.
   Ejecución  : .\ai\asesor_averias.ps1 -Pregunta "¿Qué averías suele tener y cuánto cuesta repararlas?" -Modelo "Peugeot 308 SW"
                .\ai\asesor_averias.ps1 -Pregunta "¿Qué averías suele tener y cuánto cuesta repararlas?" -Modelo "Dacia Jogger"
   Autor      : Emmanuel Grande Sierra
=============================================================================
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Pregunta,
    [string]$Modelo,
    [int]$Top = 5,
    [string]$Servidor = 'localhost'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'comun.ps1')

function Encabezado([string]$texto) { Write-Host ''; Write-Host "=== $texto ===" -ForegroundColor Cyan }

# A: recuperación · vector de la pregunta con Ollama y documentos + contexto desde SQL Server
$vector = Get-VectorJson $Pregunta
$datos = Invoke-Procedimiento $Servidor 'ia.sp_contexto_averias_vector' @{
    vector = $vector; modelo = $Modelo; top = $Top; pregunta = $Pregunta
}
$documentos = $datos.Tables[0]
$sistema    = $datos.Tables[1].Rows[0].prompt_sistema
$mensaje    = $datos.Tables[1].Rows[0].mensaje_usuario

# B: generación · mismo prompt y mismo contexto que la vía SSMS
$respuesta = Get-RespuestaChat $sistema $mensaje

# C: las cuatro partes del RAG
Encabezado '1. Pregunta'
Write-Host $Pregunta $(if ($Modelo) { "(modelo: $Modelo)" } else { '(sin modelo)' })
Encabezado '2. Documentos recuperados'
$documentos | Format-Table tipo, posicion, distancia, documento -Wrap | Out-String -Width 200 | Write-Host
Encabezado '3. Contexto enviado al modelo'
Write-Host "[sistema] $sistema"
Write-Host "[usuario] $mensaje"
Encabezado '4. Respuesta'
Write-Host $respuesta
