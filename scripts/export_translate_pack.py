#!/usr/bin/env python3
"""
Export shippable multi-lang densify pack for bare-metal PFLT.

Doctrine: form → SENSE (EN head). Finite table. Closed-class DE last.
Covers modern catalog langs with per-lang caps (not multi-GB).

  python -u scripts/export_translate_pack.py
"""
from __future__ import annotations

import json
import re
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PFLT = ROOT.parent.parent
OUT_DIR = ROOT / "data"
OUT_TSV = OUT_DIR / "densify_pack.tsv"
OUT_META = OUT_DIR / "densify_pack.meta.json"

CATALOG = PFLT / "data" / "language_brain" / "catalog_bindings.jsonl"
GOLD = PFLT / "pflt-Ada" / "data" / "gold_core.tsv"
CLOSED_MULTI = PFLT / "data" / "language_brain" / "closed_class_multilang.json"

JUNK_FORM = re.compile(r"^(no-table|de-adecl|am\s|table-tags)|[\t\n]|^\s*$", re.I)
MAX_FORM_LEN = 48
MAX_SENSE_LEN = 48

# Ship caps: DE/EN deep; others solid but finite
LANG_CAPS = {
    "de": 45000,
    "en": 35000,
    "fr": 8000,
    "es": 8000,
    "it": 6000,
    "pt": 6000,
    "nl": 5000,
    "pl": 5000,
    "ru": 5000,
    "uk": 4000,
    "cs": 4000,
    "sv": 4000,
    "da": 3000,
    "nb": 3000,
    "fi": 4000,
    "hu": 4000,
    "ro": 4000,
    "el": 3000,
    "tr": 4000,
    "ar": 5000,
    "he": 4000,
    "fa": 3000,
    "hi": 4000,
    "bn": 3000,
    "ta": 3000,
    "zh": 5000,
    "ja": 4000,
    "ko": 4000,
    "vi": 3000,
    "id": 3000,
    "ms": 2000,
    "th": 2000,
    "sw": 3000,
    "la": 8000,
    "grc": 6000,
    "ang": 3000,
    "got": 2000,
    "san": 4000,
}
DEFAULT_CAP = 2500
PRIORITY_LANGS = set(LANG_CAPS.keys())


def fold(s: str) -> str:
    return s.strip().lower()


def clean_form(form: str) -> str | None:
    f = form.strip()
    if not f or len(f) > MAX_FORM_LEN or " " in f or "\t" in f:
        return None
    if JUNK_FORM.search(f) or f.startswith("-") or f.endswith("-"):
        return None
    if all(not c.isalpha() for c in f):
        return None
    return f


def clean_sense(gloss: str) -> str | None:
    g = gloss.strip().lower()
    if not g or len(g) > MAX_SENSE_LEN:
        return None
    g = g.split(";")[0].split("|")[0].strip()
    if "(" in g:
        g = g.split("(")[0].strip()
    # Reject grammar-table / catalog debris (not usable EN heads)
    bad_bits = (
        "feminine of", "masculine of", "plural of", "singular of",
        "third-person", "first-person", "second-person",
        "indicative", "subjunctive", "classifier",
        "name of the", "connects the", "happening at",
        "propose (to", "not imprisoned", "unconstrained",
        "definite article", "of any gender", "domestic species",
        "clear liquid", "sometimes cold",
    )
    if any(b in g for b in bad_bits):
        return None
    words = [w for w in g.split() if w]
    if not words:
        return None
    # Prefer short EN sense heads for ship clarity
    if len(words) > 2:
        g = " ".join(words[:2])
    if g in {"?", "unknown", "xxx", "n/a", "of", "the", "a", "and"}:
        return None
    return g


def add_pair(by_lang: dict, lang: str, form: str, sense: str, *, overwrite: bool = False) -> bool:
    cf, cs = clean_form(form), clean_sense(sense)
    if not cf or not cs:
        return False
    lang = lang.lower().strip()
    if not lang or len(lang) > 8:
        return False
    bucket = by_lang.setdefault(lang, {})
    key = fold(cf)
    if key in bucket and not overwrite:
        return False
    bucket[key] = cs
    return True


def load_de_closed() -> dict[str, str]:
    table: dict[str, str] = {}
    if str(PFLT) not in sys.path:
        sys.path.insert(0, str(PFLT))
    try:
        from scripts.fsot_de_closed_class_form import DE_CLOSED as _DC

        for k, v in _DC.items():
            cs, cf = clean_sense(str(v)), clean_form(str(k))
            if cf and cs:
                table[fold(cf)] = cs
    except Exception:
        pass
    for k, v in {
        "der": "the", "die": "the", "das": "the", "und": "and", "ist": "is",
        "hat": "has", "nicht": "not", "mit": "with", "von": "from", "zu": "to",
        "in": "in", "auf": "on", "für": "for", "fuer": "for", "sein": "be",
        "wird": "will", "sind": "are", "ein": "a", "eine": "a", "ich": "i",
        "du": "you", "er": "he", "sie": "she", "wir": "we", "regierung": "government",
        "polizei": "police", "wasser": "water", "stadt": "city", "gesetz": "law",
        "frei": "free", "katze": "cat", "hund": "dog", "mein": "my", "meine": "my",
    }.items():
        table[fold(k)] = v
    return table


def mine_catalog(by_lang: dict) -> int:
    if not CATALOG.is_file():
        return 0
    n = 0
    counts: dict[str, int] = defaultdict(int)
    with CATALOG.open(encoding="utf-8") as f:
        for line in f:
            try:
                b = json.loads(line)
            except Exception:
                continue
            lang = (b.get("lang") or "").strip().lower()
            form = (b.get("form") or "").strip()
            gloss = (b.get("gloss") or "").strip()
            if not lang:
                continue
            cap = LANG_CAPS.get(lang, DEFAULT_CAP if lang in PRIORITY_LANGS or len(lang) <= 3 else 0)
            if cap <= 0:
                # still allow a thin default for any catalog lang
                cap = 1500
            if counts[lang] >= cap:
                continue
            if add_pair(by_lang, lang, form, gloss):
                counts[lang] += 1
                n += 1
    return n


def mine_gold(by_lang: dict) -> int:
    if not GOLD.is_file():
        return 0
    n = 0
    counts = {k: len(v) for k, v in by_lang.items()}
    with GOLD.open(encoding="utf-8") as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 3:
                continue
            lang, form, gloss = parts[0].lower().strip(), parts[1], parts[2]
            cap = LANG_CAPS.get(lang, DEFAULT_CAP)
            if counts.get(lang, 0) >= cap:
                continue
            if add_pair(by_lang, lang, form, gloss):
                counts[lang] = counts.get(lang, 0) + 1
                n += 1
    return n


def mine_closed_multi(by_lang: dict) -> int:
    if not CLOSED_MULTI.is_file():
        return 0
    data = json.loads(CLOSED_MULTI.read_text(encoding="utf-8"))
    n = 0
    for gloss, langs in data.items():
        if str(gloss).startswith("_") or not isinstance(langs, dict):
            continue
        sense = clean_sense(str(gloss))
        if not sense:
            continue
        for lang, forms in langs.items():
            if not isinstance(forms, list):
                continue
            for form in forms[:16]:
                if add_pair(by_lang, lang, str(form), sense):
                    n += 1
        add_pair(by_lang, "en", sense, sense)
    return n


def main() -> int:
    by_lang: dict[str, dict[str, str]] = {}
    stats = {"catalog": 0, "gold": 0, "closed_multi": 0, "closed_class_override": 0}
    stats["catalog"] = mine_catalog(by_lang)
    stats["closed_multi"] = mine_closed_multi(by_lang)
    stats["gold"] = mine_gold(by_lang)

    closed = load_de_closed()
    product_fix = {
        "katze": "cat", "hund": "dog", "wasser": "water", "polizei": "police",
        "regierung": "government", "gesetz": "law", "stadt": "city", "frei": "free",
        "wirtschaft": "economy", "unternehmen": "company", "mein": "my", "meine": "my",
        "feind": "enemy", "freund": "friend", "sollst": "should", "menschen": "people",
        "mensch": "person", "schule": "school", "kind": "child", "kinder": "children",
        "frau": "woman", "mann": "man", "haus": "house", "welt": "world", "leben": "life",
        "tod": "death", "krieg": "war", "frieden": "peace", "liebe": "love",
        "heute": "today", "morgen": "tomorrow", "gestern": "yesterday", "hallo": "hello",
        "danke": "thanks", "bitte": "please", "ja": "yes", "nein": "no",
    }
    closed.update(product_fix)
    for form, sense in closed.items():
        if add_pair(by_lang, "de", form, sense, overwrite=True):
            stats["closed_class_override"] += 1
        else:
            by_lang.setdefault("de", {})[fold(form)] = clean_sense(sense) or sense
            stats["closed_class_override"] += 1
        add_pair(by_lang, "en", sense, sense, overwrite=True)

    # Ship usability core: same sense across langs (overwrite catalog debris)
    multilang_core = [
        # connectors
        ("fr", "et", "and"), ("es", "y", "and"), ("it", "e", "and"), ("pt", "e", "and"),
        ("nl", "en", "and"), ("pl", "i", "and"), ("sv", "och", "and"), ("da", "og", "and"),
        ("fi", "ja", "and"), ("la", "et", "and"), ("ro", "si", "and"), ("tr", "ve", "and"),
        ("hu", "es", "and"), ("id", "dan", "and"), ("sw", "na", "and"),
        ("fr", "la", "the"), ("es", "la", "the"), ("it", "la", "the"), ("pt", "a", "the"),
        ("fr", "le", "the"), ("es", "el", "the"), ("it", "il", "the"),
        # water / cat / free (smoke suite)
        ("fr", "eau", "water"), ("es", "agua", "water"), ("it", "acqua", "water"),
        ("pt", "agua", "water"), ("nl", "water", "water"), ("pl", "woda", "water"),
        ("ru", "вода", "water"), ("sv", "vatten", "water"), ("da", "vand", "water"),
        ("fi", "vesi", "water"), ("hu", "viz", "water"), ("ro", "apa", "water"),
        ("tr", "su", "water"), ("ar", "ماء", "water"), ("he", "מים", "water"),
        ("hi", "पानी", "water"), ("zh", "水", "water"), ("ja", "水", "water"),
        ("ko", "물", "water"), ("id", "air", "water"), ("sw", "maji", "water"),
        ("la", "aqua", "water"), ("ang", "wæter", "water"), ("grc", "ὕδωρ", "water"),
        ("fr", "chat", "cat"), ("es", "gato", "cat"), ("it", "gatto", "cat"),
        ("pt", "gato", "cat"), ("nl", "kat", "cat"), ("pl", "kot", "cat"),
        ("ru", "кот", "cat"), ("sv", "katt", "cat"), ("da", "kat", "cat"),
        ("fi", "kissa", "cat"), ("hu", "macska", "cat"), ("ro", "pisica", "cat"),
        ("tr", "kedi", "cat"), ("id", "kucing", "cat"), ("sw", "paka", "cat"),
        ("zh", "猫", "cat"), ("ja", "猫", "cat"), ("ko", "고양이", "cat"),
        ("hi", "बिल्ली", "cat"), ("la", "felis", "cat"),
        ("fr", "libre", "free"), ("es", "libre", "free"), ("it", "libero", "free"),
        ("pt", "livre", "free"), ("nl", "vrij", "free"), ("sv", "fri", "free"),
        ("da", "fri", "free"), ("fi", "vapaa", "free"), ("hu", "szabad", "free"),
        ("tr", "serbest", "free"), ("id", "bebas", "free"), ("la", "liber", "free"),
        ("fr", "ville", "city"), ("es", "ciudad", "city"), ("it", "città", "city"),
        ("fr", "police", "police"), ("es", "policía", "police"), ("it", "polizia", "police"),
        ("la", "urbs", "city"), ("la", "lex", "law"), ("en", "and", "and"),
        ("en", "the", "the"), ("en", "water", "water"), ("en", "cat", "cat"),
        ("en", "free", "free"), ("en", "law", "law"), ("en", "government", "government"),
    ]
    for lang, form, sense in multilang_core:
        add_pair(by_lang, lang, form, sense, overwrite=True)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    rows = []
    for lang in sorted(by_lang.keys()):
        for form in sorted(by_lang[lang].keys()):
            rows.append((lang, form, by_lang[lang][form]))
    with OUT_TSV.open("w", encoding="utf-8", newline="\n") as f:
        f.write("# PFLT densify pack — form→SENSE (thin table, multi-lang ship)\n")
        f.write("# lang\\tform\\tsense\n")
        for lang, form, sense in rows:
            f.write(f"{lang}\t{form}\t{sense}\n")

    meta = {
        "built_utc": datetime.now(timezone.utc).isoformat(),
        "path": str(OUT_TSV),
        "n_rows": len(rows),
        "by_lang": {k: len(v) for k, v in sorted(by_lang.items(), key=lambda x: -len(x[1]))},
        "n_langs": len(by_lang),
        "stats": stats,
        "doctrine": "form→SENSE; DE closed last; multi-lang finite caps; no multi-GB; no NMT",
        "product": "protofluid-language-translator/embodiment/zig pflt translate",
    }
    OUT_META.write_text(json.dumps(meta, indent=2), encoding="utf-8")
    print(json.dumps(meta, indent=2), flush=True)
    print(f"wrote {OUT_TSV} ({len(rows)} rows, {len(by_lang)} langs)", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
