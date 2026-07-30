# Protofluid Language Translator 2.0 (Zig)

**Ship product** — bare-metal densify translator people can run offline.  
**GitHub:** https://github.com/dappalumbo91/Protofluid-Language-Translator-2.0-Zig

**form → SENSE → form** · FSOT pin **D1D38A** · not NMT

**Competitive:** densify ship is usable; Python WMT ranking **beats NLLB gen** (~37). DeepL mid~40 is a separate stretch bar — not the whole story. See `docs/COMPETITIVE_STANCE.md`.

## Quick start (ship)

```powershell
cd dist\pflt-standalone
.\pflt.exe                              # TUI
.\pflt.exe translate de en "Die Katze ist frei"
.\pflt.exe translate la en "aqua et lex"
.\pflt.exe selftest
.\pflt.exe compare gold_pairs.tsv
```

Keep `densify_pack.tsv` next to `pflt.exe`.

## Build from source

```powershell
cd I:\pflt\embodiment\zig
python -u scripts\export_translate_pack.py   # multi-lang densify pack
zig build pflt
python -u scripts\ship_baseline_multilang.py
.\ship.ps1                                   # optional full package
```

## What ships today

| Piece | Status |
|-------|--------|
| **DE→EN densify** | Strong (closed-class + pack; baseline exact 1.0 on smoke suite) |
| **Multi-lang pack** | **114 langs**, ~386k form→EN sense binds |
| **Other → EN** | Usable densify where pack hits; misses pass through honestly |
| **TUI / decision log** | Yes (`logs/decisions.jsonl`) |
| **Sentence NMT fluency** | Not this binary — densify identity, not DeepL/LLM generation |

Baseline report: `reports/SHIP_BASELINE_MULTILANG.md`

## Relation

| Tree | Role |
|------|------|
| `I:\pflt` Python | densify mining, WMT competitive ranking |
| **This Zig tree** | shippable densify product |
| `I:\fsot nuron\embodiment\zig` | reference only |
