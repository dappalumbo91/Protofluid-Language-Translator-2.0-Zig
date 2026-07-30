#!/usr/bin/env python3
"""
Shippable multi-lang densify baseline — smoke translations via pflt.exe.

Runs representative phrases across pack languages, logs exact_rate / misses.
Writes reports/SHIP_BASELINE_MULTILANG.{json,md}

  python -u scripts/ship_baseline_multilang.py
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
# Prefer ship dist, then zig-out
_BIN_CANDIDATES = [
    ROOT / "dist" / "pflt-standalone" / "pflt.exe",
    ROOT / "zig-out" / "bin" / "pflt.exe",
]
BIN = next((p for p in _BIN_CANDIDATES if p.is_file()), _BIN_CANDIDATES[-1])
PACK = ROOT / "data" / "densify_pack.tsv"
if not PACK.is_file():
    PACK = ROOT / "dist" / "pflt-standalone" / "densify_pack.tsv"
REP = ROOT / "reports"

# (src_lang, text, note) — densify identity to EN
CASES = [
    # DE — strongest ship path
    ("de", "die regierung hat wasser und gesetz", "de core"),
    ("de", "Die Katze ist frei", "de closed+content"),
    ("de", "Hallo Welt ich bin frei", "de greetings"),
    ("de", "die polizei und die stadt", "de news"),
    ("de", "mein hund und meine katze", "de possessives"),
    # EN identity
    ("en", "water and law and free", "en identity"),
    ("en", "the government has water", "en identity"),
    # Romance / common modern (pack-dependent)
    ("fr", "eau et chat et libre", "fr sample"),
    ("fr", "la ville et la police", "fr sample"),
    ("es", "agua y gato y libre", "es sample"),
    ("es", "la ciudad y la policía", "es sample"),
    ("it", "acqua e gatto e libero", "it sample"),
    ("pt", "agua e gato e livre", "pt sample"),
    ("nl", "water en kat en vrij", "nl sample"),
    ("pl", "woda i kot i wolny", "pl sample"),
    ("ru", "вода и кот и свободный", "ru sample"),
    ("sv", "vatten och katt och fri", "sv sample"),
    ("da", "vand og kat og fri", "da sample"),
    ("fi", "vesi ja kissa ja vapaa", "fi sample"),
    ("hu", "viz es macska es szabad", "hu sample"),
    ("ro", "apa si pisica si liber", "ro sample"),
    ("tr", "su ve kedi ve serbest", "tr sample"),
    ("ar", "ماء وقط وحر", "ar sample"),
    ("he", "מים וחתול וחופשי", "he sample"),
    ("hi", "पानी और बिल्ली और मुक्त", "hi sample"),
    ("zh", "水 猫 自由", "zh sample"),
    ("ja", "水 猫 自由", "ja sample"),
    ("ko", "물 고양이 자유", "ko sample"),
    ("vi", "nuoc meo tu do", "vi sample"),
    ("id", "air kucing bebas", "id sample"),
    ("sw", "maji na paka na huru", "sw sample"),
    # classical
    ("la", "aqua et felis et liber", "la classical"),
    ("la", "urbs et lex et aqua", "la classical"),
    ("grc", "ὕδωρ", "grc sample"),
    ("ang", "wæter", "ang sample"),
]


def run_pflt(src: str, text: str) -> dict:
    cmd = [str(BIN), "--pack", str(PACK), "--nolog", "translate", src, "en", text]
    r = subprocess.run(
        cmd,
        cwd=str(ROOT),
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=60,
    )
    out = (r.stdout or "") + (r.stderr or "")
    out = re.sub(r"\x1b\[[0-9;]*m", "", out)
    got = None
    exact = None
    resolved = miss = dual = closed = pack = None
    for line in out.splitlines():
        if line.startswith("OUT "):
            m = re.match(r"OUT \[[^\]]+\] (.*)$", line)
            if m:
                got = m.group(1).strip()
        if "exact_rate=" in line:
            m = re.search(
                r"exact_rate=([0-9.]+)\s+resolved=(\d+)/(\d+)\s+closed=(\d+)\s+pack=(\d+)\s+miss=(\d+)\s+duality=(\d+)",
                line,
            )
            if m:
                exact = float(m.group(1))
                resolved = int(m.group(2))
                tokens = int(m.group(3))
                closed = int(m.group(4))
                pack = int(m.group(5))
                miss = int(m.group(6))
                dual = int(m.group(7))
                return {
                    "ok": r.returncode == 0 and got is not None,
                    "out": got,
                    "exact_rate": exact,
                    "resolved": resolved,
                    "tokens": tokens,
                    "closed": closed,
                    "pack": pack,
                    "miss": miss,
                    "duality": dual,
                    "returncode": r.returncode,
                }
    return {
        "ok": False,
        "out": got,
        "exact_rate": exact,
        "raw_tail": out[-400:],
        "returncode": r.returncode,
    }


def main() -> int:
    if not BIN.is_file():
        print("FAIL: build pflt first (zig build pflt)", flush=True)
        return 2
    if not PACK.is_file():
        print("FAIL: densify pack missing — run export_translate_pack.py", flush=True)
        return 2

    meta = {}
    mp = ROOT / "data" / "densify_pack.meta.json"
    if mp.is_file():
        meta = json.loads(mp.read_text(encoding="utf-8"))

    rows = []
    by_lang = {}
    for src, text, note in CASES:
        r = run_pflt(src, text)
        row = {"src": src, "input": text, "note": note, **r}
        rows.append(row)
        by_lang.setdefault(src, []).append(row)
        mark = "OK" if r.get("ok") and (r.get("exact_rate") or 0) >= 0.5 else "WEAK"
        print(f"[{mark}] {src}: {text!r} → {r.get('out')!r} exact={r.get('exact_rate')}", flush=True)

    rates = [r["exact_rate"] for r in rows if r.get("exact_rate") is not None]
    usable = sum(1 for r in rows if r.get("ok") and (r.get("exact_rate") or 0) >= 0.5)
    strong = sum(1 for r in rows if r.get("ok") and (r.get("exact_rate") or 0) >= 0.99)

    report = {
        "built_utc": datetime.now(timezone.utc).isoformat(),
        "binary": str(BIN),
        "pack_langs": meta.get("by_lang"),
        "pack_n_langs": meta.get("n_langs"),
        "pack_n_rows": meta.get("n_rows"),
        "n_cases": len(rows),
        "usable_ge_0_5": usable,
        "strong_ge_0_99": strong,
        "mean_exact_rate": sum(rates) / len(rates) if rates else 0,
        "by_lang_summary": {
            lang: {
                "n": len(v),
                "mean_exact": sum(x.get("exact_rate") or 0 for x in v) / len(v),
                "usable": sum(1 for x in v if (x.get("exact_rate") or 0) >= 0.5),
            }
            for lang, v in by_lang.items()
        },
        "cases": rows,
        "usability": {
            "de_en": "primary ship path — high densify coverage",
            "other_langs": "pack densify to EN sense heads; coverage varies by lang depth",
            "note": "Token densify identity, not full-sentence NMT fluency",
        },
    }
    REP.mkdir(parents=True, exist_ok=True)
    (REP / "SHIP_BASELINE_MULTILANG.json").write_text(
        json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    md = [
        "# Shippable multi-lang densify baseline",
        "",
        f"- built: `{report['built_utc']}`",
        f"- pack langs: **{report['pack_n_langs']}** · rows: **{report['pack_n_rows']}**",
        f"- cases: **{report['n_cases']}** · usable (≥0.5 exact): **{usable}** · strong (≥0.99): **{strong}**",
        f"- mean exact_rate: **{report['mean_exact_rate']:.3f}**",
        "",
        "## By language",
        "",
        "| lang | n | mean exact | usable |",
        "|------|--:|-----------:|-------:|",
    ]
    for lang, s in sorted(report["by_lang_summary"].items()):
        md.append(f"| `{lang}` | {s['n']} | {s['mean_exact']:.2f} | {s['usable']}/{s['n']} |")
    md += ["", "## Cases", ""]
    for r in rows:
        md.append(
            f"- **{r['src']}** `{r['input']}` → `{r.get('out')}` "
            f"(exact={r.get('exact_rate')}, miss={r.get('miss')}, pack={r.get('pack')}, closed={r.get('closed')})"
        )
    md += [
        "",
        "## Usability",
        "",
        "- **DE→EN** is the primary polished ship path.",
        "- Other langs densify form→EN sense when pack has binds; miss = honest pass-through.",
        "- This is densify identity, not DeepL/LLM sentence fluency.",
        "",
    ]
    (REP / "SHIP_BASELINE_MULTILANG.md").write_text("\n".join(md), encoding="utf-8")
    print(json.dumps({
        "usable": usable,
        "strong": strong,
        "mean_exact": report["mean_exact_rate"],
        "n_langs_tested": len(by_lang),
        "pack_langs": report["pack_n_langs"],
    }, indent=2), flush=True)
    return 0 if usable >= max(3, len(rows) // 4) else 1


if __name__ == "__main__":
    raise SystemExit(main())
