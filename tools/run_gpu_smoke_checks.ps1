param(
    [int]$TimeoutSeconds = 90,
    [string]$Filter = '*_gpu_smoke.gd'
)

$ErrorActionPreference = 'Stop'
$godot = & (Join-Path $PSScriptRoot 'resolve_godot.ps1')
$project = Split-Path -Parent $PSScriptRoot
$sandboxRoot = Join-Path $project '.godot-user-gpu-checks'
$results = [System.Collections.Generic.List[object]]::new()
$failurePattern = 'SCRIPT ERROR|Parse Error|Failed loading resource|Cannot open file|Parameter "t" is null|RID allocations|FAIL:|GPU[_-]?SMOKE_FAIL|GPU-SMOKE FAIL'

if ($TimeoutSeconds -le 0) { throw 'TimeoutSeconds must be greater than zero.' }

$checks = @(Get-ChildItem -Path (Join-Path $project 'tests') -Recurse -File -Filter $Filter | Sort-Object FullName)
if ($checks.Count -eq 0) { throw "No GPU smoke checks matched: $Filter" }

$originalAppData = $env:APPDATA
$originalLocalAppData = $env:LOCALAPPDATA
try {
    foreach ($file in $checks) {
        $relative = $file.FullName.Substring($project.Length).TrimStart('\', '/') -replace '\\', '/'
        $checkPath = "res://$relative"
        $profileRoot = Join-Path $sandboxRoot $file.BaseName
        $roaming = Join-Path $profileRoot 'Roaming'
        $local = Join-Path $profileRoot 'Local'
        New-Item -ItemType Directory -Force -Path $roaming, $local | Out-Null
        $token = [Guid]::NewGuid().ToString('N')
        $log = Join-Path $env:TEMP "projectcake-gpu-$token.log"
        $stdout = Join-Path $env:TEMP "projectcake-gpu-$token.out"
        $stderr = Join-Path $env:TEMP "projectcake-gpu-$token.err"
        $timer = [Diagnostics.Stopwatch]::StartNew()
        $env:APPDATA = $roaming
        $env:LOCALAPPDATA = $local
        $process = Start-Process -FilePath $godot -ArgumentList @('--path', $project, '--log-file', $log, '-s', $checkPath) -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        $finished = $false
        $fatalDetected = $false
        while (-not $finished -and $timer.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
            $finished = $process.WaitForExit(250)
            if (-not $finished) {
                foreach ($candidate in @($log, $stdout, $stderr)) {
                    if ((Test-Path -LiteralPath $candidate) -and (Select-String -Path $candidate -Pattern $failurePattern -Quiet)) {
                        $fatalDetected = $true
                        Stop-Process -Id $process.Id -Force
                        $process.WaitForExit()
                        break
                    }
                }
            }
            if ($fatalDetected) { break }
        }
		$timer.Stop()
		$status = 'passed'
		$detail = ''
		if ($fatalDetected) {
			$status = 'failed'
			$detail = 'reported a fatal error before exit'
		}
		elseif (-not $finished) {
			Stop-Process -Id $process.Id -Force
			$status = 'timed_out'
            $detail = "exceeded $TimeoutSeconds seconds"
        }
        else {
            $process.WaitForExit()
            $process.Refresh()
            $exitCode = [int]$process.ExitCode
            if ($exitCode -ne 0) {
                $status = 'failed'
                $detail = "exit code $exitCode"
            }
        }
        $errors = @()
        foreach ($candidate in @($log, $stdout, $stderr)) {
            if (Test-Path -LiteralPath $candidate) {
                $errors += Select-String -Path $candidate -Pattern $failurePattern | ForEach-Object { $_.Line.Trim() }
            }
        }
        if ($status -eq 'passed' -and $errors.Count -gt 0) {
            $status = 'failed'
            $detail = 'reported parse/runtime/assertion error'
        }
		$result = [pscustomobject]@{
			Check = $checkPath
            Status = $status
            Seconds = [Math]::Round($timer.Elapsed.TotalSeconds, 2)
            Detail = $detail
			Log = $log
			Errors = @($errors | Select-Object -Unique)
		}
		$results.Add($result)
		Write-Host ("{0,-10} {1,7:N2}s  {2}" -f $result.Status.ToUpperInvariant(), $result.Seconds, $result.Check)
		if ($result.Detail) { Write-Host "           $($result.Detail)" }
		foreach ($line in $result.Errors) { Write-Host "           $line" }
		Write-Host "           log: $($result.Log)"
	}
}
finally {
    $env:APPDATA = $originalAppData
    $env:LOCALAPPDATA = $originalLocalAppData
}

$passed = @($results | Where-Object Status -eq 'passed').Count
$failed = @($results | Where-Object Status -eq 'failed').Count
$timedOut = @($results | Where-Object Status -eq 'timed_out').Count
Write-Host "GPU summary: total=$($results.Count) passed=$passed failed=$failed timed_out=$timedOut"
if ($failed + $timedOut -gt 0) { exit ($failed + $timedOut) }
