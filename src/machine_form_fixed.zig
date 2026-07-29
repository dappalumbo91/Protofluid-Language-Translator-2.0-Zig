//! Machine-native form conservation — integer only (no i128 / soft-float).
//! Safe on freestanding Multiboot without FPU.
//! Score in millipoints [0,1000] then optional Fixed conversion on host.

const fixed = @import("fixed.zig");
const Fixed = fixed.Fixed;

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}
fn isAsciiLetter(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z');
}

fn hasDigitValue(text: []const u8, want: u32) bool {
    var i: usize = 0;
    while (i < text.len) {
        if (!isDigit(text[i])) {
            i += 1;
            continue;
        }
        var v: u32 = 0;
        while (i < text.len and isDigit(text[i])) : (i += 1) {
            v = v *% 10 +% (text[i] - '0');
        }
        if (v == want) return true;
    }
    return false;
}

/// Align score in [0,1000] milli-units (integer only).
pub fn machineAlignMilli(src: []const u8, hyp: []const u8) u32 {
    // 1) digit conservation
    var n_digs: u32 = 0;
    var dig_hits: u32 = 0;
    var i: usize = 0;
    while (i < src.len) {
        if (!isDigit(src[i])) {
            i += 1;
            continue;
        }
        var v: u32 = 0;
        while (i < src.len and isDigit(src[i])) : (i += 1) {
            v = v *% 10 +% (src[i] - '0');
        }
        n_digs += 1;
        if (hasDigitValue(hyp, v)) dig_hits += 1;
    }
    const dig_score: u32 = if (n_digs == 0) 500 else (dig_hits * 1000) / n_digs;

    // 2) letter mass near ~618/1000 (φ/(1+φ))
    var letters: u32 = 0;
    var hi: u32 = 0;
    for (hyp) |c| {
        if (isAsciiLetter(c)) letters += 1;
        if (c >= 0x80) hi += 1;
    }
    const len: u32 = if (hyp.len == 0) 1 else @intCast(hyp.len);
    const letter_frac: u32 = (letters * 1000) / len;
    const target_L: u32 = 618;
    const letter_dev: u32 = if (letter_frac > target_L) letter_frac - target_L else target_L - letter_frac;
    // score = 1000 - min(1000, dev * 2)  (φ≈1.6 ~ 2 for integer)
    var letter_score: u32 = 1000;
    const pen = letter_dev * 2;
    if (pen < letter_score) letter_score -= pen else letter_score = 0;

    // 3) pollution (high bytes)
    const poll: u32 = (hi * 1000) / len;
    var clean: u32 = 1000;
    const ppen = poll * 3;
    if (ppen < clean) clean -= ppen else clean = 0;

    // golden-ish nest with integer weights ~ φ:1  =>  618:382 of mid, then clean
    const mid: u32 = (dig_score * 618 + letter_score * 382) / 1000;
    return (mid * 618 + clean * 382) / 1000;
}

pub fn machineAlign(src: []const u8, hyp: []const u8) Fixed {
    // Host path: convert milli → Fixed (SCALE/1000)
    const m = machineAlignMilli(src, hyp);
    return fixed.fromRatio(@intCast(m), 1000);
}

pub fn alignSelfTest() struct { ok: bool } {
    const src = "Die Regierung 2024";
    const good = "The government 2024";
    // high-byte pollution (not valid UTF-8 needed — raw bytes)
    const bad = [_]u8{ 0xe6, 0x94, 0xbf, 0xe5, 0xba, 0x9c, ' ', '2', '0', '2', '4' };
    const ag = machineAlignMilli(src, good);
    const ab = machineAlignMilli(src, bad[0..]);
    return .{ .ok = ag > 500 and ab < ag };
}
