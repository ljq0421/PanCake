param(
    [int]$TimeoutSeconds = 60,
    [int]$GpuTimeoutSeconds = 90,
    [switch]$SkipGpu
)

$ErrorActionPreference = 'Stop'
$shell = (Get-Process -Id $PID).Path
$stages = [System.Collections.Generic.List[object]]::new()

function Invoke-CheckStage {
    param(
        [string]$Name,
        [string]$ScriptPath,
        [string[]]$Arguments = @()
    )
    Write-Host "`n=== $Name ==="
    & $shell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Arguments
    $stages.Add([pscustomobject]@{ Name = $Name; ExitCode = [int]$LASTEXITCODE })
}

Invoke-CheckStage -Name 'Headless self-checks' -ScriptPath (Join-Path $PSScriptRoot 'run_checks.ps1') -Arguments @('-TimeoutSeconds', $TimeoutSeconds)
Invoke-CheckStage -Name 'P0.2 CPU benchmark' -ScriptPath (Join-Path $PSScriptRoot 'run_cpu_benchmark.ps1')
if (-not $SkipGpu) {
    Invoke-CheckStage -Name 'GPU smoke checks' -ScriptPath (Join-Path $PSScriptRoot 'run_gpu_smoke_checks.ps1') -Arguments @('-TimeoutSeconds', $GpuTimeoutSeconds)
}

Write-Host "`n=== Release check summary ==="
foreach ($stage in $stages) {
    $status = if ($stage.ExitCode -eq 0) { 'PASSED' } else { 'FAILED' }
    Write-Host ("{0,-8} {1} (exit {2})" -f $status, $stage.Name, $stage.ExitCode)
}
$failedStages = @($stages | Where-Object ExitCode -ne 0)
if ($failedStages.Count -gt 0) { exit 1 }

