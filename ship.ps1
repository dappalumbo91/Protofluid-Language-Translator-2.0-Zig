# Package standalone PFLT translator for distribution.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

Write-Host "Export multi-lang densify pack..."
python -u scripts\export_translate_pack.py
if ($LASTEXITCODE -ne 0) { throw "export_translate_pack failed" }

Write-Host "Build pflt (ReleaseSafe)..."
# prefer clean install; if locked, build still may have cache exe
try {
  zig build pflt -Doptimize=ReleaseSafe
} catch {
  Write-Host "Release install warning: $_ — trying default build"
  zig build pflt
}
if (-not (Test-Path "zig-out\bin\pflt.exe")) { throw "pflt.exe missing" }

$Out = Join-Path $Root "dist\pflt-standalone"
New-Item -ItemType Directory -Force -Path $Out | Out-Null
Copy-Item -Force "zig-out\bin\pflt.exe" $Out
Copy-Item -Force "data\densify_pack.tsv" $Out
Copy-Item -Force "data\densify_pack.meta.json" $Out -ErrorAction SilentlyContinue
Copy-Item -Force "data\gold_pairs.tsv" $Out -ErrorAction SilentlyContinue
Copy-Item -Force "docs\COMPETITIVE_STANCE.md" $Out -ErrorAction SilentlyContinue
Copy-Item -Force "README.md" $Out -ErrorAction SilentlyContinue

@"
PFLT — Protofluid Language Translator 2.0 (Zig)
===============================================

form -> SENSE -> form  |  FSOT pin D1D38A  |  densify (not NMT)

Usage:
  pflt.exe                          interactive TUI
  pflt.exe translate de en "..."
  pflt.exe translate fr en "..."
  pflt.exe translate la en "aqua"
  pflt.exe compare gold_pairs.tsv
  pflt.exe selftest

Keep densify_pack.tsv next to pflt.exe (or in data\).

DE->EN is the strongest path. Other langs use pack densify to EN sense heads.
Competitive: densify ship + Python WMT path beats NLLB gen; DeepL mid is a stretch bar.

"@ | Set-Content -Encoding utf8 (Join-Path $Out "README.txt")

Unblock-File (Join-Path $Out "pflt.exe") -ErrorAction SilentlyContinue

Write-Host "Baseline multi-lang smoke..."
python -u scripts\ship_baseline_multilang.py
Copy-Item -Force "reports\SHIP_BASELINE_MULTILANG.md" $Out -ErrorAction SilentlyContinue
Copy-Item -Force "reports\SHIP_BASELINE_MULTILANG.json" $Out -ErrorAction SilentlyContinue

Write-Host "Shipped: $Out"
Get-ChildItem $Out | Format-Table Name, Length
