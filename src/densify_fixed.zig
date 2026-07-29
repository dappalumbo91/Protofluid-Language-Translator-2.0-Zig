//! Finite form↔sense densify for PFLT (no multi-GB catalogs).
//! DE closed-class + high-frequency content → EN sense heads.
//! Unresolved forms stay unresolved (honest).
//! Host product loads larger pack via densify_pack.zig; this table is freestanding + fallback.

const pflt_ml = @import("pflt_machine_lang.zig");

/// Closed-class + light content (matches scripts/fsot_de_closed_class_form.py + news heads).
const DE_CLOSED = [_]struct { []const u8, []const u8 }{
    // articles / demonstratives
    .{ "der", "the" },     .{ "die", "the" },     .{ "das", "the" },
    .{ "den", "the" },     .{ "dem", "the" },     .{ "des", "the" },
    .{ "ein", "a" },       .{ "eine", "a" },      .{ "einer", "a" },
    .{ "einem", "a" },     .{ "einen", "a" },     .{ "eines", "a" },
    .{ "dieser", "this" }, .{ "diese", "this" },  .{ "dieses", "this" },
    .{ "jener", "that" },  .{ "jene", "that" },   .{ "jenes", "that" },
    // conjunctions / particles
    .{ "und", "and" },     .{ "oder", "or" },     .{ "aber", "but" },
    .{ "als", "as" },      .{ "auch", "also" },   .{ "noch", "still" },
    .{ "nur", "only" },    .{ "schon", "already" }, .{ "sehr", "very" },
    .{ "mehr", "more" },   .{ "nicht", "not" },
    .{ "kein", "no" },     .{ "keine", "no" },    .{ "keinem", "no" },
    .{ "keinen", "no" },   .{ "keiner", "no" },
    .{ "denn", "because" }, .{ "weil", "because" },
    .{ "wenn", "if" },     .{ "ob", "whether" },
    .{ "dass", "that" },   .{ "daß", "that" },
    .{ "doch", "yet" },    .{ "so", "so" },
    .{ "da", "there" },    .{ "hier", "here" },   .{ "dort", "there" },
    .{ "mal", "once" },
    // prepositions
    .{ "zu", "to" },       .{ "von", "from" },    .{ "mit", "with" },
    .{ "auf", "on" },      .{ "in", "in" },       .{ "im", "in" },
    .{ "am", "at" },       .{ "an", "at" },       .{ "aus", "out" },
    .{ "bei", "at" },      .{ "nach", "after" },  .{ "vor", "before" },
    .{ "für", "for" },     .{ "fuer", "for" },
    .{ "über", "over" },   .{ "ueber", "over" },
    .{ "um", "around" },   .{ "durch", "through" },
    .{ "gegen", "against" }, .{ "ohne", "without" },
    .{ "unter", "under" }, .{ "zwischen", "between" },
    // pronouns
    .{ "ich", "i" },       .{ "du", "you" },      .{ "er", "he" },
    .{ "sie", "she" },     .{ "es", "it" },       .{ "wir", "we" },
    .{ "ihr", "you" },     .{ "man", "one" },     .{ "sich", "itself" },
    .{ "mich", "me" },     .{ "mir", "me" },
    .{ "dich", "you" },    .{ "dir", "you" },
    .{ "ihm", "him" },     .{ "ihn", "him" },
    .{ "uns", "us" },      .{ "euch", "you" },
    .{ "was", "what" },    .{ "wie", "how" },     .{ "wer", "who" },
    .{ "wo", "where" },    .{ "wann", "when" },
    .{ "welche", "which" }, .{ "welcher", "which" }, .{ "welches", "which" },
    // light verbs / auxiliaries
    .{ "ist", "is" },      .{ "sind", "are" },
    .{ "war", "was" },     .{ "waren", "were" },
    .{ "bin", "am" },      .{ "bist", "are" },    .{ "sein", "be" },
    .{ "hat", "has" },     .{ "haben", "have" },
    .{ "hatte", "had" },   .{ "hatten", "had" },
    .{ "wird", "will" },   .{ "werden", "become" },
    .{ "wurde", "became" }, .{ "wurden", "became" },
    .{ "kann", "can" },    .{ "können", "can" },  .{ "koennen", "can" },
    .{ "muss", "must" },   .{ "muß", "must" },
    .{ "müssen", "must" }, .{ "muessen", "must" },
    .{ "soll", "should" }, .{ "sollen", "should" },
    .{ "will", "want" },   .{ "wollen", "want" },
    .{ "darf", "may" },    .{ "dürfen", "may" },  .{ "duerfen", "may" },
    .{ "mag", "like" },    .{ "mögen", "like" },  .{ "moegen", "like" },
    // high-frequency news / product content heads
    .{ "regierung", "government" },
    .{ "polizei", "police" },
    .{ "stadt", "city" },
    .{ "wasser", "water" },
    .{ "krieg", "war" },
    .{ "gesetz", "law" },
    .{ "wirtschaft", "economy" },
    .{ "unternehmen", "company" },
    .{ "jahr", "year" },
    .{ "jahren", "years" },
    .{ "frei", "free" },
    .{ "kostenlos", "free" },
    .{ "land", "country" },
    .{ "menschen", "people" },
    .{ "mensch", "person" },
    .{ "zeit", "time" },
    .{ "tag", "day" },
    .{ "tage", "days" },
    .{ "welt", "world" },
    .{ "haus", "house" },
    .{ "arbeit", "work" },
    .{ "schule", "school" },
    .{ "kind", "child" },
    .{ "kinder", "children" },
    .{ "frau", "woman" },
    .{ "mann", "man" },
    .{ "geld", "money" },
    .{ "leben", "life" },
    .{ "tod", "death" },
    .{ "gut", "good" },
    .{ "neu", "new" },
    .{ "alt", "old" },
    .{ "groß", "large" },
    .{ "gross", "large" },
    .{ "klein", "small" },
    .{ "heute", "today" },
    .{ "morgen", "tomorrow" },
    .{ "gestern", "yesterday" },
    .{ "jetzt", "now" },
    .{ "immer", "always" },
    .{ "nie", "never" },
    .{ "ja", "yes" },
    .{ "nein", "no" },
    .{ "bitte", "please" },
    .{ "danke", "thanks" },
    .{ "hallo", "hello" },
    .{ "tschuess", "bye" },
    .{ "tschüss", "bye" },
    .{ "katze", "cat" },
    .{ "hund", "dog" },
    .{ "brot", "bread" },
    .{ "milch", "milk" },
    .{ "buch", "book" },
    .{ "wort", "word" },
    .{ "sprache", "language" },
    .{ "könig", "king" },
    .{ "koenig", "king" },
    .{ "blut", "blood" },
    .{ "himmel", "sky" },
};

fn eqAsciiLower(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    var i: usize = 0;
    while (i < a.len) : (i += 1) {
        var ca = a[i];
        var cb = b[i];
        if (ca >= 'A' and ca <= 'Z') ca += 32;
        if (cb >= 'A' and cb <= 'Z') cb += 32;
        if (ca != cb) return false;
    }
    return true;
}

pub fn densifyDe(form: []const u8) ?[]const u8 {
    for (DE_CLOSED) |pair| {
        if (eqAsciiLower(form, pair[0])) return pair[1];
    }
    return null;
}

/// DE text → machine frame: densify each token to EN sense token (thin table).
pub fn deTextToFrame(text: []const u8, out: *pflt_ml.MachineFrame) void {
    out.clear();
    out.path_id = pflt_ml.PATH_MACHINE;
    var i: usize = 0;
    while (i < text.len and out.n_words < pflt_ml.MAX_WORDS) {
        while (i < text.len and (text[i] <= 32 or text[i] == ',' or text[i] == '.' or text[i] == ';' or text[i] == ':' or text[i] == '!' or text[i] == '?')) : (i += 1) {}
        if (i >= text.len) break;
        const start = i;
        while (i < text.len and text[i] > 32 and text[i] != ',' and text[i] != '.' and text[i] != ';' and text[i] != ':' and text[i] != '!' and text[i] != '?') : (i += 1) {}
        const tok = text[start..i];
        const en = densifyDe(tok) orelse tok;
        out.words[out.n_words] = pflt_ml.tokenToWord(pflt_ml.senseToken(en));
        out.n_words += 1;
        out.n_trits +%= 32;
    }
}

pub fn densifySelfTest() struct { ok: bool, hits: u32, n: u32 } {
    const pairs = [_]struct { []const u8, []const u8 }{
        .{ "die", "the" },
        .{ "hat", "has" },
        .{ "regierung", "government" },
        .{ "wasser", "water" },
        .{ "frei", "free" },
        .{ "sein", "be" },
        .{ "können", "can" },
        .{ "katze", "cat" },
    };
    var hits: u32 = 0;
    for (pairs) |p| {
        const g = densifyDe(p[0]) orelse continue;
        if (eqAsciiLower(g, p[1])) hits += 1;
    }
    return .{ .ok = hits == pairs.len, .hits = hits, .n = pairs.len };
}
