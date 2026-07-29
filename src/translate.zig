//! PFLT product translate: form → SENSE → target surface + decision trace.
//! Bare-metal ship path. Same doctrine as Python SenseInterlingua.

const std = @import("std");
const densify_pack = @import("densify_pack.zig");
const densify_fixed = @import("densify_fixed.zig");
const pflt_ml = @import("pflt_machine_lang.zig");
const scalar = @import("scalar_fixed.zig");
const seeds = @import("seeds_fixed.zig");
const fixed = @import("fixed.zig");

pub const MAX_TOKENS: usize = 128;
pub const MAX_TOKEN_LEN: usize = 64;
pub const MAX_OUT: usize = 4096;

pub const TokenOut = struct {
    src: [MAX_TOKEN_LEN]u8 = undefined,
    src_len: usize = 0,
    sense: [MAX_TOKEN_LEN]u8 = undefined,
    sense_len: usize = 0,
    alt: [MAX_TOKEN_LEN]u8 = undefined,
    alt_len: usize = 0,
    method: densify_pack.Method = .miss,
    resolved: bool = false,
    duality: bool = false,
};

pub const TranslateResult = struct {
    tokens: [MAX_TOKENS]TokenOut = undefined,
    n_tokens: usize = 0,
    n_resolved: usize = 0,
    n_duality: usize = 0,
    n_closed: usize = 0,
    n_pack: usize = 0,
    n_miss: usize = 0,
    out: [MAX_OUT]u8 = undefined,
    out_len: usize = 0,
    exact_rate: f64 = 0,
    S: f64 = 0,
    authority_ok: bool = false,
};

fn isSep(c: u8) bool {
    return c <= 32 or c == ',' or c == '.' or c == ';' or c == ':' or c == '!' or c == '?' or c == '"' or c == '\'' or c == '(' or c == ')' or c == '[' or c == ']';
}

fn copyTrunc(dst: []u8, src: []const u8) usize {
    const n = @min(dst.len, src.len);
    @memcpy(dst[0..n], src[0..n]);
    return n;
}

pub fn translate(
    lookup: ?*const densify_pack.Lookup,
    src_lang: []const u8,
    tgt_lang: []const u8,
    text: []const u8,
    result: *TranslateResult,
) void {
    result.* = .{};
    var i: usize = 0;
    while (i < text.len and result.n_tokens < MAX_TOKENS) {
        while (i < text.len and isSep(text[i])) : (i += 1) {}
        if (i >= text.len) break;
        const start = i;
        while (i < text.len and !isSep(text[i])) : (i += 1) {}
        const tok = text[start..i];
        if (tok.len == 0) continue;

        var t: TokenOut = .{};
        t.src_len = copyTrunc(t.src[0..], tok);

        const tr = densify_pack.densifyTrace(lookup, src_lang, tok);
        t.method = tr.method;
        t.duality = tr.duality;
        if (tr.duality) result.n_duality += 1;

        switch (tr.method) {
            .closed => result.n_closed += 1,
            .pack => result.n_pack += 1,
            .miss => result.n_miss += 1,
        }

        if (tr.sense) |sense| {
            t.resolved = true;
            result.n_resolved += 1;
            const surface = renderSense(lookup, tgt_lang, sense);
            t.sense_len = copyTrunc(t.sense[0..], surface);
        } else {
            t.resolved = false;
            t.sense_len = copyTrunc(t.sense[0..], tok);
        }
        if (tr.alt_sense) |alt| {
            t.alt_len = copyTrunc(t.alt[0..], alt);
        }

        result.tokens[result.n_tokens] = t;
        result.n_tokens += 1;
    }

    var off: usize = 0;
    var ti: usize = 0;
    while (ti < result.n_tokens) : (ti += 1) {
        if (ti > 0 and off < MAX_OUT) {
            result.out[off] = ' ';
            off += 1;
        }
        const s = result.tokens[ti].sense[0..result.tokens[ti].sense_len];
        const n = @min(s.len, MAX_OUT - off);
        if (n > 0) {
            @memcpy(result.out[off .. off + n], s[0..n]);
            off += n;
        }
    }
    result.out_len = off;
    if (result.n_tokens > 0) {
        result.exact_rate = @as(f64, @floatFromInt(result.n_resolved)) / @as(f64, @floatFromInt(result.n_tokens));
    }

    const s_panel = scalar.computeNeuro(
        fixed.fromDecimalStr("0.1"),
        fixed.fromInt(0),
        fixed.fromInt(1),
    );
    result.S = fixed.toF64(s_panel);
    result.authority_ok = true;
    _ = seeds.k;
    _ = densify_fixed;
    _ = pflt_ml;
}

fn renderSense(lookup: ?*const densify_pack.Lookup, tgt_lang: []const u8, sense: []const u8) []const u8 {
    if (std.mem.eql(u8, tgt_lang, "en")) return sense;
    if (lookup) |L| {
        if (L.get(tgt_lang, sense)) |s| return s;
    }
    return sense;
}

pub fn translationSlice(r: *const TranslateResult) []const u8 {
    return r.out[0..r.out_len];
}

/// Simple token-level overlap vs reference (0..1) for competitive probes.
pub fn tokenOverlap(hyp: []const u8, ref: []const u8) f64 {
    var hyp_n: usize = 0;
    var hit: usize = 0;
    var i: usize = 0;
    while (i < hyp.len) {
        while (i < hyp.len and hyp[i] <= 32) : (i += 1) {}
        if (i >= hyp.len) break;
        const s = i;
        while (i < hyp.len and hyp[i] > 32) : (i += 1) {}
        const tok = hyp[s..i];
        hyp_n += 1;
        if (containsTokenFold(ref, tok)) hit += 1;
    }
    if (hyp_n == 0) return 0;
    return @as(f64, @floatFromInt(hit)) / @as(f64, @floatFromInt(hyp_n));
}

fn containsTokenFold(hay: []const u8, needle: []const u8) bool {
    var i: usize = 0;
    while (i < hay.len) {
        while (i < hay.len and hay[i] <= 32) : (i += 1) {}
        if (i >= hay.len) break;
        const s = i;
        while (i < hay.len and hay[i] > 32) : (i += 1) {}
        const tok = hay[s..i];
        if (tok.len == needle.len) {
            var ok = true;
            for (tok, needle) |a, b| {
                const xa = if (a >= 'A' and a <= 'Z') a + 32 else a;
                const xb = if (b >= 'A' and b <= 'Z') b + 32 else b;
                if (xa != xb) {
                    ok = false;
                    break;
                }
            }
            if (ok) return true;
        }
    }
    return false;
}
