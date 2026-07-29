# Protofluid Language Translator 2.0 (Zig)

**Product embodiment** at `I:\pflt\embodiment\zig`  
**Standalone GitHub tree:** `I:\Protofluid-Language-Translator-2.0-Zig`

Bare-metal translator people can run. form → SENSE → form. Pin D1D38A. Not NMT.

## Use

```powershell
zig build pflt
.\zig-out\bin\pflt.exe                          # modern TUI
.\zig-out\bin\pflt.exe translate de en "..."
.\zig-out\bin\pflt.exe compare data\gold_pairs.tsv
```

Decision log: `logs\decisions.jsonl` (method = closed | pack | miss, + duality).

See the standalone repo README for full TUI / compare / ship docs.

## Relation

| Tree | Role |
|------|------|
| `I:\pflt` Python lab | densify mining, WMT sacre probes |
| **This Zig tree** | shippable product + TUI + decision log |
| `I:\fsot nuron\embodiment\zig` | reference only — do not implement PFLT there |
