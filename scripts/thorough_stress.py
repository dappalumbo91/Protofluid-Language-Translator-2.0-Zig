#!/usr/bin/env python3
"""
Thorough PFLT 2.0 stress suite — accuracy / densify / competitive probe apparatus.

Runs:
  1) pflt selftest
  2) embedded gold_pairs compare
  3) expanded synthetic gold from densify pack (closed + content)
  4) bulk free-form DE phrases (coverage / miss / duality)
  5) optional WMT-style refs if hyp caches present
  6) decision-log aggregate

Writes:
  reports/THOROUGH_STRESS.json
  reports/THOROUGH_STRESS.md
  data/stress_gold_expanded.tsv
  logs/stress_decisions.jsonl
"""
from __future__ import annotations

import json
import random
import re
import subprocess
import sys
import time
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PFLT = ROOT.parent.parent  # protofluid-language-translator
BIN = ROOT / "zig-out" / "bin" / "pflt.exe"
PACK = ROOT / "data" / "densify_pack.tsv"
GOLD = ROOT / "data" / "gold_pairs.tsv"
STRESS_GOLD = ROOT / "data" / "stress_gold_expanded.tsv"
REP_DIR = ROOT / "reports"
LOG = ROOT / "logs" / "stress_decisions.jsonl"
CLOSED_MOD = PFLT / "scripts" / "fsot_de_closed_class_form.py"


def run_pflt(args: list[str], timeout: int = 120) -> subprocess.CompletedProcess:
    cmd = [str(BIN), "--pack", str(PACK), "--log", str(LOG)] + args
    return subprocess.run(
        cmd,
        cwd=str(ROOT),
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout,
    )


def strip_ansi(s: str) -> str:
    return re.sub(r"\x1b\[[0-9;]*m", "", s)


def parse_compare_summary(out: str) -> dict:
    text = strip_ansi(out)
    m = re.search(
        r"SUMMARY n=(\d+)\s+mean_overlap=([0-9.]+)\s+mean_exact=([0-9.]+)\s+duality_tokens=(\d+)\s+miss_tokens=(\d+)",
        text,
    )
    if not m:
        return {"raw_tail": text[-800:]}
    return {
        "n": int(m.group(1)),
        "mean_overlap": float(m.group(2)),
        "mean_exact": float(m.group(3)),
        "duality_tokens": int(m.group(4)),
        "miss_tokens": int(m.group(5)),
    }


def parse_cli_translate(out: str) -> dict:
    d: dict = {"out_text": None, "exact_rate": None, "resolved": None, "tokens": None, "duality": None, "miss": None, "closed": None, "pack": None}
    for line in strip_ansi(out).splitlines():
        if line.startswith("OUT "):
            # OUT [en] text
            m = re.match(r"OUT \[[^\]]+\] (.*)$", line)
            if m:
                d["out_text"] = m.group(1).strip()
        if "exact_rate=" in line:
            m = re.search(
                r"exact_rate=([0-9.]+)\s+resolved=(\d+)/(\d+)\s+closed=(\d+)\s+pack=(\d+)\s+miss=(\d+)\s+duality=(\d+)",
                line,
            )
            if m:
                d["exact_rate"] = float(m.group(1))
                d["resolved"] = int(m.group(2))
                d["tokens"] = int(m.group(3))
                d["closed"] = int(m.group(4))
                d["pack"] = int(m.group(5))
                d["miss"] = int(m.group(6))
                d["duality"] = int(m.group(7))
    return d


def load_pack_de_en() -> dict[str, str]:
    m: dict[str, str] = {}
    if not PACK.is_file():
        return m
    for line in PACK.read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 3:
            continue
        lang, form, sense = parts[0].strip(), parts[1].strip(), parts[2].strip()
        if lang == "de" and form and sense:
            m[form.lower()] = sense.lower()
    return m


def load_closed() -> dict[str, str]:
    table: dict[str, str] = {}
    if CLOSED_MOD.is_file():
        ns: dict = {}
        try:
            if str(PFLT) not in sys.path:
                sys.path.insert(0, str(PFLT))
            from scripts.fsot_de_closed_class_form import DE_CLOSED  # type: ignore

            for k, v in DE_CLOSED.items():
                table[str(k).lower()] = str(v).lower()
        except Exception:
            pass
    # product heads also in densify_fixed
    extra = {
        "regierung": "government",
        "polizei": "police",
        "stadt": "city",
        "wasser": "water",
        "krieg": "war",
        "gesetz": "law",
        "wirtschaft": "economy",
        "unternehmen": "company",
        "jahr": "year",
        "jahren": "years",
        "frei": "free",
        "katze": "cat",
        "hund": "dog",
        "brot": "bread",
        "milch": "milk",
        "schule": "school",
        "kind": "child",
        "kinder": "children",
        "frau": "woman",
        "mann": "man",
        "haus": "house",
        "welt": "world",
        "zeit": "time",
        "tag": "day",
        "geld": "money",
        "leben": "life",
        "tod": "death",
        "frieden": "peace",
        "liebe": "love",
        "freund": "friend",
        "arbeit": "work",
        "gut": "good",
        "neu": "new",
        "alt": "old",
        "groß": "large",
        "klein": "small",
        "heute": "today",
        "morgen": "tomorrow",
        "gestern": "yesterday",
        "jetzt": "now",
        "hallo": "hello",
        "danke": "thanks",
        "bitte": "please",
        "ja": "yes",
        "nein": "no",
        "buch": "book",
        "wort": "word",
        "sprache": "language",
        "könig": "king",
        "blut": "blood",
        "himmel": "sky",
        "menschen": "people",
        "mensch": "person",
        "land": "country",
        "kostenlos": "free",
    }
    table.update(extra)
    return table


def build_expanded_gold(pack: dict[str, str], closed: dict[str, str], n_single: int = 400, n_phrase: int = 200) -> list[tuple[str, str]]:
    """Return list of (de_source, en_reference) for densify-identity gold."""
    pairs: list[tuple[str, str]] = []
    # 1) closed-class singles
    for form, sense in sorted(closed.items()):
        pairs.append((form, sense))
    # 2) content singles from pack that look clean (ascii-ish letters)
    content = []
    for form, sense in pack.items():
        if form in closed:
            continue
        if not re.fullmatch(r"[a-zäöüß\-']{2,32}", form, re.I):
            continue
        if not re.fullmatch(r"[a-z][a-z\- ]{0,40}", sense):
            continue
        if " " in form:
            continue
        content.append((form, sense))
    random.Random(42).shuffle(content)
    for form, sense in content[:n_single]:
        pairs.append((form, sense))

    # 3) phrase templates
    templates = [
        ("die {n}", "the {n_en}"),
        ("der {n}", "the {n_en}"),
        ("das {n}", "the {n_en}"),
        ("{n} ist frei", "{n_en} is free"),
        ("die {n} hat wasser", "the {n_en} has water"),
        ("ich bin in der {n}", "i am in the {n_en}"),
        ("{n} und {n2}", "{n_en} and {n2_en}"),
        ("heute ist ein guter {n}", "today is a good {n_en}"),
        ("die polizei hat das {n}", "the police has the {n_en}"),
        ("hallo {n}", "hello {n_en}"),
    ]
    nouns = [
        ("regierung", "government"),
        ("stadt", "city"),
        ("schule", "school"),
        ("wirtschaft", "economy"),
        ("unternehmen", "company"),
        ("gesetz", "law"),
        ("polizei", "police"),
        ("krieg", "war"),
        ("frieden", "peace"),
        ("katze", "cat"),
        ("hund", "dog"),
        ("haus", "house"),
        ("welt", "world"),
        ("tag", "day"),
        ("kind", "child"),
        ("frau", "woman"),
        ("mann", "man"),
        ("buch", "book"),
        ("sprache", "language"),
        ("land", "country"),
    ]
    count = 0
    for n, n_en in nouns:
        for n2, n2_en in nouns:
            if count >= n_phrase:
                break
            for td, te in templates:
                if count >= n_phrase:
                    break
                if "{n2}" in td and n2 == n:
                    continue
                de = td.format(n=n, n2=n2)
                en = te.format(n_en=n_en, n2_en=n2_en)
                pairs.append((de, en))
                count += 1
        if count >= n_phrase:
            break

    # 4) hand hard set (competitive / everyday)
    hand = [
        ("die regierung hat wasser und gesetz", "the government has water and law"),
        ("Die Katze ist frei", "the cat is free"),
        ("Die Polizei hat das Gesetz", "the police has the law"),
        ("Hallo Welt ich bin frei", "hello world i am free"),
        ("das unternehmen und die wirtschaft", "the company and the economy"),
        ("die stadt hat kein wasser", "the city has no water"),
        ("ich bin in der schule", "i am in the school"),
        ("der krieg und der frieden", "the war and the peace"),
        ("heute ist ein guter tag", "today is a good day"),
        ("die frau und der mann", "the woman and the man"),
        ("die kinder sind in der schule", "the children are in the school"),
        ("das haus und die stadt", "the house and the city"),
        ("ich habe kein geld", "i have no money"),
        ("wir sind frei", "we are free"),
        ("er ist in der stadt", "he is in the city"),
        ("sie hat ein buch", "she has a book"),
        ("die sprache und das wort", "the language and the word"),
        ("der könig und das land", "the king and the country"),
        ("wasser und milch und brot", "water and milk and bread"),
        ("ja und nein", "yes and no"),
        ("bitte und danke", "please and thanks"),
        ("gestern und heute und morgen", "yesterday and today and tomorrow"),
        ("die liebe und der tod", "the love and the death"),
        ("mein freund ist gut", "my friend is good"),
        ("die arbeit und die zeit", "the work and the time"),
        ("ein neues jahr", "a new year"),
        ("die kleinen kinder", "the small children"),
        ("die große stadt", "the large city"),
        ("kein krieg", "no war"),
        ("mit der polizei", "with the police"),
        ("von der regierung", "from the government"),
        ("für die wirtschaft", "for the economy"),
        ("auf dem land", "on the country"),
        ("nach der schule", "after the school"),
        ("unter dem himmel", "under the sky"),
        ("zwischen krieg und frieden", "between war and peace"),
        ("die neuen gesetze", "the new law"),  # densify is token-wise not agreement
        ("wir haben wasser", "we have water"),
        ("sie sind in der welt", "they are in the world"),
        ("das leben und der tod", "the life and the death"),
    ]
    pairs.extend(hand)
    # dedupe
    seen = set()
    out = []
    for de, en in pairs:
        key = (de.lower().strip(), en.lower().strip())
        if key in seen:
            continue
        seen.add(key)
        out.append((de.strip(), en.strip()))
    return out


def write_gold_tsv(path: Path, pairs: list[tuple[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as f:
        f.write("# src_lang\ttgt_lang\tsource\treference\n")
        for de, en in pairs:
            f.write(f"de\ten\t{de}\t{en}\n")


def token_overlap(hyp: str, ref: str) -> float:
    ht = [t.lower() for t in hyp.split() if t]
    rt = set(t.lower() for t in ref.split() if t)
    if not ht:
        return 0.0
    return sum(1 for t in ht if t in rt) / len(ht)


def main() -> int:
    t0 = time.time()
    REP_DIR.mkdir(parents=True, exist_ok=True)
    (ROOT / "logs").mkdir(parents=True, exist_ok=True)
    if LOG.is_file():
        LOG.unlink()

    report: dict = {
        "built_utc": datetime.now(timezone.utc).isoformat(),
        "binary": str(BIN),
        "pack": str(PACK),
        "pin": "D1D38A",
        "sections": {},
    }

    if not BIN.is_file():
        print("FAIL: pflt.exe missing — run zig build pflt", flush=True)
        return 2

    # --- 1 selftest ---
    print("== selftest ==", flush=True)
    r = run_pflt(["selftest"])
    st_out = (r.stdout or "") + (r.stderr or "")
    report["sections"]["selftest"] = {
        "ok": r.returncode == 0 and "PFLT selftest PASS" in st_out,
        "returncode": r.returncode,
        "tail": st_out[-500:],
    }
    print(st_out[-300:], flush=True)

    # --- 2 baseline gold ---
    print("== gold_pairs compare ==", flush=True)
    r = run_pflt(["compare", str(GOLD)])
    out = (r.stdout or "") + (r.stderr or "")
    report["sections"]["gold_baseline"] = parse_compare_summary(out)
    report["sections"]["gold_baseline"]["returncode"] = r.returncode
    print(json.dumps(report["sections"]["gold_baseline"], indent=2), flush=True)

    # --- 3 expanded densify-identity gold ---
    print("== build expanded gold ==", flush=True)
    pack = load_pack_de_en()
    closed = load_closed()
    pairs = build_expanded_gold(pack, closed, n_single=500, n_phrase=250)
    write_gold_tsv(STRESS_GOLD, pairs)
    report["sections"]["expanded_gold_build"] = {
        "n_pairs": len(pairs),
        "pack_de_rows": len(pack),
        "closed_rows": len(closed),
        "path": str(STRESS_GOLD),
    }
    print(f"expanded gold pairs: {len(pairs)}", flush=True)

    print("== expanded gold compare ==", flush=True)
    r = run_pflt(["compare", str(STRESS_GOLD)], timeout=600)
    out = (r.stdout or "") + (r.stderr or "")
    report["sections"]["gold_expanded"] = parse_compare_summary(out)
    report["sections"]["gold_expanded"]["returncode"] = r.returncode
    # count perfect vs weak lines from compare output
    ov_vals = [float(x) for x in re.findall(r"ov=([0-9.]+)", out)]
    if ov_vals:
        report["sections"]["gold_expanded"]["n_parsed_lines"] = len(ov_vals)
        report["sections"]["gold_expanded"]["pct_perfect_overlap"] = sum(1 for v in ov_vals if v >= 0.999) / len(ov_vals)
        report["sections"]["gold_expanded"]["pct_ge_0_8"] = sum(1 for v in ov_vals if v >= 0.8) / len(ov_vals)
        report["sections"]["gold_expanded"]["pct_lt_0_4"] = sum(1 for v in ov_vals if v < 0.4) / len(ov_vals)
    print(json.dumps(report["sections"]["gold_expanded"], indent=2), flush=True)

    # --- 4 bulk free phrases (not all gold identity) — coverage ---
    print("== bulk free-form coverage ==", flush=True)
    free_phrases = [
        "die regierung der stadt hat kein wasser und kein gesetz",
        "mein hund und meine katze sind frei",
        "wir wollen frieden und nicht krieg",
        "die polizei ist in der schule",
        "er hat geld und arbeit",
        "sie kann heute und morgen",
        "zwischen dem himmel und der welt",
        "die sprache der menschen",
        "ein altes haus in der stadt",
        "die kinder haben milch und brot",
        "ich bin und du bist",
        "das neue unternehmen der wirtschaft",
        "ohne wasser und ohne brot",
        "mit liebe und mit freund",
        "der könig hat das land",
        "ja ich will und nein ich will nicht",
        "bitte gib mir wasser",
        "danke für die hilfe",  # hilfe may miss
        "die zeit der arbeit ist jetzt",
        "gestern war krieg heute ist frieden",
        "die große und die kleine stadt",
        "wir sind menschen und nicht geld",
        "die frau hat ein kind",
        "der mann hat ein buch",
        "leben und tod und liebe",
        "die neuen jahre der welt",
        "ich muss und du sollst",
        "sie dürfen und wir können",
        "unter dem himmel der stadt",
        "nach der arbeit in der schule",
        "vor dem krieg und nach dem frieden",
        "die regierung und die polizei und das gesetz",
        "kostenlos und frei",
        "hallo und tschüss",
        "die wirtschaft des landes",  # landes may miss
        "im jahr der liebe",
        "am tag der arbeit",
        "kein mensch ist eine insel",  # insel may miss
        "wasser ist leben",
        "die katze ist auf dem haus",
        "der hund ist bei dem mann",
        "die schule der kinder",
        "freund und feind",  # feind may miss
        "gut und alt und neu und klein",
        "ich war und er war und wir waren",
        "sie wurde und er wird",
        "die sprache ist ein wort und ein buch",
        "geld und macht und krieg",  # macht may miss
        "die stadt hat polizei und regierung",
        "wir haben zeit und arbeit und geld",
    ]
    bulk = []
    tot_tok = tot_res = tot_miss = tot_dual = tot_closed = tot_pack = 0
    for ph in free_phrases:
        r = run_pflt(["translate", "de", "en", ph], timeout=60)
        out = (r.stdout or "") + (r.stderr or "")
        parsed = parse_cli_translate(out)
        parsed["input"] = ph
        bulk.append(parsed)
        if parsed.get("tokens"):
            tot_tok += parsed["tokens"]
            tot_res += parsed.get("resolved") or 0
            tot_miss += parsed.get("miss") or 0
            tot_dual += parsed.get("duality") or 0
            tot_closed += parsed.get("closed") or 0
            tot_pack += parsed.get("pack") or 0
    report["sections"]["bulk_free"] = {
        "n_phrases": len(free_phrases),
        "tokens": tot_tok,
        "resolved": tot_res,
        "miss": tot_miss,
        "duality": tot_dual,
        "closed": tot_closed,
        "pack": tot_pack,
        "exact_rate": (tot_res / tot_tok) if tot_tok else 0.0,
        "miss_rate": (tot_miss / tot_tok) if tot_tok else 0.0,
        "duality_rate": (tot_dual / tot_tok) if tot_tok else 0.0,
        "samples": bulk[:15],
        "weak": [b for b in bulk if (b.get("exact_rate") or 1) < 0.85 or (b.get("miss") or 0) > 0][:40],
    }
    print(
        f"bulk exact={report['sections']['bulk_free']['exact_rate']:.3f} "
        f"miss={report['sections']['bulk_free']['miss_rate']:.3f} "
        f"dual={report['sections']['bulk_free']['duality_rate']:.3f}",
        flush=True,
    )

    # --- 5 pack closed-class identity battery via single-token translate ---
    print("== closed-class identity battery ==", flush=True)
    closed_ok = 0
    closed_fail = []
    for form, sense in sorted(closed.items()):
        r = run_pflt(["translate", "de", "en", form], timeout=30)
        out = (r.stdout or "") + (r.stderr or "")
        parsed = parse_cli_translate(out)
        got = (parsed.get("out_text") or "").strip().lower()
        if got == sense.lower():
            closed_ok += 1
        else:
            closed_fail.append({"form": form, "expect": sense, "got": got})
    report["sections"]["closed_identity"] = {
        "n": len(closed),
        "ok": closed_ok,
        "rate": closed_ok / len(closed) if closed else 0.0,
        "fails": closed_fail[:50],
        "n_fails": len(closed_fail),
    }
    print(f"closed identity {closed_ok}/{len(closed)}", flush=True)

    # --- 6 decision log aggregate ---
    print("== decision log aggregate ==", flush=True)
    methods = Counter()
    dual_forms = Counter()
    miss_forms = Counter()
    n_events = 0
    if LOG.is_file():
        for line in LOG.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            try:
                ev = json.loads(line)
            except Exception:
                continue
            n_events += 1
            for d in ev.get("decisions") or []:
                methods[d.get("method", "?")] += 1
                if d.get("duality"):
                    dual_forms[d.get("form", "?")] += 1
                if d.get("method") == "miss":
                    miss_forms[d.get("form", "?")] += 1
    report["sections"]["decision_log"] = {
        "path": str(LOG),
        "n_events": n_events,
        "methods": dict(methods),
        "top_duality_forms": dual_forms.most_common(30),
        "top_miss_forms": miss_forms.most_common(40),
    }

    # --- pass/fail gates ---
    gates = {
        "selftest": report["sections"]["selftest"]["ok"],
        "gold_baseline_overlap_1": report["sections"].get("gold_baseline", {}).get("mean_overlap", 0) >= 0.99,
        "closed_identity_1": report["sections"]["closed_identity"]["rate"] >= 0.99,
        "expanded_overlap_ge_0_85": report["sections"].get("gold_expanded", {}).get("mean_overlap", 0) >= 0.85,
        "bulk_exact_ge_0_75": report["sections"]["bulk_free"]["exact_rate"] >= 0.75,
    }
    report["gates"] = gates
    report["all_gates_pass"] = all(gates.values())
    report["elapsed_s"] = round(time.time() - t0, 2)
    report["repo_audit"] = {
        "note": "token scan + file parity performed separately",
        "product_doctrine": "form→SENSE→form densify; closed wins; pin D1D38A",
    }

    # write reports
    (REP_DIR / "THOROUGH_STRESS.json").write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    md = [
        "# PFLT 2.0 Thorough Stress Report",
        "",
        f"- built: `{report['built_utc']}`",
        f"- elapsed_s: {report['elapsed_s']}",
        f"- all_gates_pass: **{report['all_gates_pass']}**",
        "",
        "## Gates",
        "",
    ]
    for k, v in gates.items():
        md.append(f"- `{'PASS' if v else 'FAIL'}` {k}")
    md += [
        "",
        "## Baseline gold",
        f"```json\n{json.dumps(report['sections'].get('gold_baseline'), indent=2)}\n```",
        "",
        "## Expanded gold",
        f"```json\n{json.dumps(report['sections'].get('gold_expanded'), indent=2)}\n```",
        "",
        "## Bulk free-form",
        f"```json\n{json.dumps({k: report['sections']['bulk_free'][k] for k in report['sections']['bulk_free'] if k not in ('samples','weak')}, indent=2)}\n```",
        "",
        "### Weak phrases (miss or low exact)",
        "",
    ]
    for w in report["sections"]["bulk_free"].get("weak") or []:
        md.append(f"- IN `{w.get('input')}` → OUT `{w.get('out_text')}` exact={w.get('exact_rate')} miss={w.get('miss')} dual={w.get('duality')}")
    md += [
        "",
        "## Closed-class identity",
        f"- rate: {report['sections']['closed_identity']['rate']:.4f} ({report['sections']['closed_identity']['ok']}/{report['sections']['closed_identity']['n']})",
        f"- fails: {report['sections']['closed_identity']['n_fails']}",
        "",
        "## Top miss forms (refinement targets)",
        "",
    ]
    for form, c in report["sections"]["decision_log"].get("top_miss_forms") or []:
        md.append(f"- `{form}` × {c}")
    md += ["", "## Top duality forms", ""]
    for form, c in report["sections"]["decision_log"].get("top_duality_forms") or []:
        md.append(f"- `{form}` × {c}")
    md += [
        "",
        "## Competitive note",
        "",
        "Token densify identity is not full sacreBLEU fluency. Use miss/duality lists to densify pack.",
        "Lab product lock ~37.22 sacre remains Python ranking path; Zig 2.0 is shippable densify app.",
        "",
    ]
    (REP_DIR / "THOROUGH_STRESS.md").write_text("\n".join(md), encoding="utf-8")
    print(json.dumps({"all_gates_pass": report["all_gates_pass"], "elapsed_s": report["elapsed_s"], "gates": gates}, indent=2), flush=True)
    print(f"wrote {REP_DIR / 'THOROUGH_STRESS.json'}", flush=True)
    return 0 if report["all_gates_pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
