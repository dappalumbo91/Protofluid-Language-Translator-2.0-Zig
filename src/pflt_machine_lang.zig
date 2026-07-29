//! PFLT machine tongue — self-contained (reference: embodiment machine_lang_fixed).
//!
//! Doctrine:
//!   mind tongue  = trits / TritWords / FSOT frames
//!   human text   = thin table over that tongue (densify), not a second mind
//!   generate/understand/run use the same substrate
//!
//! Does NOT import neuron/organism (PFLT language slice only).

const std = @import("std");
const fixed = @import("fixed.zig");
const trit = @import("trit.zig");
const machine = @import("machine_encode_fixed.zig");
const frame_inj = @import("frame_inject.zig");
const token_hash = @import("token_hash.zig");
const Fixed = fixed.Fixed;

pub const PATH_MACHINE: u8 = 1;
pub const ABI_VERSION: u8 = 1;
pub const MAX_WORDS: usize = 16;
pub const MAX_FRAME_BYTES: usize = 10 + MAX_WORDS * 12;
pub const MAX_TRITS: usize = 32 * MAX_WORDS;

pub const MachineWord = struct {
    pack: u64 = 0,
    n_trits: u8 = 0,
};

pub const MachineFrame = struct {
    version: u8 = ABI_VERSION,
    path_id: u8 = PATH_MACHINE,
    n_trits: u32 = 0,
    words: [MAX_WORDS]MachineWord = [_]MachineWord{.{}} ** MAX_WORDS,
    n_words: usize = 0,

    pub fn clear(self: *MachineFrame) void {
        self.* = .{};
        self.version = ABI_VERSION;
        self.path_id = PATH_MACHINE;
    }

    pub fn toBytes(self: *const MachineFrame, out: []u8) usize {
        if (out.len < 10) return 0;
        @memcpy(out[0..4], &frame_inj.magic);
        out[4] = self.version;
        out[5] = self.path_id;
        std.mem.writeInt(u32, out[6..10], self.n_trits, .little);
        var off: usize = 10;
        var i: usize = 0;
        while (i < self.n_words and off + 12 <= out.len) : (i += 1) {
            std.mem.writeInt(u64, out[off .. off + 8][0..8], self.words[i].pack, .little);
            out[off + 8] = self.words[i].n_trits;
            out[off + 9] = 0;
            out[off + 10] = 0;
            out[off + 11] = 0;
            off += 12;
        }
        return off;
    }

    pub fn fromBytes(buf: []const u8) ?MachineFrame {
        const h = frame_inj.parseHeader(buf) orelse return null;
        var f: MachineFrame = .{};
        f.version = h.version;
        f.path_id = h.path_id;
        f.n_trits = h.n_trits;
        var off: usize = 10;
        while (off + 12 <= buf.len and f.n_words < MAX_WORDS) {
            f.words[f.n_words] = .{
                .pack = std.mem.readInt(u64, buf[off .. off + 8][0..8], .little),
                .n_trits = buf[off + 8],
            };
            f.n_words += 1;
            off += 12;
        }
        return f;
    }

    pub fn toTrits(self: *const MachineFrame, out: []trit.Trit) usize {
        var n: usize = 0;
        var w: usize = 0;
        while (w < self.n_words) : (w += 1) {
            const nw = @min(@as(usize, self.words[w].n_trits), @as(usize, 32));
            var i: u8 = 0;
            while (i < nw and n < out.len) : (i += 1) {
                const bits: u8 = @truncate(self.words[w].pack >> @intCast(2 * i));
                out[n] = trit.unpackT1(bits) orelse 0;
                n += 1;
            }
        }
        return n;
    }

    pub fn toFeatures(self: *const MachineFrame, out: *[8]Fixed) usize {
        var trits: [MAX_TRITS]trit.Trit = undefined;
        const nt = self.toTrits(trits[0..]);
        return machine.tritsToFeatures(trits[0..nt], out[0..]);
    }
};

pub fn tokenToWord(tok: u32) MachineWord {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, tok, .little);
    var trits: [32]trit.Trit = .{0} ** 32;
    _ = machine.bytesToTrits(bytes[0..], trits[0..]);
    const tw = trit.TritWord.fromTrits(trits[0..32]);
    return .{ .pack = tw.pack, .n_trits = 32 };
}

pub fn senseToken(en_gloss: []const u8) u32 {
    return token_hash.hashToken(en_gloss);
}

/// Raw UTF-8 → machine frame (bytes as machine form).
pub fn generateFromText(text: []const u8, out: *MachineFrame) void {
    out.clear();
    out.path_id = PATH_MACHINE;
    var trits: [machine.MAX_TRITS]trit.Trit = undefined;
    const nt = machine.bytesToTrits(text, trits[0..]);
    var words: [MAX_WORDS]trit.TritWord = undefined;
    const nw = machine.tritsToWords(trits[0..nt], words[0..]);
    var i: usize = 0;
    while (i < nw and out.n_words < MAX_WORDS) : (i += 1) {
        out.words[out.n_words] = .{ .pack = words[i].pack, .n_trits = words[i].n };
        out.n_words += 1;
    }
    out.n_trits = @intCast(nt);
}

pub fn textRoundTrip(text: []const u8, out_text: []u8) struct { ok: bool, n: usize } {
    var f: MachineFrame = .{};
    generateFromText(text, &f);
    var raw: [MAX_FRAME_BYTES]u8 = undefined;
    const nb = f.toBytes(raw[0..]);
    const f2 = MachineFrame.fromBytes(raw[0..nb]) orelse return .{ .ok = false, .n = 0 };
    var trits: [MAX_TRITS]trit.Trit = undefined;
    const nt = f2.toTrits(trits[0..]);
    const nback = machine.tritsToBytes(trits[0..nt], out_text);
    const ok = nback == text.len and std.mem.eql(u8, out_text[0..nback], text);
    return .{ .ok = ok, .n = nback };
}
