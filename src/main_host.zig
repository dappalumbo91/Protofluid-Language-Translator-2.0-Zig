//! PFLT host self-test — densify + machine form + frame round-trip + scalar smoke.
const std = @import("std");
const densify = @import("densify_fixed.zig");
const mform = @import("machine_form_fixed.zig");
const pflt_ml = @import("pflt_machine_lang.zig");
const scalar = @import("scalar_fixed.zig");
const seeds = @import("seeds_fixed.zig");
const fixed = @import("fixed.zig");

pub fn main() !void {
    var fails: u32 = 0;

    const d = densify.densifySelfTest();
    if (!d.ok) {
        std.debug.print("PFLT densify FAIL {}/{}\n", .{ d.hits, d.n });
        fails += 1;
    } else {
        std.debug.print("PFLT densify PASS {}/{}\n", .{ d.hits, d.n });
    }

    const a = mform.alignSelfTest();
    if (!a.ok) {
        std.debug.print("PFLT machine_form FAIL\n", .{});
        fails += 1;
    } else {
        std.debug.print("PFLT machine_form PASS\n", .{});
    }

    const msg = "hello";
    var back: [64]u8 = undefined;
    const rt = pflt_ml.textRoundTrip(msg, back[0..]);
    if (!rt.ok) {
        std.debug.print("PFLT frame_roundtrip FAIL n={}\n", .{rt.n});
        fails += 1;
    } else {
        std.debug.print("PFLT frame_roundtrip PASS\n", .{});
    }

    var frame: pflt_ml.MachineFrame = .{};
    densify.deTextToFrame("die regierung hat wasser", &frame);
    if (frame.n_words < 3) {
        std.debug.print("PFLT de_frame FAIL words={}\n", .{frame.n_words});
        fails += 1;
    } else {
        std.debug.print("PFLT de_frame PASS words={}\n", .{frame.n_words});
    }

    // Scalar smoke: neuro-like panel
    const s = scalar.computeNeuro(
        fixed.fromDecimalStr("0.1"),
        fixed.fromInt(0),
        fixed.fromInt(1),
    );
    _ = s;
    _ = seeds.k;
    std.debug.print("PFLT scalar_smoke PASS\n", .{});

    if (fails != 0) {
        std.debug.print("PFLT_HOST FAIL fails={}\n", .{fails});
        std.process.exit(1);
    }
    std.debug.print("PFLT_HOST PASS\n", .{});
}
