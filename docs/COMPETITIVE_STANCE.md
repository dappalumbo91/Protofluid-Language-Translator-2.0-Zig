# PFLT Zig 2.0 — competitive stance (honest)

Pin **D1D38A**. Doctrine: **form → SENSE → form** densify. Not NMT.

## Two products, one law

| Layer | Where | Metric | Where we stand |
|-------|--------|--------|----------------|
| **Ship densify app** | This Zig tree | form→sense exact, gold overlap, usable DE→EN | Strong on densify identity; standalone binary |
| **WMT news ranking** | Python lab `I:\pflt` | sacreBLEU de→en | **~37.0** product path · beats NLLB gen **36.81** · DeepL mid **40** still **~3** above |

Zig does **not** embed NLLB students. WMT ~37 is densify+law **ranking of student hyps** in Python.  
Zig is the **bare-metal densify translator** people can run offline.

## What we solidified into Zig

- Finite densify pack (`data/densify_pack.tsv`) + closed-class table (wins over pack debris)
- Decision log: method `closed|pack|miss` + yin–yang duality when pack disagrees
- TUI + CLI + gold compare harness
- FSOT law panel smoke (S≈0.43232, pin D1D38A)
- Thorough stress script (`scripts/thorough_stress.py`)

## Competitive honesty (DeepL gap)

DeepL mid~40 on WMT is commercial neural MT (massive parallel data + proprietary decoding).  
Our path is **intrinsic densify + law certification**, optionally ranking open students:

- Beating **NLLB student gen** is real.
- Matching **DeepL mid** is not claimed and may require densify coverage / pool quality we do not cheat on.
- Pool oracle on WMT (~43.5) shows headroom in **candidates**, not free QE knobs.

We do **not** soft-fuse free params to fake BLEU. If densify does not separate, law certifies — honest.

## Refine next (both trees)

1. Grow densify content binds (miss list from decision log / stress).
2. Keep closed-class last (duality = pack hygiene targets).
3. Python: densify that separates more often on WMT (79/3003 today).
4. Zig: export multi-lang densify packs when DE→EN ship is solid.

## Commands

```powershell
cd I:\pflt\embodiment\zig
python -u scripts\export_translate_pack.py
zig build pflt
.\zig-out\bin\pflt.exe selftest
.\zig-out\bin\pflt.exe compare data\gold_pairs.tsv
python -u scripts\thorough_stress.py
.\zig-out\bin\pflt.exe   # TUI
```
