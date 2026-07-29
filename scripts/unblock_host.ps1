# Unblock PFLT host binary after Windows Defender quarantine-style block.
# Run from elevated PowerShell if Set-MpPreference is needed.
$ErrorActionPreference = "Continue"
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not (Test-Path (Join-Path $PSScriptRoot "..\zig-out"))) {
    $root = Resolve-Path (Join-Path $PSScriptRoot "..")
} else {
    $root = Resolve-Path (Join-Path $PSScriptRoot "..")
}
Set-Location $root

Write-Host "Building host (no auto-run)..."
zig build host

$exe = Join-Path $root "zig-out\bin\pflt_host.exe"
if (-not (Test-Path $exe)) {
    # cache path fallback
    $cand = Get-ChildItem (Join-Path $root ".zig-cache\o") -Recurse -Filter "pflt_host.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cand) { $exe = $cand.FullName }
}
if (-not (Test-Path $exe)) { throw "pflt_host.exe not found" }

Write-Host "Unblock-File $exe"
Unblock-File -Path $exe -ErrorAction SilentlyContinue

# Zone.Identifier ADS removal
Remove-Item -Path ($exe + ":Zone.Identifier") -Force -ErrorAction SilentlyContinue

# Optional Defender exclusion (requires admin)
try {
    Add-MpPreference -ExclusionPath $root -ErrorAction Stop
    Write-Host "Added Defender exclusion for $root"
} catch {
    Write-Host "Defender exclusion skipped (need admin): $($_.Exception.Message)"
}

Write-Host "Running: $exe"
& $exe
exit $LASTEXITCODE
