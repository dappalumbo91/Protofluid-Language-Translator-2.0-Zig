# PFLT Major Competitive Audit

- built: `2026-07-29T18:31:47.280561+00:00`
- pin: **D1D38A**

## 1. Where we sit competitively

Two games (do not mix them):

| Game | Meaning | Position |
|------|---------|----------|
| **A. Form→gloss inventory** | lemma/form → sense | **Strong on our catalog** |
| **B. Sentence fluency MT** | full-sentence BLEU/chrF | **Climbing — near mid open MT on news** |

### Sentence quality (WMT14 de→en)

| System | sacreBLEU |
|--------|----------:|
| **PFLT product lock** (`FSOT_B_Aco_S_phi_rank_sense`) | **37.22** |
| Best student gen (NLLB pool) | 36.81 |
| DeepL-class mid bar (staged) | 40.0 |
| **Gap to DeepL mid** | **2.78** |

- Beats NLLB student: **True**
- Clears DeepL mid-40: **False**

### Form→gloss quality (catalog densify)

- Languages: **114**
- Closed product exact: **99.2%**
- Langs ≥95% closed: **110/114**
- Open residual exact (outside densify cap): **19.3%** (expected under per-lang cap)
- Interlingua: **68,981** senses · **451,476** form binds

### Zig standalone product (ship path)

- Pack languages: **de, en**
- DE unique forms: **34,715** · EN: **28,978**
- Thorough stress: bulk densify exact **1.0**, expanded gold overlap **0.999**, gates_pass **True**
- **Honest:** multi-lang *depth* is in the lab catalog; ship pack is **DE/EN** until export expands.

## 2. How many languages — and how deep

| Layer | Languages | Depth signal |
|-------|----------:|--------------|
| Catalog densified (gold_core) | **114** | form→gloss product |
| Modern-ish | **82** | consumer-like |
| Historical-ish | **32** | classical moat |
| Closed-class multilang | **114** | high-freq senses |
| Zig densify pack (ship) | **2** | DE/EN product binary |
| Gold-core rows (all langs) | — | **11,992,983** binds |

### Depth tiers (unique gold forms)

| Tier | Definition | Count |
|------|------------|------:|
| deep | >=10000 unique gold forms | **91** |
| solid | 3000-9999 | **12** |
| medium | 500-2999 | **8** |
| thin | 50-499 | **3** |
| stub | 1-49 | **0** |

### Top 30 deepest languages

| Lang | Tier | Unique forms | Gold rows | Closed exact | Open residual | DeepL core | Google major |
|------|------|-------------:|----------:|-------------:|--------------:|:----------:|:------------:|
| `grc` | deep | 936,292 | 2,128,233 | 0.90 | 0.00 |  |  |
| `la` | deep | 794,059 | 917,503 | 1.00 | 0.07 |  | Y |
| `ang` | deep | 162,276 | 356,259 | 1.00 | 0.00 |  |  |
| `sw` | deep | 101,981 | 180,000 | 1.00 | 0.13 |  | Y |
| `ro` | deep | 97,194 | 180,000 | 1.00 | 0.07 | Y | Y |
| `fi` | deep | 95,355 | 180,004 | 1.00 | 0.07 | Y | Y |
| `cs` | deep | 94,357 | 180,000 | 1.00 | 0.00 | Y | Y |
| `ar` | deep | 94,151 | 203,448 | 1.00 | 0.13 | Y | Y |
| `he` | deep | 93,256 | 192,230 | 1.00 | 0.00 | Y | Y |
| `got` | deep | 83,751 | 158,310 | 1.00 | 0.00 |  |  |
| `pi` | deep | 81,814 | 81,866 | 1.00 | 0.00 |  |  |
| `uk` | deep | 79,558 | 180,002 | 1.00 | 0.00 | Y | Y |
| `hu` | deep | 77,600 | 180,002 | 0.97 | 0.00 | Y | Y |
| `zh` | deep | 77,367 | 180,000 | 1.00 | 0.00 | Y | Y |
| `el` | deep | 74,326 | 180,000 | 0.97 | 0.00 | Y | Y |
| `tr` | deep | 72,262 | 78,445 | 1.00 | 0.07 | Y | Y |
| `ta` | deep | 70,392 | 180,002 | 1.00 | 0.00 |  | Y |
| `san` | deep | 68,559 | 190,625 | 1.00 | 0.07 |  |  |
| `ka` | deep | 66,371 | 100,000 | 0.97 | 0.07 |  | Y |
| `cu` | deep | 63,968 | 104,372 | 0.97 | 0.00 |  |  |
| `oc` | deep | 62,038 | 90,522 | 1.00 | 0.07 |  |  |
| `qu` | deep | 61,653 | 100,000 | 1.00 | 0.00 |  |  |
| `hy` | deep | 61,553 | 115,401 | 1.00 | 0.00 |  | Y |
| `sv` | deep | 61,485 | 63,837 | 1.00 | 0.27 | Y | Y |
| `kk` | deep | 59,877 | 100,000 | 1.00 | 0.07 |  | Y |
| `ko` | deep | 59,388 | 61,999 | 1.00 | 0.07 | Y | Y |
| `nb` | deep | 59,368 | 100,000 | 1.00 | 0.07 | Y | Y |
| `pt` | deep | 58,981 | 64,081 | 0.93 | 0.07 | Y | Y |
| `eo` | deep | 57,618 | 100,000 | 1.00 | 0.07 |  | Y |
| `fro` | deep | 57,308 | 107,626 | 0.97 | 0.00 |  |  |

### Thinnest densified languages (depth targets)

| Lang | Tier | Unique forms | Closed exact |
|------|------|-------------:|-------------:|
| `phn` | thin | 154 | 1.00 |
| `pal` | thin | 241 | 0.83 |
| `hit` | thin | 320 | 1.00 |
| `peo` | medium | 1,072 | 1.00 |
| `pro` | medium | 1,299 | 1.00 |
| `roa-opt` | medium | 1,301 | 1.00 |
| `mga` | medium | 1,311 | 1.00 |
| `uga` | medium | 1,916 | 1.00 |
| `si` | medium | 2,347 | 1.00 |
| `osp` | medium | 2,440 | 1.00 |
| `haw` | medium | 2,733 | 1.00 |
| `so` | solid | 3,000 | 1.00 |
| `sum` | solid | 3,260 | 1.00 |
| `arc` | solid | 4,508 | 1.00 |
| `gmh` | solid | 4,862 | 1.00 |
| `jv` | solid | 5,576 | 1.00 |
| `ha` | solid | 5,850 | 1.00 |
| `akk` | solid | 6,138 | 1.00 |
| `xcl` | solid | 6,583 | 1.00 |
| `am` | solid | 8,326 | 1.00 |
| `ps` | solid | 8,580 | 1.00 |
| `yo` | solid | 9,236 | 1.00 |
| `orv` | solid | 9,597 | 1.00 |
| `af` | deep | 12,285 | 1.00 |
| `my` | deep | 14,480 | 0.97 |

### Families covered

- **Germanic** (10): `af`, `da`, `de`, `en`, `is`, `nb`, `nl`, `nn`, `sv`, `yi`
- **Slavic** (10): `be`, `bg`, `cs`, `mk`, `pl`, `ru`, `sh`, `sk`, `sl`, `uk`
- **IndoAryan** (8): `bn`, `gu`, `hi`, `mr`, `ne`, `pa`, `si`, `ur`
- **Romance** (8): `ca`, `es`, `fr`, `gl`, `it`, `oc`, `pt`, `ro`
- **Germanic_hist** (7): `ang`, `enm`, `gmh`, `goh`, `got`, `non`, `osx`
- **Austronesian** (6): `ceb`, `haw`, `id`, `jv`, `ms`, `tl`
- **Romance_hist** (6): `frm`, `fro`, `la`, `osp`, `pro`, `roa-opt`
- **Semitic_hist** (5): `akk`, `arc`, `phn`, `syc`, `uga`
- **Bantu** (3): `sw`, `xh`, `zu`
- **Celtic** (3): `cy`, `ga`, `gd`
- **Dravidian** (3): `ml`, `ta`, `te`
- **Semitic** (3): `am`, `ar`, `he`
- **Turkic** (3): `az`, `kk`, `tr`
- **Uralic** (3): `et`, `fi`, `hu`
- **Austroasiatic** (2): `km`, `vi`
- **Baltic** (2): `lt`, `lv`
- **Celtic_hist** (2): `mga`, `sga`
- **Egyptian_hist** (2): `cop`, `egy`
- **IndoAryan_hist** (2): `pi`, `san`
- **Iranian** (2): `fa`, `ps`
- **Iranian_hist** (2): `pal`, `peo`
- **Slavic_hist** (2): `cu`, `orv`
- **Albanian** (1): `sq`
- **Anatolian_hist** (1): `hit`
- **Armenian** (1): `hy`
- **Armenian_hist** (1): `xcl`
- **AtlanticCongo** (1): `yo`
- **Chadic** (1): `ha`
- **Constructed** (1): `eo`
- **Cushitic** (1): `so`
- **Hellenic** (1): `el`
- **Hellenic_hist** (1): `grc`
- **Isolate_Basque** (1): `eu`
- **Japonic** (1): `ja`
- **Kartvelian** (1): `ka`
- **Koreanic** (1): `ko`
- **Mongolic** (1): `mn`
- **Quechuan** (1): `qu`
- **Sinitic** (1): `zh`
- **SinoTibetan** (1): `my`
- **Sumerian_isolate** (1): `sum`
- **TaiKadai** (1): `th`

### Full densified language list (114)

`af`, `akk`, `am`, `ang`, `ar`, `arc`, `az`, `be`, `bg`, `bn`, `ca`, `ceb`, `cop`, `cs`, `cu`, `cy`, `da`, `de`, `egy`, `el`, `en`, `enm`, `eo`, `es`, `et`, `eu`, `fa`, `fi`, `fr`, `frm`, `fro`, `ga`, `gd`, `gl`, `gmh`, `goh`, `got`, `grc`, `gu`, `ha`, `haw`, `he`, `hi`, `hit`, `hu`, `hy`, `id`, `is`, `it`, `ja`, `jv`, `ka`, `kk`, `km`, `ko`, `la`, `lt`, `lv`, `mga`, `mk`, `ml`, `mn`, `mr`, `ms`, `my`, `nb`, `ne`, `nl`, `nn`, `non`, `oc`, `orv`, `osp`, `osx`, `pa`, `pal`, `peo`, `phn`, `pi`, `pl`, `pro`, `ps`, `pt`, `qu`, `ro`, `roa-opt`, `ru`, `san`, `sga`, `sh`, `si`, `sk`, `sl`, `so`, `sq`, `sum`, `sv`, `sw`, `syc`, `ta`, `te`, `th`, `tl`, `tr`, `uga`, `uk`, `ur`, `vi`, `xcl`, `xh`, `yi`, `yo`, `zh`, `zu`

## 3. Languages competitors cover that we do not

| Competitor | Approx languages | PFLT densified | Share of competitor count |
|------------|----------------:|---------------:|--------------------------:|
| Google Translate | ~249 | 114 | 46% |
| Meta NLLB-200 | ~200 | 114 | 57% |
| DeepL (core codes in this audit) | ~33 | 114 | PFLT **wider on count** (includes historical) |

### Missing vs DeepL core

_None of the DeepL-core codes in this audit set are missing from PFLT densify._

### Missing vs Google major consumer set (**29** codes)

`bs`, `co`, `fy`, `hmn`, `hr`, `ht`, `ig`, `kn`, `ku`, `ky`, `lb`, `lo`, `mg`, `mi`, `mt`, `ny`, `or`, `rw`, `sd`, `sm`, `sn`, `sr`, `st`, `su`, `tg`, `tk`, `tt`, `ug`, `uz`

### Missing high-value NLLB-style extras (**65** codes)

`ast`, `ay`, `ba`, `bm`, `bo`, `br`, `ckb`, `din`, `dyu`, `dzo`, `ee`, `ff`, `fj`, `fon`, `fur`, `gn`, `ht`, `ig`, `ilo`, `kab`, `kam`, `kn`, `ks`, `ky`, `lb`, `lg`, `ln`, `lo`, `luo`, `lus`, `mai`, `mi`, `min`, `nso`, `nya`, `ory`, `pag`, `pap`, `pcm`, `quy`, `rn`, `rw`, `sat`, `scn`, `sd`, `sg`, `shn`, `sm`, `sn`, `ss`, `st`, `su`, `tg`, `ti`, `tk`, `tn`, `tpi`, `ts`, `tt`, `tum`, `tw`, `umb`, `war`, `wo`, `yue`

### Priority expansion list (modern competitive value)

`hr`, `sr`, `ig`, `lo`, `uz`, `kn`, `or`, `as`, `sd`, `ku`, `ky`, `tg`, `tt`, `ug`, `mt`, `bs`, `lb`, `ht`, `mg`, `sm`, `st`, `sn`, `rw`, `ny`, `wo`, `ln`, `lg`, `ff`, `bm`, `ti`, `om`, `ss`, `tn`, `ts`, `ve`, `nr`, `nso`

### Our unique coverage (mostly historical; competitors weak/absent)

**35** densified codes outside the Google-major consumer set:

`akk`, `ang`, `arc`, `cop`, `cu`, `egy`, `enm`, `frm`, `fro`, `gmh`, `goh`, `got`, `grc`, `hit`, `mga`, `nn`, `non`, `oc`, `orv`, `osp`, `osx`, `pal`, `peo`, `phn`, `pi`, `pro`, `qu`, `roa-opt`, `san`, `sga`, `sh`, `sum`, `syc`, `uga`, `xcl`

## 4. Recommended expansion order

1. **Quality B (news):** close **+2.78** sacreBLEU to DeepL mid-40 on WMT14 de-en.
2. **Ship breadth:** multi-lang densify packs into Zig 2.0 (today DE/EN only).
3. **Modern gaps vs Google/DeepL:** `hr`, `sr`, `ig`, `lo`, `uz`, `kn`, `or`, `as`, `sd`, `ku`, `ky`, `tg`, `tt`, `ug`, `mt`
4. **Deepen thin tiers:** raise unique-form depth on medium/thin densified langs.
5. **Keep classical moat:** historical chain already present — differentiate, do not drop.

## 5. One-page verdict

| Track | Verdict |
|-------|---------|
| Multi-lang form→sense | **Competitive / strong** (114 langs, ~99% closed) |
| Classical / dead languages | **Category of one vs consumer MT** |
| News sentence de-en | **Beats NLLB gen; ~7% relative below DeepL mid-40** |
| Breadth vs Google ~249 | **~46% of language count** |
| Breadth vs NLLB ~200 | **~57%** |
| Zig app people can run | **DE→EN densify ready; multi-lang pack next** |
| Full DeepL/Google fluency parity | **Not claimed** |

---

Sources: `FSOT_PRODUCT_LOCK.json`, `FSOT_CATALOG_TRANSLATION_BENCHMARK.json`, `FSOT_LANG_GAP_AUDIT.json`, `gold_core.tsv`, `catalog_bindings.jsonl`, `embodiment/zig` densify pack + thorough stress; public competitor language counts (Google ~249, NLLB ~200, DeepL core codes).