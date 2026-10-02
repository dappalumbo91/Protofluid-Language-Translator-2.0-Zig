#!/usr/bin/env python3
"""
Parity harness: Python FSOT pin standards vs Zig pflt_stress METRIC lines.

Writes report to protofluid-language-translator/pflt-Ada/reports (not Desktop).

  cd .
  zig build stress
  python scripts\\parity_python.py
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]  # protofluid-language-translator
ZIG = Path(__file__).resolve().parents[1]
REP = ROOT / "pflt-Ada" / "reports"

sys.path.insert(0, str(ROOT))


def run_zig_stress() -> tuple[str, int]:
    exe = ZIG / "zig-out" / "bin" / "pflt_stress.exe"
    if not exe.is_file():
        # build
        subprocess.check_call(["zig", "build", "stress"], cwd=str(ZIG))
    # unblock
    try:
        subprocess.check_call(
            ["powershell", "-NoProfile", "-Command", f'Unblock-File -Path "{exe}"'],
        )
    except Exception:
        pass
    r = subprocess.run([str(exe)], capture_output=True, text=True, cwd=str(ZIG))
    out = (r.stdout or "") + (r.stderr or "")
    return out, r.returncode


def parse_metrics(text: str) -> dict:
    m = {}
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("METRIC "):
            body = line[len("METRIC ") :]
            if "=" not in body:
                continue
            k, v = body.split("=", 1)
            try:
                if "," in v:
                    m[k] = v  # codon list
                elif "." in v:
                    m[k] = float(v)
                else:
                    m[k] = int(v)
            except ValueError:
                m[k] = v
    return m


def python_standards() -> dict:
    from fsot_authority_gate import run_authority_gate
    from mpmath import mpf
    from scripts.fsot_seed_push import load_authority
    from scripts.fsot_machine_form import machine_align

    run_authority_gate(fail_closed=True)
    mod, path, pin_ok, dig = load_authority()
    s_in = mod.ScalarInput(
        N=mpf(4),
        P=mpf(3),
        D_eff=mpf(13),
        delta_psi=mpf("0.1"),
        delta_theta=mpf(1),
        recent_hits=mpf(0),
        rho=mpf(1),
        observed=True,
        scale=mpf(1),
        amplitude=mpf(1),
        trend_bias=mpf(0),
    )
    S = float(mod.compute_scalar(s_in))
    densify_pairs = [
        ("die", "the"),
        ("hat", "has"),
        ("sein", "be"),
        ("regierung", "government"),
        ("wasser", "water"),
        ("frei", "free"),
        ("wirtschaft", "economy"),
        ("polizei", "police"),
        ("wird", "will"),
        ("fuer", "for"),
    ]
    # use Zig densify table via import densify is zig-only; check interlingua
    from scripts.fsot_sense_rank_climb import _resolve_de
    from sense_interlingua import SenseInterlingua

    ix = SenseInterlingua()
    dens_hits = 0
    for de, en in densify_pairs:
        r = _resolve_de(de, ix)
        if r and (r.canonical_en or "").lower() == en:
            dens_hits += 1

    align_good = machine_align("Die Regierung 2024", "The government 2024")
    align_bad = machine_align(
        "Die Regierung 2024", bytes([0xE6, 0x94, 0xBF, 0xE5, 0xBA, 0x9C, 0x20, 0x32, 0x30, 0x32, 0x34]).decode("latin-1")
    )

    return {
        "pin_ok": pin_ok,
        "authority": str(path),
        "K": float(mod.K),
        "PHI": float(mod.PHI),
        "C_EFF": float(mod.C_EFF),
        "E": float(mod.E),
        "PI": float(mod.PI),
        "GAMMA": float(mod.GAMMA),
        "ALPHA": float(mod.ALPHA),
        "S_neuro_d13": S,
        "densify_pairs": densify_pairs,
        "densify_hits": dens_hits,
        "densify_n": len(densify_pairs),
        "align_good": align_good,
        "align_bad": align_bad,
        "codon_ATG": [1, -1, 1],
        "product_lock_sacre": 37.22,  # Python lab probe bar (not kernel metric)
    }


def near(a: float, b: float, rel: float = 1e-6, abs_tol: float = 1e-4) -> bool:
    return abs(a - b) <= max(abs_tol, rel * max(abs(a), abs(b), 1e-12))


def main() -> int:
    print("=== PFLT parity: Python standards vs Zig stress ===", flush=True)
    py = python_standards()
    print("Python pin_ok", py["pin_ok"], "S_neuro", py["S_neuro_d13"], flush=True)

    # ensure stress binary
    subprocess.check_call(["zig", "build", "stress"], cwd=str(ZIG))
    zig_out, rc = run_zig_stress()
    print(zig_out, flush=True)
    zm = parse_metrics(zig_out)

    checks = []

    def chk(name: str, ok: bool, detail: str = "") -> None:
        checks.append({"name": name, "ok": ok, "detail": detail})
        print(f"  {'PASS' if ok else 'FAIL'} {name} {detail}", flush=True)

    # seed parity
    for key, pyk in [
        ("seed_K_f64", "K"),
        ("seed_PHI_f64", "PHI"),
        ("seed_C_EFF_f64", "C_EFF"),
        ("seed_E_f64", "E"),
        ("seed_PI_f64", "PI"),
        ("seed_GAMMA_f64", "GAMMA"),
        ("seed_ALPHA_f64", "ALPHA"),
    ]:
        if key in zm:
            chk(
                key,
                near(float(zm[key]), float(py[pyk]), abs_tol=5e-10),
                f"zig={zm[key]} py={py[pyk]}",
            )

    # codon ATG
    if "codon_ATG" in zm:
        chk("codon_ATG", str(zm["codon_ATG"]).replace(" ", "") in ("1,-1,1", "1, -1, 1"), str(zm["codon_ATG"]))

    # scalar band vs Python D=13 neuro panel
    if "S_neuro_dpsi0.1_f64" in zm:
        zs = float(zm["S_neuro_dpsi0.1_f64"])
        chk(
            "S_neuro_vs_python",
            near(zs, py["S_neuro_d13"], abs_tol=0.02),  # fixed-point vs mpmath room
            f"zig={zs} py={py['S_neuro_d13']}",
        )

    # densify: zig internal rate must be 1.0 on closed table
    if "densify_rate" in zm:
        chk("zig_densify_rate", float(zm["densify_rate"]) >= 0.999, str(zm["densify_rate"]))

    # machine form: good > pollute
    if "align_good_milli" in zm and "align_pollute_milli" in zm:
        chk(
            "align_order",
            int(zm["align_good_milli"]) > int(zm["align_pollute_milli"]),
            f"good={zm['align_good_milli']} bad={zm['align_pollute_milli']}",
        )
    # python align order
    chk("python_align_order", py["align_good"] > py["align_bad"], f"{py['align_good']} > {py['align_bad']}")

    # frame RT
    if "frame_rt_ok" in zm and "frame_rt_n" in zm:
        chk(
            "frame_roundtrip",
            int(zm["frame_rt_ok"]) == int(zm["frame_rt_n"]) and int(zm["frame_rt_n"]) > 0,
            f"{zm.get('frame_rt_ok')}/{zm.get('frame_rt_n')}",
        )

    # stress overall
    chk("zig_stress_exit", rc == 0 and "STRESS PASS" in zig_out, f"rc={rc}")

    n_ok = sum(1 for c in checks if c["ok"])
    report = {
        "built_utc": datetime.now(timezone.utc).isoformat(),
        "python": {k: v for k, v in py.items() if k != "densify_pairs"},
        "zig_metrics": zm,
        "checks": checks,
        "pass": n_ok,
        "n_checks": len(checks),
        "all_pass": n_ok == len(checks),
        "note": (
            "Bare-metal parity on seeds/scalar/trit/densify/machine-form/frames. "
            "Python product lock sacre 37.22 is NLLB-hyp probe — not a kernel metric."
        ),
    }
    REP.mkdir(parents=True, exist_ok=True)
    (REP / "PFLT_ZIG_PARITY.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    md = [
        "# PFLT Zig ↔ Python parity",
        "",
        f"**{n_ok}/{len(checks)} checks pass** · all_pass={report['all_pass']}",
        "",
        report["note"],
        "",
        "| check | ok | detail |",
        "|-------|:--:|--------|",
    ]
    for c in checks:
        md.append(f"| {c['name']} | {'yes' if c['ok'] else 'NO'} | {c['detail']} |")
    md += [
        "",
        "## Python standards",
        f"- pin K={py['K']:.12g} PHI={py['PHI']:.12g}",
        f"- S neuro D=13 dpsi=0.1 → **{py['S_neuro_d13']:.12g}**",
        f"- densify interlingua sample {py['densify_hits']}/{py['densify_n']}",
        f"- product lock sacre (lab only) {py['product_lock_sacre']}",
        "",
        "## Zig stress metrics (subset)",
    ]
    for k in sorted(zm.keys()):
        md.append(f"- `{k}` = `{zm[k]}`")
    (REP / "PFLT_ZIG_PARITY.md").write_text("\n".join(md), encoding="utf-8")
    print(f"WROTE {REP / 'PFLT_ZIG_PARITY.md'}", flush=True)
    return 0 if report["all_pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
