<#
=============================================================================
   Proyecto   : Bajo el Capó · DP-800 (Microsoft SQL AI Developer Associate)
   Script     : ai/comun.ps1
   Objetivo   : Funciones compartidas por la vía terminal (buscar_coches.ps1 y
                asesor_averias.ps1): llamadas a Ollama y a SQL Server.
   Requisitos : Ollama en http://localhost:11434 (bge-m3 y qwen2.5:3b).
                SQL Server con autenticación de Windows.
   Ejecución  : no se ejecuta solo; los otros scripts lo cargan con «. $PSScriptRoot\comun.ps1»
   Autor      : Emmanuel Grande Sierra
=============================================================================
#>

$OllamaUrl = 'http://localhost:11434'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# A: POST JSON a Ollama con UTF-8 en los dos sentidos (Invoke-RestMethod de PowerShell 5.1
#    no siempre decodifica bien los acentos)
function Invoke-Ollama([string]$Ruta, [hashtable]$Cuerpo) {
    $cliente = New-Object System.Net.WebClient
    $cliente.Encoding = [System.Text.Encoding]::UTF8
    $cliente.Headers['Content-Type'] = 'application/json; charset=utf-8'
    try {
        $json = $cliente.UploadString("$OllamaUrl$Ruta", ($Cuerpo | ConvertTo-Json -Depth 10 -Compress))
    } catch {
        throw "No se pudo llamar a Ollama en $OllamaUrl$Ruta. ¿Está en marcha? Detalle: $($_.Exception.Message)"
    }
    return $json | ConvertFrom-Json
}

# B: embedding de un texto con bge-m3, como array JSON listo para VECTOR(1024)
function Get-VectorJson([string]$Texto) {
    $r = Invoke-Ollama '/api/embed' @{ model = 'bge-m3'; input = $Texto }
    $valores = $r.embeddings[0]
    if ($valores.Count -ne 1024) { throw "bge-m3 devolvió $($valores.Count) dimensiones (se esperaban 1024)." }
    $cultura = [System.Globalization.CultureInfo]::InvariantCulture
    return '[' + (($valores | ForEach-Object { ([double]$_).ToString('R', $cultura) }) -join ',') + ']'
}

# C: respuesta de qwen2.5:3b con temperatura 0 y sin streaming
function Get-RespuestaChat([string]$Sistema, [string]$Usuario) {
    $r = Invoke-Ollama '/api/chat' @{
        model    = 'qwen2.5:3b'
        stream   = $false
        options  = @{ temperature = 0 }
        messages = @(@{ role = 'system'; content = $Sistema }, @{ role = 'user'; content = $Usuario })
    }
    return $r.message.content
}

# D: ejecuta un procedimiento con parámetros (el vector viaja como parámetro, no en la línea de
#    comandos) y devuelve todos sus conjuntos de resultados
function Invoke-Procedimiento([string]$Servidor, [string]$Nombre, [hashtable]$Parametros) {
    $conexion = New-Object System.Data.SqlClient.SqlConnection "Server=$Servidor;Database=BajoElCapoDB;Integrated Security=true;TrustServerCertificate=true"
    $cmd = $conexion.CreateCommand()
    $cmd.CommandText = $Nombre
    $cmd.CommandType = [System.Data.CommandType]::StoredProcedure
    $cmd.CommandTimeout = 300
    foreach ($p in $Parametros.GetEnumerator()) {
        $valor = if ($null -eq $p.Value -or "$($p.Value)" -eq '') { [DBNull]::Value } else { $p.Value }
        [void]$cmd.Parameters.AddWithValue("@$($p.Key)", $valor)
    }
    $datos = New-Object System.Data.DataSet
    try {
        [void](New-Object System.Data.SqlClient.SqlDataAdapter $cmd).Fill($datos)
    } finally { $conexion.Dispose() }
    return ,$datos
}
