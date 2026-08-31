param([int]$TimeoutSeconds = 60)

$ErrorActionPreference = 'Stop'
$godot = & (Join-Path $PSScriptRoot 'resolve_godot.ps1')
$project = Split-Path -Parent $PSScriptRoot
$sandboxRoot = Join-Path $project '.godot-user-checks'
$results = [System.Collections.Generic.List[object]]::new()
$failurePattern = 'SCRIPT ERROR|Parse Error|Failed loading resource|Cannot open file|Parameter "t" is null|RID allocations|FAIL:|SELF[_-]?CHECK_FAIL|SELF-CHECK FAIL'

if ($TimeoutSeconds -le 0) { throw 'TimeoutSeconds must be greater than zero.' }

$sharedProfiles = @{
    'res://tests/integration/four_area_first_day_e2e_self_check.gd' = @{ Name = 'four-area-e2e'; Priority = 0 }
    'res://tests/integration/four_area_existing_save_e2e_self_check.gd' = @{ Name = 'four-area-e2e'; Priority = 1 }
}
$checks = foreach ($file in (Get-ChildItem -Path (Join-Path $project 'tests') -Recurse -File -Filter '*_self_check.gd' | Where-Object { $_.FullName -match '[\\/](unit|integration)[\\/]' } | Sort-Object FullName)) {
    $relative = $file.FullName.Substring($project.Length).TrimStart('\', '/') -replace '\\', '/'
    $path = "res://$relative"
    $shared = $sharedProfiles[$path]
    [pscustomobject]@{
        Path = $path
        Profile = if ($null -eq $shared) { "check-$($file.BaseName)" } else { $shared.Name }
        Priority = if ($null -eq $shared) { 10 } else { [int]$shared.Priority }
    }
}

foreach ($check in ($checks | Sort-Object Priority, Path)) {
    $profileRoot = Join-Path $sandboxRoot $check.Profile
    $roaming = Join-Path $profileRoot 'Roaming'
    $local = Join-Path $profileRoot 'Local'
    New-Item -ItemType Directory -Force -Path $roaming, $local | Out-Null
    $token = [Guid]::NewGuid().ToString('N')
    $log = Join-Path $env:TEMP "projectcake-check-$token.log"
    $stdout = Join-Path $env:TEMP "projectcake-check-$token.out"
    $stderr = Join-Path $env:TEMP "projectcake-check-$token.err"
    $timer = [Diagnostics.Stopwatch]::StartNew()
    # Windows PowerShell 5.1 has no Start-Process -Environment parameter.
    # Processes are launched serially, so assigning the inherited variables here
    # keeps every self-check isolated on both Windows PowerShell and pwsh.
    $env:APPDATA = $roaming
    $env:LOCALAPPDATA = $local
    $process = Start-Process -FilePath $godot -ArgumentList @('--headless', '--path', $project, '--log-file', $log, '-s', $check.Path) -NoNewWindow -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $finished = $process.WaitForExit($TimeoutSeconds * 1000)
    $timer.Stop()
    $status = 'passed'
    $detail = ''
    if (-not $finished) { Stop-Process -Id $process.Id -Force; $status = 'timed_out'; $detail = "exceeded $TimeoutSeconds seconds" }
    else {
        # WaitForExit(timeout) can expose a stale ExitCode through Windows
        # PowerShell when output is redirected. A final unbounded wait and
        # refresh guarantees that successful checks do not become false fails.
        $process.WaitForExit()
        $process.Refresh()
        $exitCode = [int]$process.ExitCode
        if ($exitCode -ne 0) { $status = 'failed'; $detail = "exit code $exitCode" }
    }
    $errors = @()
    foreach ($candidate in @($log, $stdout, $stderr)) {
        if (Test-Path -LiteralPath $candidate) { $errors += Select-String -Path $candidate -Pattern $failurePattern | ForEach-Object { $_.Line.Trim() } }
    }
    if ($status -eq 'passed' -and $errors.Count -gt 0) { $status = 'failed'; $detail = 'reported parse/runtime/assertion error' }
    $results.Add([pscustomobject]@{ Check = $check.Path; Status = $status; Seconds = [Math]::Round($timer.Elapsed.TotalSeconds, 2); Detail = $detail; Log = $log; Errors = @($errors | Select-Object -Unique) })
}

foreach ($result in $results) {
    Write-Host ("{0,-10} {1,7:N2}s  {2}" -f $result.Status.ToUpperInvariant(), $result.Seconds, $result.Check)
    if ($result.Detail) { Write-Host "           $($result.Detail)" }
    foreach ($line in $result.Errors) { Write-Host "           $line" }
    Write-Host "           log: $($result.Log)"
}
$passed = @($results | Where-Object Status -eq 'passed').Count
$failed = @($results | Where-Object Status -eq 'failed').Count
$timedOut = @($results | Where-Object Status -eq 'timed_out').Count
Write-Host "Summary: total=$($results.Count) passed=$passed failed=$failed timed_out=$timedOut"
if ($failed + $timedOut -gt 0) { exit ($failed + $timedOut) }
