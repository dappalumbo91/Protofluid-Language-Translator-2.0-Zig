# Build freestanding PFLT kernel and run under QEMU (serial console).
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$zigCmd = Get-Command zig -ErrorAction SilentlyContinue
$zig = $null
if ($zigCmd) { $zig = $zigCmd.Source }
if (-not $zig) {
    $cand = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter zig.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
    if ($cand) { $zig = $cand }
}
if (-not $zig) { throw "zig not found on PATH" }

Write-Host "=== zig build kernel ($PSScriptRoot) ==="
& $zig build kernel

$kernelSrc = Join-Path $PSScriptRoot "zig-out\bin\pflt_kernel"
if (-not (Test-Path $kernelSrc)) {
    Write-Host "FAIL: kernel binary not found at $kernelSrc"
    exit 2
}

$qemuCmd = Get-Command qemu-system-x86_64 -ErrorAction SilentlyContinue
$qemu = $null
if ($qemuCmd) { $qemu = $qemuCmd.Source }
if (-not $qemu -and (Test-Path "C:\Program Files\qemu\qemu-system-x86_64.exe")) {
    $qemu = "C:\Program Files\qemu\qemu-system-x86_64.exe"
}
if (-not $qemu) {
    Write-Host "WARN: qemu-system-x86_64 not found - kernel at $kernelSrc"
    exit 0
}

$kernel = Join-Path $env:TEMP "pflt_kernel"
$serialLog = Join-Path $env:TEMP "pflt_qemu_serial.log"
$errLog = Join-Path $env:TEMP "pflt_qemu_err.log"
Copy-Item -Force $kernelSrc $kernel
Remove-Item $serialLog, $errLog -ErrorAction SilentlyContinue

Write-Host "=== QEMU (serial) ==="
$arg = "-display none -serial file:$serialLog -no-reboot -m 64M -kernel `"$kernel`""
$p = Start-Process -FilePath $qemu -ArgumentList $arg -PassThru -WindowStyle Hidden -RedirectStandardError $errLog
Start-Sleep -Seconds 15
if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }

Write-Host "--- serial output ---"
if (Test-Path $serialLog) {
    Get-Content $serialLog
    $txt = Get-Content $serialLog -Raw
    if ($txt -match "PFLT_KERNEL PASS") {
        Write-Host "=== QEMU GATE PASS ==="
        exit 0
    }
    Write-Host "=== QEMU GATE FAIL ==="
    exit 1
}
Write-Host "no serial log"
if (Test-Path $errLog) { Get-Content $errLog }
exit 1
