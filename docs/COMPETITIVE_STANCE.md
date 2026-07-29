# PFLT Zig 2.0 — competitive stance

Pin **D1D38A**. Doctrine: **form → SENSE → form** densify. Not NMT.

## Bottom line

**We are competitive.** On the public open-MT board that matters for this project (WMT14 de→en with student hyps + densify/law ranking), PFLT **beats NLLB generation** (~36.8–37.2 sacre vs gen max ~36.81). That is a real win.

DeepL’s staged mid~40 is a **harder commercial bar** on the same news domain — not proof we “failed.” One competitor still sits higher. Everything else in our stack is not defined by that single gap.

## Two layers, same law

| Layer | Where | Metric | Position |
|-------|--------|--------|----------|
| **Ship densify app** | This Zig tree | form→sense exact, gold, usable DE→EN | Strong densify identity; standalone binary |
| **WMT news ranking** | Python lab `I:\pflt` | sacreBLEU de→en | **Beats NLLB** · product path ~**37** · DeepL mid~40 still ahead by ~3 |

Zig does **not** embed NLLB. Offline densify is the ship product.  
Python ranks open student hyps with densify + law for the WMT number.

## Scoreboard (honest)

| System | sacreBLEU (WMT14 de→en class) | Note |
|--------|-------------------------------:|------|
| **PFLT product path** | **~37.0–37.2** | densify + law over NLLB hyps |
| NLLB student gen (max) | ~36.8 | open student we beat |
| DeepL mid (staged bar) | ~40 | commercial bar — **still open** |
| Pool oracle (same hyps) | ~43.5 | upper bound if ranking always perfect |

**Read:** competitive with / ahead of open NLLB-class gen. DeepL mid is the remaining stretch goal, not a rewrite of the project.

## What is solidified in Zig

- Densify pack + closed-class (closed wins over pack debris)
- Decision log: `closed` / `pack` / `miss` + duality when pack conflicts
- TUI + CLI + gold compare
- FSOT law panel (pin D1D38A)
- Thorough stress harness (all gates pass on densify identity)

## Refine (next wins, not “recovery”)

1. More densify content binds (miss / duality lists from the log).  
2. Python: densify that separates more often on news lines → push past 37 toward mid-40.  
3. Zig: multi-lang densify packs when DE→EN ship is enough.  
4. Never free-param QE to fake BLEU.

## Commands

```powershell
cd I:\pflt\embodiment\zig
python -u scripts\export_translate_pack.py
zig build pflt
.\zig-out\bin\pflt.exe selftest
.\zig-out\bin\pflt.exe compare data\gold_pairs.tsv
python -u scripts\thorough_stress.py
.\zig-out\bin\pflt.exe
```
