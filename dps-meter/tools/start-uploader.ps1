param([string]$ModuleRoot = $PSScriptRoot)
$ErrorActionPreference = 'Stop'
# This script is launched directly by the HLX game process. Resolve that parent
# before starting the unchanged uploader; it needs the game PID for shutdown.
$gameProcessId = [int](Get-CimInstance Win32_Process -Filter "ProcessId=$PID").ParentProcessId
if ($gameProcessId -le 0) { throw 'Could not identify the game process.' }
Write-Output "PID=$gameProcessId"
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
