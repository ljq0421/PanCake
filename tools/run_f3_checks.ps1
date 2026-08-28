param(
	[int]$TimeoutSeconds = 60
)

# Historical entry point retained for local scripts. The production baseline is
# four areas; all automated headless checks are owned by run_checks.ps1.
& (Join-Path $PSScriptRoot 'run_checks.ps1') -TimeoutSeconds $TimeoutSeconds
exit $LASTEXITCODE
