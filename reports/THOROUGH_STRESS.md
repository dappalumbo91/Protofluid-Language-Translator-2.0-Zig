# PFLT 2.0 Thorough Stress Report

- built: `2026-07-29T22:20:04.944555+00:00`
- elapsed_s: 31.58
- all_gates_pass: **True**

## Gates

- `PASS` selftest
- `PASS` gold_baseline_overlap_1
- `PASS` closed_identity_1
- `PASS` expanded_overlap_ge_0_85
- `PASS` bulk_exact_ge_0_75

## Baseline gold
```json
{
  "n": 10,
  "mean_overlap": 1.0,
  "mean_exact": 1.0,
  "duality_tokens": 0,
  "miss_tokens": 0,
  "returncode": 0
}
```

## Expanded gold
```json
{
  "n": 761,
  "mean_overlap": 0.999,
  "mean_exact": 1.0,
  "duality_tokens": 3,
  "miss_tokens": 0,
  "returncode": 0
}
```

## Bulk free-form
```json
{
  "n_phrases": 50,
  "tokens": 273,
  "resolved": 273,
  "miss": 0,
  "duality": 6,
  "closed": 260,
  "pack": 13,
  "exact_rate": 1.0,
  "miss_rate": 0.0,
  "duality_rate": 0.02197802197802198
}
```

### Weak phrases (miss or low exact)


## Closed-class identity
- rate: 1.0000 (180/180)
- fails: 0

## Top miss forms (refinement targets)


## Top duality forms

- `menschen` × 4
- `mensch` × 3
- `mein` × 2
- `meine` × 1
- `macht` × 1

## Competitive note

Token densify identity is not full sacreBLEU fluency. Use miss/duality lists to densify pack.
Lab product lock ~37.22 sacre remains Python ranking path; Zig 2.0 is shippable densify app.
