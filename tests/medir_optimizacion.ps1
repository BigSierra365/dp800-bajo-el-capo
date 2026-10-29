<#
=============================================================================
   Proyecto   : Bajo el Capó · DP-800 (Microsoft SQL AI Developer Associate)
   Script     : tests/medir_optimizacion.ps1
   Objetivo   : Ejecuta database/07_indexes.sql lote a lote en una sola conexión,
                activa STATISTICS XML solo en las consultas medidas (bloques C y E)
                y guarda los planes reales (.sqlplan) y los mensajes de
                STATISTICS IO y TIME.
   Requisitos : BajoElCapoDB creada (run_all.ps1). Autenticación de Windows.
   Ejecución  : .\tests\medir_optimizacion.ps1
   Salida     : docs/evidencias/003-plan-antes.sqlplan, 003-plan-despues.sqlplan
                y 003-optimizacion.txt
   Autor      : Emmanuel Grande Sierra
=============================================================================
#>
[CmdletBinding()]
param([string]$Servidor = 'localhost')

$ErrorActionPreference = 'Stop'
$raiz = Split-Path $PSScriptRoot -Parent
$evidencias = Join-Path $raiz 'docs\evidencias'
New-Item -ItemType Directory -Force -Path $evidencias | Out-Null

# A: lotes de 07 (separados por GO)
$texto = [IO.File]::ReadAllText((Join-Path $raiz 'database\07_indexes.sql'), [Text.Encoding]::UTF8)
$lotes = [regex]::Split($texto, '(?im)^\s*GO\s*$') | Where-Object { $_.Trim() }

# B: una conexión; los mensajes (PRINT, STATISTICS IO/TIME) se acumulan en orden
$conexion = New-Object System.Data.SqlClient.SqlConnection "Server=$Servidor;Database=BajoElCapoDB;Integrated Security=true;TrustServerCertificate=true"
$mensajes = New-Object System.Collections.Generic.List[string]
$conexion.add_InfoMessage({ param($s, $e) $mensajes.Add($e.Message) })
$conexion.Open()

function Ejecutar([string]$sql) {
    $cmd = $conexion.CreateCommand(); $cmd.CommandText = $sql; $cmd.CommandTimeout = 600
    $planes = @()
    $lector = $cmd.ExecuteReader()
    do {
        # los planes llegan como un conjunto de resultados de una sola columna XML
        if ($lector.FieldCount -eq 1 -and $lector.GetName(0) -like '*Showplan*') {
            while ($lector.Read()) { $planes += $lector.GetString(0) }
        } else { while ($lector.Read()) { } }
    } while ($lector.NextResult())
    $lector.Close()
    return ,$planes
}

$planAntes = $null; $planDespues = $null
foreach ($lote in $lotes) {
    $medido = $lote -match '(?m)^-- (C|E):'
    if ($medido) { Ejecutar 'SET STATISTICS XML ON;' | Out-Null }
    $planes = Ejecutar $lote
    if ($medido) {
        Ejecutar 'SET STATISTICS XML OFF;' | Out-Null
        # el último plan del lote es el de la segunda ejecución, la que se compara
        $ultimo = $planes | Where-Object { $_ -match 'TOP \(50\)' } | Select-Object -Last 1
        if ($lote -match '(?m)^-- C:') { $planAntes = $ultimo } else { $planDespues = $ultimo }
    }
}
$conexion.Close()

# C: guarda planes y mensajes (sin el nombre del equipo)
$limpiar = { param($t) $t -replace [regex]::Escape($env:COMPUTERNAME), '<equipo>' }
[IO.File]::WriteAllText((Join-Path $evidencias '003-plan-antes.sqlplan'),   (& $limpiar $planAntes),   (New-Object Text.UTF8Encoding $false))
[IO.File]::WriteAllText((Join-Path $evidencias '003-plan-despues.sqlplan'), (& $limpiar $planDespues), (New-Object Text.UTF8Encoding $false))
$salida = @('# Evidencia 003 · Mensajes reales de database/07_indexes.sql (STATISTICS IO y TIME)', '') + ($mensajes | ForEach-Object { & $limpiar $_ })

# D: resumen extraído de los planes reales (operador sobre Vehiculos, coste y filas leídas)
function Resumir([string]$nombre, [string]$plan) {
    [xml]$x = $plan
    $ns = New-Object Xml.XmlNamespaceManager $x.NameTable
    $ns.AddNamespace('p', 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
    $stmt = $x.SelectSingleNode('//p:StmtSimple', $ns)
    $ops = $x.SelectNodes('//p:RelOp[p:IndexScan/p:Object[@Table="[Vehiculos]"]]', $ns)
    $lineas = @("$nombre · coste estimado del plan (StatementSubTreeCost): $($stmt.StatementSubTreeCost)")
    foreach ($op in $ops) {
        $obj = $op.SelectSingleNode('p:IndexScan/p:Object', $ns)
        $leidas = ($op.SelectNodes('p:RunTimeInformation/p:RunTimeCountersPerThread', $ns) | ForEach-Object { [long]$_.ActualRowsRead } | Measure-Object -Sum).Sum
        $lineas += "$nombre · acceso a Vehiculos: $($op.PhysicalOp) sobre $($obj.Index) · filas leídas: $leidas · coste del operador: $($op.EstimatedTotalSubtreeCost)"
    }
    return $lineas
}
$salida += ''; $salida += '## Resumen de los planes reales (segunda ejecución)'
$salida += Resumir 'ANTES' $planAntes
$salida += Resumir 'DESPUÉS' $planDespues
Set-Content -Path (Join-Path $evidencias '003-optimizacion.txt') -Value $salida -Encoding UTF8
$salida | Select-Object -Last 6
