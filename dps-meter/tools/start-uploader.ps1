param(
    [string]$ModuleRoot = $PSScriptRoot,
    [Parameter(Mandatory = $true)][string]$ResultPath
)
$ErrorActionPreference = 'Stop'
$result = @{ gamePid = 0; running = $false; error = '' }
$encoding = New-Object System.Text.UTF8Encoding($false)
try {
    # Launched directly by the HLX game process, after the loader has finished.
    $gameProcessId = [int](Get-CimInstance Win32_Process -Filter "ProcessId=$PID").ParentProcessId
    if ($gameProcessId -le 0) { throw 'Could not identify the game process.' }
    $result.gamePid = $gameProcessId
    $moduleDirectory = [IO.Path]::GetFullPath($ModuleRoot)
    $uploaderPath = Join-Path $moduleDirectory 'uploader.exe'
    if (-not (Test-Path -LiteralPath $uploaderPath -PathType Leaf)) { throw 'uploader.exe was not installed in the dps-meter mod folder.' }
    $iniPath = Join-Path $moduleDirectory 'uploader.ini'
    if (Test-Path -LiteralPath $iniPath -PathType Leaf) {
        $oldHeader = @(
            "; Configuration de l'uploader farever-group-dps",
            '; api_url : adresse de l''API qui recoit les runs',
            ';           (http://localhost:3333/api/v1/runs pour un test en local)',
            '; token   : laisser vide (servira plus tard pour les comptes du site)',
            '; keep_days : jours de conservation des runs deja envoyes (0 = tout garder)'
        )
        [string[]]$lines = [IO.File]::ReadAllLines($iniPath)
        [string[]]$cleanLines = @($lines | Where-Object { $oldHeader -cnotcontains $_ })
        if ($cleanLines.Length -ne $lines.Length) {
            [IO.File]::WriteAllLines($iniPath, $cleanLines, $encoding)
        }
    } else {
        [IO.File]::WriteAllLines($iniPath, [string[]]@(
            'api_url=https://fareverlogs.fr/api/v1/runs',
            'token=',
            'poll_sec=5',
            'keep_days=7'
        ), $encoding)
    }
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
[IO.File]::WriteAllText($ResultPath + '.tmp', ($result | ConvertTo-Json -Compress), $encoding)
[IO.File]::Move($ResultPath + '.tmp', $ResultPath)
