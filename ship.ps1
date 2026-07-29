# Package standalone PFLT translator for distribution.
# Output: dist\pflt-standalone\  (pflt.exe + densify_pack.tsv + README)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

Write-Host "Export densify pack..."
python -u scripts\export_translate_pack.py
if ($LASTEXITCODE -ne 0) { throw "export_translate_pack failed" }

Write-Host "Build pflt..."
zig build pflt -Doptimize=ReleaseSafe
if ($LASTEXITCODE -ne 0) { throw "zig build pflt failed" }

$Out = Join-Path $Root "dist\pflt-standalone"
New-Item -ItemType Directory -Force -Path $Out | Out-Null
Copy-Item -Force "zig-out\bin\pflt.exe" $Out
Copy-Item -Force "data\densify_pack.tsv" $Out
Copy-Item -Force "data\densify_pack.meta.json" $Out -ErrorAction SilentlyContinue

@"
PFLT — Protofluid Language Translator (standalone)
==================================================

form → SENSE → form  |  FSOT pin D1D38A  |  not NMT

Usage:
  pflt.exe translate de en "die regierung hat wasser"
  pflt.exe de en "Die Katze ist frei"
  pflt.exe --repl
  pflt.exe selftest

Keep densify_pack.tsv next to pflt.exe (or in data\).

"@ | Set-Content -Encoding utf8 (Join-Path $Out "README.txt")

Unblock-File (Join-Path $Out "pflt.exe") -ErrorAction SilentlyContinue
Write-Host "Shipped: $Out"
Get-ChildItem $Out | Format-Table Name, Length
