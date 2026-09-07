$ErrorActionPreference = 'Stop'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("DPS meter's launcher test " + [Guid]::NewGuid())
$stub = $null
$launcher = $null
try {
    [void][IO.Directory]::CreateDirectory($testRoot)
    # A local stub only: never execute the supplied uploader or contact Farever Logs.
    Add-Type -OutputAssembly (Join-Path $testRoot 'uploader.exe') -OutputType ConsoleApplication -TypeDefinition @'
using System;
using System.Diagnostics;
using System.IO;
using System.Threading;
public class UploaderStub {
    public static void Main(string[] args) {
        File.WriteAllLines(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "started.txt"),
            new[] { Process.GetCurrentProcess().Id.ToString(), args[0], Environment.CurrentDirectory });
        Thread.Sleep(30000);
    }
}
'@
    $script = Get-Content -Raw (Join-Path $PSScriptRoot '../tools/start-uploader.ps1')
    foreach ($missing in @($false, $true)) {
        $moduleRoot = if ($missing) { Join-Path $testRoot 'missing helper' } else { $testRoot }
        [void][IO.Directory]::CreateDirectory($moduleRoot)
        $resultPath = Join-Path $moduleRoot 'startup.json'
        $command = "& {`n" + $script + "`n} -ModuleRoot '" + $moduleRoot.Replace("'", "''") + "' -ResultPath '" + $resultPath.Replace("'", "''") + "'"
        $start = New-Object System.Diagnostics.ProcessStartInfo
        $start.FileName = 'powershell.exe'
        $start.Arguments = '-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -EncodedCommand ' + [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
        $start.UseShellExecute = $false
        $start.CreateNoWindow = $true
        $launcher = [Diagnostics.Process]::Start($start)
        if (-not $launcher.WaitForExit(15000)) { throw 'Launcher waited for the long-lived helper.' }
        if ($launcher.ExitCode -ne 0) { throw "Launcher failed: $($launcher.ExitCode)" }
        $launcher.Dispose()
        $launcher = $null
        $bytes = [IO.File]::ReadAllBytes($resultPath)
        if ($bytes[0] -ne 123) { throw 'Startup JSON must begin with {, without a BOM.' }
        $result = [Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json
        if ($result.gamePid -ne $PID) { throw 'Incorrect parent game PID.' }
        if (Test-Path ($resultPath + '.tmp')) { throw 'Startup result was not renamed atomically.' }
        if ($missing) {
            if ($result.running -or $result.error -notmatch 'not installed') { throw 'Missing helper was not reported.' }
        } else {
            if (-not $result.running -or $result.error) { throw 'Successful helper launch was not reported.' }
            $marker = Join-Path $testRoot 'started.txt'
            $deadline = [DateTime]::UtcNow.AddSeconds(5)
            while (-not (Test-Path $marker) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
            $lines = Get-Content $marker
            $stub = [Diagnostics.Process]::GetProcessById([int]$lines[0])
            if ($stub.HasExited) { throw 'Readiness was not reported while the helper was still running.' }
            if ([int]$lines[1] -ne $PID -or $lines[2] -ne $testRoot) { throw 'Wrong helper PID argument or working directory.' }
        }
    }
    Write-Output 'Windows launcher checks passed: readiness before helper exit, parent PID, mod paths, BOM-free JSON, missing helper.'
} finally {
    foreach ($child in @($launcher, $stub)) {
        if ($null -ne $child) {
            if (-not $child.HasExited) { $child.Kill(); [void]$child.WaitForExit(5000) }
            $child.Dispose()
        }
    }
    Remove-Item -LiteralPath $testRoot -Recurse -Force
}
