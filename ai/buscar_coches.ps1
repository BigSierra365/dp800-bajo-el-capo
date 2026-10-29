<#
=============================================================================
   Proyecto   : Bajo el Capó · DP-800 (Microsoft SQL AI Developer Associate)
   Script     : ai/buscar_coches.ps1
   Objetivo   : Buscador semántico por la vía terminal. Pide el embedding de la
                frase a Ollama (bge-m3) y usa el mismo ranking de SQL Server que la
                vía SSMS (ia.sp_buscar_coches_vector -> ia.fn_ranking_coches).
   Requisitos : ai/vector_search.sql ejecutado; Ollama en http://localhost:11434.
   Ejecución  : .\ai\buscar_coches.ps1 -Consulta "familiar, económico y fiable para ciudad y escapadas" -PrecioMax 14000
                .\ai\buscar_coches.ps1 -Consulta "aventura por caminos de tierra" -Segmento SUV -Top 3
   Autor      : Emmanuel Grande Sierra
=============================================================================
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Consulta,
    [Nullable[decimal]]$PrecioMax,
    [string]$Segmento,
    [int]$Top = 5,
    [string]$Servidor = 'localhost'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'comun.ps1')

# A: embedding de la frase con Ollama
$vector = Get-VectorJson $Consulta

# B: ranking en SQL Server (misma función que la vía SSMS)
$datos = Invoke-Procedimiento $Servidor 'ia.sp_buscar_coches_vector' @{
    vector = $vector; precio_max = $PrecioMax; segmento = $Segmento; top = $Top
}

# C: resultado
Write-Host "Consulta: $Consulta" -ForegroundColor Cyan
$filtros = @()
if ($PrecioMax) { $filtros += "precio máximo $PrecioMax" }
if ($Segmento)  { $filtros += "segmento $Segmento" }
Write-Host ("Filtros: " + $(if ($filtros) { $filtros -join ', ' } else { 'ninguno' }) + " · top $Top")
$datos.Tables[0] | Select-Object posicion, distancia, marca, modelo, segmento, anio, precio_venta,
    @{ n = 'descripcion'; e = { if ($_.descripcion.Length -gt 70) { $_.descripcion.Substring(0, 70) + '…' } else { $_.descripcion } } } |
    Format-Table -AutoSize | Out-String -Width 220
