# Protofluid Language Translator 2.0 (Zig)

**Standalone bare-metal translator** — form → SENSE → form.  
Not NMT. Finite densify table + FSOT law pin **D1D38A**.

Ship a single binary people can run. Interactive TUI for input/output,  
decision logs for refinement (misses, pack debris, yin–yang duality overrides),  
and comparative gold eval for competitive probing.

```
form  ──densify──►  SENSE  ──render──►  surface
          │
     closed-class wins over pack debris
```

## Requirements

- [Zig](https://ziglang.org/) **0.15+**
- Windows Terminal / modern console (ANSI colors)
- Optional: Python 3 to re-export densify pack from a lab tree

## Quick start

```powershell
# Build product
zig build pflt

# Modern TUI (default)
.\zig-out\bin\pflt.exe

# One-shot translate
.\zig-out\bin\pflt.exe translate de en "die regierung hat wasser"

# Competitive gold compare
.\zig-out\bin\pflt.exe compare data\gold_pairs.tsv

# Decision log is written to logs\decisions.jsonl
```

Portable ship folder:

```powershell
.\ship.ps1
# → dist\pflt-standalone\  (pflt.exe + densify_pack.tsv)
```

## TUI

```
+--------------------------------------------------------------------------+
| PFLT 2.0  ·  form→SENSE→form                                             |
| pin D1D38A   de→en   pack N rows   log logs/decisions.jsonl              |
+--------------------------------------------------------------------------+
| IN     die regierung hat wasser                                          |
| OUT    the government has water                                          |
| REF    (optional :ref ...)                                               |
+--------------------------------------------------------------------------+
| DECISION LOG  closed=… pack=… miss=… duality=…                           |
| #  form        method   sense      alt/duality                           |
+--------------------------------------------------------------------------+
  pflt▸
```

| Command | Action |
|---------|--------|
| `<text>` | Translate |
| `:src de` / `:tgt en` | Languages |
| `:ref <gold EN>` | Live compare against a reference |
| `:compare path.tsv` | Batch gold eval |
| `:log path` | Decision JSONL path |
| `:help` / `:q` | Help / quit |

### Decision methods

| Method | Meaning |
|--------|---------|
| `closed` | Embedded DE closed-class (always wins over pack debris) |
| `pack` | Content bind from `data/densify_pack.tsv` |
| `miss` | No bind — honest pass-through (competitive gap) |
| `duality` | Closed overrode a **different** pack sense (yin–yang / densify debris) |

Use duality + miss rows in `logs/decisions.jsonl` to target pack hygiene and closed-class fixes.

## Comparative eval

Gold TSV format:

```text
# src_lang	tgt_lang	source	reference
de	en	Die Katze ist frei	the cat is free
```

```powershell
pflt compare data\gold_pairs.tsv
```

Reports token overlap vs reference, exact densify rate, duality and miss counts.

## Doctrine

| Layer | Role |
|-------|------|
| Machine tongue | Trits / frames (`pflt_machine_lang`) |
| Human language | Finite densify (`densify_fixed` + pack) |
| Machine form | Script/digit conservation |
| Law | \(S=K(T_1+T_2+T_3)\) fixed-point, pin D1D38A |

**No multi-GB catalogs in the binary. No NMT product. No free-param QE.**

## Layout

```
src/
  main_translate.zig   # CLI + default TUI entry
  tui.zig              # modern terminal UI
  translate.zig        # form→SENSE→surface + metrics
  densify_pack.zig     # pack load + densifyTrace
  densify_fixed.zig    # closed-class (wins over pack)
  decision_log.zig     # JSONL decision log
  ...
data/
  densify_pack.tsv     # ship with binary
  gold_pairs.tsv       # competitive probe pairs
logs/
  decisions.jsonl      # generated session log
```

## Competitive path

1. Run TUI / `compare` against real references (WMT-style lines, human refs).
2. Read `logs/decisions.jsonl` for `miss` and `duality`.
3. Add pack binds or closed-class overrides; re-export pack if needed.
4. Re-run compare; push mean token overlap / densify coverage.

Lab densify mining may live elsewhere; **this repo is the shippable 2.0 product.**

## Build targets

| Step | Output |
|------|--------|
| `zig build pflt` | Product CLI + TUI |
| `zig build host` | Substrate self-test |
| `zig build stress` | Metric dump |
| `zig build kernel` | Freestanding Multiboot (QEMU) |

## Publish to GitHub

```powershell
cd I:\Protofluid-Language-Translator-2.0-Zig
gh auth login
gh repo create Protofluid-Language-Translator-2.0-Zig --public --source=. --remote=origin --push
```

## License

MIT — see [LICENSE](LICENSE).
