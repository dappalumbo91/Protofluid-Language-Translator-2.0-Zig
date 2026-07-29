#!/usr/bin/env python3
"""
Export a finite densify pack for the bare-metal PFLT translator.

Doctrine: form → SENSE → form (thin table over machine tongue).
No multi-GB catalogs. Closed-class DE overrides catalog debris last.

Writes:
  I:\\pflt\\embodiment\\zig\\data\\densify_pack.tsv
  I:\\pflt\\embodiment\\zig\\data\\densify_pack.meta.json

Usage:
  python -u scripts/export_translate_pack.py
"""
from __future__ import annotations

import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]  # embodiment/zig
PFLT = ROOT.parents[1] if (ROOT.parents[1] / "sense_interlingua.py").is_file() else ROOT.parent.parent
# I:\pflt\embodiment\zig → parents[0]=embodiment, parents[1]=pflt
PFLT = ROOT.parent.parent
OUT_DIR = ROOT / "data"
OUT_TSV = OUT_DIR / "densify_pack.tsv"
OUT_META = OUT_DIR / "densify_pack.meta.json"

# Prefer product tree sources
DE_CLOSED_MOD = PFLT / "scripts" / "fsot_de_closed_class_form.py"
CATALOG = PFLT / "data" / "language_brain" / "catalog_bindings.jsonl"
GOLD = PFLT / "pflt-Ada" / "data" / "gold_core.tsv"
CLOSED_MULTI = PFLT / "data" / "language_brain" / "closed_class_multilang.json"

JUNK_FORM = re.compile(
    r"^(no-table|de-adecl|am\s|table-tags)|[\t\n]|^\s*$",
    re.I,
)
# Single-token forms only for densify table (token path)
MAX_FORM_LEN = 48
MAX_SENSE_LEN = 48
MAX_DE_CONTENT = 45000  # after closed-class; keeps pack shippable


def fold(s: str) -> str:
    return s.strip().lower()


def clean_form(form: str) -> str | None:
    f = form.strip()
    if not f or len(f) > MAX_FORM_LEN:
        return None
    if " " in f or "\t" in f:
        return None
    if JUNK_FORM.search(f):
        return None
    if f.startswith("-") or f.endswith("-"):
        return None
    # skip pure punctuation / digits-only noise for content
    if all(not c.isalpha() for c in f):
        return None
    return f


def clean_sense(gloss: str) -> str | None:
    g = gloss.strip().lower()
    if not g or len(g) > MAX_SENSE_LEN:
        return None
    # first sense head if multi-gloss debris
    g = g.split(";")[0].split("|")[0].strip()
    # keep multi-word EN heads (e.g. "in order to") but cap words
    words = g.split()
    if len(words) > 4:
        g = " ".join(words[:3])
    if not g or g in {"?", "unknown", "xxx", "n/a"}:
        return None
    return g


def load_de_closed() -> dict[str, str]:
    table: dict[str, str] = {}
    # Import product DE closed-class (path insert — do not exec as script)
    if str(PFLT) not in sys.path:
        sys.path.insert(0, str(PFLT))
    try:
        from scripts.fsot_de_closed_class_form import DE_CLOSED as _DC  # type: ignore

        for k, v in _DC.items():
            cs = clean_sense(str(v))
            cf = clean_form(str(k))
            if cf and cs:
                table[fold(cf)] = cs
    except Exception:
        pass
    # Always ensure critical closed-class overrides (catalog debris killers)
    minimal = {
        "der": "the",
        "die": "the",
        "das": "the",
        "den": "the",
        "dem": "the",
        "des": "the",
        "ein": "a",
        "eine": "a",
        "und": "and",
        "oder": "or",
        "aber": "but",
        "nicht": "not",
        "ist": "is",
        "sind": "are",
        "hat": "has",
        "haben": "have",
        "sein": "be",
        "wird": "will",
        "zu": "to",
        "von": "from",
        "mit": "with",
        "auf": "on",
        "in": "in",
        "für": "for",
        "fuer": "for",
        "als": "as",
        "auch": "also",
        "nach": "after",
        "bei": "at",
        "aus": "out",
        "im": "in",
        "am": "at",
        "ich": "i",
        "du": "you",
        "er": "he",
        "sie": "she",
        "es": "it",
        "wir": "we",
        "ihr": "you",
        "man": "one",
        "sich": "itself",
        "was": "what",
        "wie": "how",
        "wenn": "if",
        "dass": "that",
        "daß": "that",
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
        "kostenlos": "free",
    }
    for k, v in minimal.items():
        table[fold(k)] = v
    return table


def add_pair(
    by_lang: dict[str, dict[str, str]],
    lang: str,
    form: str,
    sense: str,
    *,
    overwrite: bool = False,
) -> bool:
    cf = clean_form(form)
    cs = clean_sense(sense)
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


def mine_catalog(by_lang: dict[str, dict[str, str]]) -> int:
    if not CATALOG.is_file():
        return 0
    n = 0
    with CATALOG.open(encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                b = json.loads(line)
            except Exception:
                continue
            lang = (b.get("lang") or "").strip().lower()
            form = (b.get("form") or "").strip()
            gloss = (b.get("gloss") or "").strip()
            if lang not in {"de", "en"}:
                continue
            if add_pair(by_lang, lang, form, gloss):
                n += 1
    return n


def mine_gold(by_lang: dict[str, dict[str, str]], max_de: int) -> int:
    if not GOLD.is_file():
        return 0
    n = 0
    de_n = len(by_lang.get("de", {}))
    with GOLD.open(encoding="utf-8") as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 3:
                continue
            lang, form, gloss = parts[0], parts[1], parts[2]
            lang = lang.lower().strip()
            if lang not in {"de", "en"}:
                continue
            if lang == "de" and de_n + n >= max_de:
                # still allow en
                if lang != "en":
                    continue
            if add_pair(by_lang, lang, form, gloss):
                n += 1
                if lang == "de":
                    de_n += 1
    return n


def mine_closed_multi(by_lang: dict[str, dict[str, str]]) -> int:
    """Gloss-keyed multilang closed class → form→sense for de/en."""
    if not CLOSED_MULTI.is_file():
        return 0
    data = json.loads(CLOSED_MULTI.read_text(encoding="utf-8"))
    n = 0
    for gloss, langs in data.items():
        if gloss.startswith("_") or not isinstance(langs, dict):
            continue
        sense = clean_sense(str(gloss))
        if not sense:
            continue
        for lang in ("de", "en"):
            forms = langs.get(lang) or []
            if not isinstance(forms, list):
                continue
            for form in forms[:12]:
                if add_pair(by_lang, lang, str(form), sense):
                    n += 1
        # EN head identity
        if add_pair(by_lang, "en", sense, sense):
            n += 1
    return n


def main() -> int:
    by_lang: dict[str, dict[str, str]] = {}
    stats = {
        "catalog": 0,
        "gold": 0,
        "closed_multi": 0,
        "closed_class_override": 0,
    }

    stats["catalog"] = mine_catalog(by_lang)
    stats["closed_multi"] = mine_closed_multi(by_lang)
    stats["gold"] = mine_gold(by_lang, MAX_DE_CONTENT)

    # Closed class + product sense fixes LAST (overrides catalog debris)
    closed = load_de_closed()
    # High-frequency content heads that densify debris routinely corrupts
    product_fix = {
        "katze": "cat",
        "hund": "dog",
        "brot": "bread",
        "milch": "milk",
        "wasser": "water",
        "blut": "blood",
        "himmel": "sky",
        "könig": "king",
        "koenig": "king",
        "sprache": "language",
        "wort": "word",
        "buch": "book",
        "kind": "child",
        "kinder": "children",
        "frau": "woman",
        "mann": "man",
        "haus": "house",
        "stadt": "city",
        "land": "country",
        "welt": "world",
        "zeit": "time",
        "tag": "day",
        "geld": "money",
        "leben": "life",
        "tod": "death",
        "krieg": "war",
        "frieden": "peace",
        "liebe": "love",
        "freund": "friend",
        "schule": "school",
        "arbeit": "work",
        "regierung": "government",
        "polizei": "police",
        "gesetz": "law",
        "wirtschaft": "economy",
        "unternehmen": "company",
        "jahr": "year",
        "jahren": "years",
        "frei": "free",
        "kostenlos": "free",
        "gut": "good",
        "neu": "new",
        "alt": "old",
        "groß": "large",
        "gross": "large",
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
    }
    closed.update(product_fix)
    for form, sense in closed.items():
        if add_pair(by_lang, "de", form, sense, overwrite=True):
            stats["closed_class_override"] += 1
        else:
            by_lang.setdefault("de", {})[fold(form)] = clean_sense(sense) or sense
            stats["closed_class_override"] += 1
        add_pair(by_lang, "en", sense, sense, overwrite=True)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    rows: list[tuple[str, str, str]] = []
    for lang in sorted(by_lang.keys()):
        for form in sorted(by_lang[lang].keys()):
            rows.append((lang, form, by_lang[lang][form]))

    with OUT_TSV.open("w", encoding="utf-8", newline="\n") as f:
        f.write("# PFLT densify pack — form→SENSE (thin table)\n")
        f.write("# lang\\tform\\tsense\n")
        for lang, form, sense in rows:
            f.write(f"{lang}\t{form}\t{sense}\n")

    meta = {
        "built_utc": datetime.now(timezone.utc).isoformat(),
        "path": str(OUT_TSV),
        "n_rows": len(rows),
        "by_lang": {k: len(v) for k, v in by_lang.items()},
        "sources": {
            "catalog_bindings": str(CATALOG),
            "gold_core": str(GOLD),
            "closed_class_multilang": str(CLOSED_MULTI),
            "de_closed": str(DE_CLOSED_MOD),
        },
        "stats": stats,
        "doctrine": "form→SENSE→form; DE closed-class last; no multi-GB; no NMT",
        "product": "I:\\pflt\\embodiment\\zig pflt translate",
    }
    OUT_META.write_text(json.dumps(meta, indent=2), encoding="utf-8")
    print(json.dumps(meta, indent=2), flush=True)
    print(f"wrote {OUT_TSV} ({len(rows)} rows)", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
