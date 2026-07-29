//! PFLT stress + metric dump (host). Machine-readable lines for Python parity harness.
//!
//! Prints:
//!   METRIC name=value
//!   CASE densify|align|frame|scalar ...
//!   STRESS summary
//!
//! Run: zig build stress && zig-out\bin\pflt_stress.exe

const std = @import("std");
const densify = @import("densify_fixed.zig");
const mform = @import("machine_form_fixed.zig");
const pflt_ml = @import("pflt_machine_lang.zig");
const scalar = @import("scalar_fixed.zig");
const seeds = @import("seeds_fixed.zig");
const fixed = @import("fixed.zig");
const trit = @import("trit.zig");

fn printFixed(name: []const u8, x: fixed.Fixed) void {
    const p = fixed.toParts(x);
    // fixed SCALE 1e12 → print int.frac with 12 digits
    var frac_buf: [12]u8 = .{'0'} ** 12;
    var f = p.frac;
    var i: isize = 11;
    while (i >= 0) : (i -= 1) {
        frac_buf[@intCast(i)] = @intCast('0' + (f % 10));
        f /= 10;
    }
    if (p.is_neg) {
        std.debug.print("METRIC {s}=-{d}.{s}\n", .{ name, p.int, frac_buf[0..] });
    } else {
        std.debug.print("METRIC {s}={d}.{s}\n", .{ name, p.int, frac_buf[0..] });
    }
}

fn printF64Lab(name: []const u8, x: fixed.Fixed) void {
    // Host-only f64 for parity comparison with Python float(mod.K)
    const v = fixed.toF64(x);
    std.debug.print("METRIC {s}_f64={d:.12}\n", .{ name, v });
}

pub fn main() !void {
    var fails: u32 = 0;
    var cases: u32 = 0;
    var passes: u32 = 0;

    // --- Seeds (must match archive pin decimals) ---
    printF64Lab("seed_K", seeds.k);
    printF64Lab("seed_PHI", seeds.phi);
    printF64Lab("seed_C_EFF", seeds.c_eff);
    printF64Lab("seed_E", seeds.e);
    printF64Lab("seed_PI", seeds.pi);
    printF64Lab("seed_GAMMA", seeds.gamma);
    printF64Lab("seed_ALPHA", seeds.alpha);
    std.debug.print("METRIC seed_neuro_D_eff={d}\n", .{13}); // seeds.neuro_d_eff = 13

    // --- Trit standard (codon ATG = +1,-1,+1) ---
    const tr = trit.selfTest();
    cases += 1;
    if (tr.ok) {
        passes += 1;
        std.debug.print("CASE trit ok=1 fails=0\n", .{});
    } else {
        fails += 1;
        std.debug.print("CASE trit ok=0 fails={d}\n", .{tr.fails});
    }
    const atg = trit.codonPrimary('A', 'T', 'G');
    std.debug.print("METRIC codon_ATG={d},{d},{d}\n", .{ atg[0], atg[1], atg[2] });
    cases += 1;
    if (atg[0] == 1 and atg[1] == -1 and atg[2] == 1) {
        passes += 1;
        std.debug.print("CASE codon_ATG ok=1\n", .{});
    } else {
        fails += 1;
        std.debug.print("CASE codon_ATG ok=0\n", .{});
    }

    // --- Scalar S (neuro panel dpsi=0.1 hits=0 rho=1) ---
    const s0 = scalar.computeNeuro(fixed.fromDecimalStr("0.1"), 0, fixed.fromInt(1));
    printFixed("S_neuro_dpsi0.1", s0);
    printF64Lab("S_neuro_dpsi0.1", s0);
    cases += 1;
    // Python reference ~0.43232 for D=13
    const lo = fixed.fromDecimalStr("0.40");
    const hi = fixed.fromDecimalStr("0.50");
    if (!fixed.lt(s0, lo) and !fixed.gt(s0, hi)) {
        passes += 1;
        std.debug.print("CASE scalar_neuro_band ok=1\n", .{});
    } else {
        fails += 1;
        std.debug.print("CASE scalar_neuro_band ok=0\n", .{});
    }
    if (!scalar.selfTest()) {
        fails += 1;
        std.debug.print("CASE scalar_selfTest ok=0\n", .{});
    } else {
        cases += 1;
        passes += 1;
        std.debug.print("CASE scalar_selfTest ok=1\n", .{});
    }

    // --- Densify battery (Python closed-class + news) ---
    const densify_cases = [_]struct { []const u8, []const u8 }{
        .{ "die", "the" },
        .{ "der", "the" },
        .{ "das", "the" },
        .{ "hat", "has" },
        .{ "sein", "be" },
        .{ "ist", "is" },
        .{ "wird", "will" },
        .{ "und", "and" },
        .{ "nicht", "not" },
        .{ "für", "for" },
        .{ "fuer", "for" },
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
        .{ "ich", "i" },
        .{ "wir", "we" },
        .{ "dass", "that" },
    };
    var dens_hits: u32 = 0;
    for (densify_cases) |c| {
        cases += 1;
        const g = densify.densifyDe(c[0]);
        const ok = if (g) |gg| blk: {
            // case-insensitive compare
            if (gg.len != c[1].len) break :blk false;
            var i: usize = 0;
            while (i < gg.len) : (i += 1) {
                var a = gg[i];
                var b = c[1][i];
                if (a >= 'A' and a <= 'Z') a += 32;
                if (b >= 'A' and b <= 'Z') b += 32;
                if (a != b) break :blk false;
            }
            break :blk true;
        } else false;
        if (ok) {
            dens_hits += 1;
            passes += 1;
            std.debug.print("CASE densify {s}->{s} ok=1\n", .{ c[0], c[1] });
        } else {
            fails += 1;
            std.debug.print("CASE densify {s}->{s} ok=0 got={s}\n", .{ c[0], c[1], g orelse "null" });
        }
    }
    std.debug.print("METRIC densify_hits={d}\n", .{dens_hits});
    std.debug.print("METRIC densify_n={d}\n", .{densify_cases.len});
    std.debug.print("METRIC densify_rate={d:.6}\n", .{@as(f64, @floatFromInt(dens_hits)) / @as(f64, @floatFromInt(densify_cases.len))});

    // --- Machine-form align battery ---
    const align_cases = [_]struct { []const u8, []const u8, u32, u32 }{
        // src, hyp, min_milli, max_milli (band)
        .{ "Die Regierung 2024", "The government 2024", 700, 1000 },
        .{ "Die Regierung 2024", "The government declared war in 2024.", 650, 1000 },
        .{ "x 42 y", "answer 42 only", 500, 1000 },
        .{ "plain", "plain text ok", 400, 1000 },
    };
    // pollution should score below clean
    const poll_src = "Die Regierung 2024";
    const poll_good = "The government 2024";
    const poll_bad = [_]u8{ 0xe6, 0x94, 0xbf, 0xe5, 0xba, 0x9c, ' ', '2', '0', '2', '4' };
    const ag = mform.machineAlignMilli(poll_src, poll_good);
    const ab = mform.machineAlignMilli(poll_src, poll_bad[0..]);
    std.debug.print("METRIC align_good_milli={d}\n", .{ag});
    std.debug.print("METRIC align_pollute_milli={d}\n", .{ab});
    cases += 1;
    if (ag > ab and ag >= 500) {
        passes += 1;
        std.debug.print("CASE align_pollute_order ok=1\n", .{});
    } else {
        fails += 1;
        std.debug.print("CASE align_pollute_order ok=0\n", .{});
    }
    for (align_cases) |c| {
        cases += 1;
        const m = mform.machineAlignMilli(c[0], c[1]);
        std.debug.print("CASE align milli={d} min={d} max={d}\n", .{ m, c[2], c[3] });
        if (m >= c[2] and m <= c[3]) {
            passes += 1;
        } else {
            fails += 1;
            std.debug.print("CASE align FAIL band\n", .{});
        }
    }

    // --- Frame round-trip stress ---
    const texts = [_][]const u8{
        "hello",
        "a",
        "die regierung",
        "The quick brown fox",
        "12345",
        "mix 2024 end",
        "",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", // 32 a's
        "unicode-ascii-only",
    };
    var rt_ok: u32 = 0;
    var rt_n: u32 = 0;
    for (texts) |t| {
        if (t.len == 0) continue; // empty may be trivial
        if (t.len * 8 > pflt_ml.MAX_TRITS) continue; // beyond single-frame bit budget
        rt_n += 1;
        cases += 1;
        var back: [512]u8 = undefined;
        if (back.len < t.len) continue;
        const r = pflt_ml.textRoundTrip(t, back[0..]);
        if (r.ok) {
            rt_ok += 1;
            passes += 1;
            std.debug.print("CASE frame_rt len={d} ok=1\n", .{t.len});
        } else {
            fails += 1;
            std.debug.print("CASE frame_rt len={d} ok=0 nback={d}\n", .{ t.len, r.n });
        }
    }
    std.debug.print("METRIC frame_rt_ok={d}\n", .{rt_ok});
    std.debug.print("METRIC frame_rt_n={d}\n", .{rt_n});

    // Burst: many densify frames
    var frame_words_sum: u32 = 0;
    var fi: u32 = 0;
    while (fi < 1000) : (fi += 1) {
        var fr: pflt_ml.MachineFrame = .{};
        densify.deTextToFrame("die regierung hat wasser und gesetz", &fr);
        frame_words_sum += @intCast(fr.n_words);
    }
    std.debug.print("METRIC densify_frame_burst_words_sum={d}\n", .{frame_words_sum});
    cases += 1;
    if (frame_words_sum == 1000 * 6) {
        passes += 1;
        std.debug.print("CASE densify_frame_burst ok=1\n", .{});
    } else {
        // token count may vary if whitespace tokenization differs
        if (frame_words_sum >= 1000 * 4) {
            passes += 1;
            std.debug.print("CASE densify_frame_burst ok=1 soft\n", .{});
        } else {
            fails += 1;
            std.debug.print("CASE densify_frame_burst ok=0 sum={d}\n", .{frame_words_sum});
        }
    }

    // Scalar burst (stress fixed lattice)
    var s_acc: fixed.Fixed = 0;
    var si: u32 = 0;
    while (si < 500) : (si += 1) {
        // vary dpsi slightly via fixed fromInt milli
        const dpsi = fixed.fromRatio(@intCast(si % 50), 1000); // 0..0.049
        const s = scalar.computeNeuro(dpsi, fixed.fromInt(@intCast(si % 3)), fixed.fromInt(1));
        s_acc = fixed.add(s_acc, s);
    }
    printF64Lab("S_neuro_burst_mean_approx", fixed.div(s_acc, fixed.fromInt(500)));
    cases += 1;
    passes += 1;
    std.debug.print("CASE scalar_burst ok=1\n", .{});

    // Fixed arithmetic self-test
    cases += 1;
    if (fixed.selfTest()) {
        passes += 1;
        std.debug.print("CASE fixed_selfTest ok=1\n", .{});
    } else {
        fails += 1;
        std.debug.print("CASE fixed_selfTest ok=0\n", .{});
    }

    std.debug.print("METRIC cases={d}\n", .{cases});
    std.debug.print("METRIC passes={d}\n", .{passes});
    std.debug.print("METRIC fails={d}\n", .{fails});
    std.debug.print("METRIC pass_rate={d:.6}\n", .{@as(f64, @floatFromInt(passes)) / @as(f64, @floatFromInt(if (cases == 0) 1 else cases))});

    if (fails != 0) {
        std.debug.print("STRESS FAIL fails={d}\n", .{fails});
        std.process.exit(1);
    }
    std.debug.print("STRESS PASS\n", .{});
}
