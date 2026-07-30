# Shippable multi-lang densify baseline

- built: `2026-07-30T02:18:52.210661+00:00`
- pack langs: **114** · rows: **386006**
- cases: **35** · usable (≥0.5 exact): **27** · strong (≥0.99): **8**
- mean exact_rate: **0.653**

## By language

| lang | n | mean exact | usable |
|------|--:|-----------:|-------:|
| `ang` | 1 | 1.00 | 1/1 |
| `ar` | 1 | 0.33 | 0/1 |
| `da` | 1 | 0.60 | 1/1 |
| `de` | 5 | 1.00 | 5/5 |
| `en` | 2 | 0.68 | 2/2 |
| `es` | 2 | 0.50 | 1/2 |
| `fi` | 1 | 0.60 | 1/1 |
| `fr` | 2 | 0.50 | 1/2 |
| `grc` | 1 | 1.00 | 1/1 |
| `he` | 1 | 0.33 | 0/1 |
| `hi` | 1 | 0.40 | 0/1 |
| `hu` | 1 | 0.60 | 1/1 |
| `id` | 1 | 1.00 | 1/1 |
| `it` | 1 | 0.60 | 1/1 |
| `ja` | 1 | 0.67 | 1/1 |
| `ko` | 1 | 0.67 | 1/1 |
| `la` | 2 | 0.60 | 2/2 |
| `nl` | 1 | 0.60 | 1/1 |
| `pl` | 1 | 0.60 | 1/1 |
| `pt` | 1 | 0.60 | 1/1 |
| `ro` | 1 | 0.40 | 0/1 |
| `ru` | 1 | 0.40 | 0/1 |
| `sv` | 1 | 0.60 | 1/1 |
| `sw` | 1 | 0.80 | 1/1 |
| `tr` | 1 | 0.60 | 1/1 |
| `vi` | 1 | 0.25 | 0/1 |
| `zh` | 1 | 0.67 | 1/1 |

## Cases

- **de** `die regierung hat wasser und gesetz` → `the government has water and law` (exact=1.0, miss=0, pack=0, closed=6)
- **de** `Die Katze ist frei` → `the cat is free` (exact=1.0, miss=0, pack=0, closed=4)
- **de** `Hallo Welt ich bin frei` → `hello world i am free` (exact=1.0, miss=0, pack=0, closed=5)
- **de** `die polizei und die stadt` → `the police and the city` (exact=1.0, miss=0, pack=0, closed=5)
- **de** `mein hund und meine katze` → `my dog and my cat` (exact=1.0, miss=0, pack=0, closed=5)
- **en** `water and law and free` → `water and law and free` (exact=0.6, miss=2, pack=3, closed=0)
- **en** `the government has water` → `the government has water` (exact=0.75, miss=1, pack=3, closed=0)
- **fr** `eau et chat et libre` → `water et cat et free` (exact=0.6, miss=2, pack=3, closed=0)
- **fr** `la ville et la police` → `la city et la police` (exact=0.4, miss=3, pack=2, closed=0)
- **es** `agua y gato y libre` → `water y cat y free` (exact=0.6, miss=2, pack=3, closed=0)
- **es** `la ciudad y la policía` → `la city y la police` (exact=0.4, miss=3, pack=2, closed=0)
- **it** `acqua e gatto e libero` → `water e cat e free` (exact=0.6, miss=2, pack=3, closed=0)
- **pt** `agua e gato e livre` → `water e cat e free` (exact=0.6, miss=2, pack=3, closed=0)
- **nl** `water en kat en vrij` → `water en cat en free` (exact=0.6, miss=2, pack=3, closed=0)
- **pl** `woda i kot i wolny` → `water i cat i slow` (exact=0.6, miss=2, pack=3, closed=0)
- **ru** `вода и кот и свободный` → `water и cat и свободный` (exact=0.4, miss=3, pack=2, closed=0)
- **sv** `vatten och katt och fri` → `water och cat och free` (exact=0.6, miss=2, pack=3, closed=0)
- **da** `vand og kat og fri` → `water og cat og free` (exact=0.6, miss=2, pack=3, closed=0)
- **fi** `vesi ja kissa ja vapaa` → `water ja cat ja free` (exact=0.6, miss=2, pack=3, closed=0)
- **hu** `viz es macska es szabad` → `water es cat es free` (exact=0.6, miss=2, pack=3, closed=0)
- **ro** `apa si pisica si liber` → `water si cat si liber` (exact=0.4, miss=3, pack=2, closed=0)
- **tr** `su ve kedi ve serbest` → `water ve cat ve free` (exact=0.6, miss=2, pack=3, closed=0)
- **ar** `ماء وقط وحر` → `water وقط وحر` (exact=0.33, miss=2, pack=1, closed=0)
- **he** `מים וחתול וחופשי` → `water וחתול וחופשי` (exact=0.33, miss=2, pack=1, closed=0)
- **hi** `पानी और बिल्ली और मुक्त` → `water और cat और मुक्त` (exact=0.4, miss=3, pack=2, closed=0)
- **zh** `水 猫 自由` → `water cat 自由` (exact=0.67, miss=1, pack=2, closed=0)
- **ja** `水 猫 自由` → `water cat 自由` (exact=0.67, miss=1, pack=2, closed=0)
- **ko** `물 고양이 자유` → `water cat 자유` (exact=0.67, miss=1, pack=2, closed=0)
- **vi** `nuoc meo tu do` → `nuoc meo tu by` (exact=0.25, miss=3, pack=1, closed=0)
- **id** `air kucing bebas` → `water cat free` (exact=1.0, miss=0, pack=3, closed=0)
- **sw** `maji na paka na huru` → `water with cat with huru` (exact=0.8, miss=1, pack=4, closed=0)
- **la** `aqua et felis et liber` → `water et cat et free` (exact=0.6, miss=2, pack=3, closed=0)
- **la** `urbs et lex et aqua` → `city et law et water` (exact=0.6, miss=2, pack=3, closed=0)
- **grc** `ὕδωρ` → `water` (exact=1.0, miss=0, pack=1, closed=0)
- **ang** `wæter` → `water` (exact=1.0, miss=0, pack=1, closed=0)

## Usability

- **DE→EN** is the primary polished ship path.
- Other langs densify form→EN sense when pack has binds; miss = honest pass-through.
- This is densify identity, not DeepL/LLM sentence fluency.
