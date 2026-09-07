param(
    [string]$ModuleRoot = $PSScriptRoot,
    [Parameter(Mandatory = $true)][string]$ResultPath
)
$ErrorActionPreference = 'Stop'
$result = @{ gamePid = 0; running = $false; error = '' }
try {
    # Launched directly by the HLX game process, after the loader has finished.
    $gameProcessId = [int](Get-CimInstance Win32_Process -Filter "ProcessId=$PID").ParentProcessId
    if ($gameProcessId -le 0) { throw 'Could not identify the game process.' }
    $result.gamePid = $gameProcessId
    $moduleDirectory = [IO.Path]::GetFullPath($ModuleRoot)
    $uploaderPath = Join-Path $moduleDirectory 'uploader.exe'
    if (-not (Test-Path -LiteralPath $uploaderPath -PathType Leaf)) { throw 'uploader.exe was not installed in the dps-meter mod folder.' }
    $start = New-Object System.Diagnostics.ProcessStartInfo
    $start.FileName = $uploaderPath
    $start.Arguments = [string]$gameProcessId
    $start.WorkingDirectory = $moduleDirectory
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $process = [System.Diagnostics.Process]::Start($start)
    $process.Dispose()
    $result.running = $true
} catch {
    $result.error = $_.Exception.Message
}
# The uploader can keep inherited output pipes open. Use a complete status file
# instead, encoded without a BOM for Haxe's JSON reader.
$encoding = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($ResultPath + '.tmp', ($result | ConvertTo-Json -Compress), $encoding)
[IO.File]::Move($ResultPath + '.tmp', $ResultPath)
