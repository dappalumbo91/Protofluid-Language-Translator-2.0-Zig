//! Session decision log — how densify chose each form→sense.
//! Append-only JSONL for refinement (duality / wrong sense / misses).

const std = @import("std");
const translate_mod = @import("translate.zig");

pub const DEFAULT_PATH = "logs/decisions.jsonl";

fn escapeInto(buf: []u8, s: []const u8) []const u8 {
    var o: usize = 0;
    if (o < buf.len) {
        buf[o] = '"';
        o += 1;
    }
    for (s) |c| {
        switch (c) {
            '"' => {
                if (o + 2 <= buf.len) {
                    buf[o] = '\\';
                    buf[o + 1] = '"';
                    o += 2;
                }
            },
            '\\' => {
                if (o + 2 <= buf.len) {
                    buf[o] = '\\';
                    buf[o + 1] = '\\';
                    o += 2;
                }
            },
            '\n' => {
                if (o + 2 <= buf.len) {
                    buf[o] = '\\';
                    buf[o + 1] = 'n';
                    o += 2;
                }
            },
            '\r' => {
                if (o + 2 <= buf.len) {
                    buf[o] = '\\';
                    buf[o + 1] = 'r';
                    o += 2;
                }
            },
            '\t' => {
                if (o + 2 <= buf.len) {
                    buf[o] = '\\';
                    buf[o + 1] = 't';
                    o += 2;
                }
            },
            else => {
                if (o < buf.len) {
                    buf[o] = c;
                    o += 1;
                }
            },
        }
    }
    if (o < buf.len) {
        buf[o] = '"';
        o += 1;
    }
    return buf[0..o];
}

/// Ensure parent directory exists for path like logs/decisions.jsonl
pub fn ensureParentDir(path: []const u8) void {
    if (std.fs.path.dirname(path)) |dir| {
        std.fs.cwd().makePath(dir) catch {};
    }
}

/// Append one translation event as a JSONL line.
pub fn appendEvent(
    path: []const u8,
    src_lang: []const u8,
    tgt_lang: []const u8,
    input: []const u8,
    tr: *const translate_mod.TranslateResult,
    ref: ?[]const u8,
    note: ?[]const u8,
) !void {
    ensureParentDir(path);
    // open append; create if missing
    const file = blk: {
        break :blk std.fs.cwd().openFile(path, .{ .mode = .write_only }) catch {
            break :blk try std.fs.cwd().createFile(path, .{});
        };
    };
    defer file.close();
    try file.seekFromEnd(0);

    var line_buf: [16384]u8 = undefined;
    var o: usize = 0;

    const append = struct {
        fn go(buf: []u8, off: *usize, piece: []const u8) void {
            const n = @min(piece.len, buf.len - off.*);
            if (n > 0) {
                @memcpy(buf[off.* .. off.* + n], piece[0..n]);
                off.* += n;
            }
        }
    }.go;

    const appendFmt = struct {
        fn go(buf: []u8, off: *usize, comptime fmt: []const u8, args: anytype) void {
            const slice = std.fmt.bufPrint(buf[off.*..], fmt, args) catch return;
            off.* += slice.len;
        }
    }.go;

    var e1: [4096]u8 = undefined;
    var e2: [4096]u8 = undefined;
    const jin = escapeInto(e1[0..], input);
    const jout = escapeInto(e2[0..], translate_mod.translationSlice(tr));

    appendFmt(line_buf[0..], &o, "{{\"pin\":\"D1D38A\",\"src\":\"{s}\",\"tgt\":\"{s}\",\"input\":{s},\"output\":{s}", .{
        src_lang,
        tgt_lang,
        jin,
        jout,
    });
    appendFmt(line_buf[0..], &o, ",\"exact_rate\":{d:.4},\"S\":{d:.6},\"n_tokens\":{d},\"n_resolved\":{d}", .{
        tr.exact_rate,
        tr.S,
        tr.n_tokens,
        tr.n_resolved,
    });
    appendFmt(line_buf[0..], &o, ",\"n_closed\":{d},\"n_pack\":{d},\"n_miss\":{d},\"n_duality\":{d}", .{
        tr.n_closed,
        tr.n_pack,
        tr.n_miss,
        tr.n_duality,
    });

    if (ref) |r| {
        var e3: [4096]u8 = undefined;
        const jr = escapeInto(e3[0..], r);
        appendFmt(line_buf[0..], &o, ",\"reference\":{s},\"overlap\":{d:.4}", .{
            jr,
            translate_mod.tokenOverlap(translate_mod.translationSlice(tr), r),
        });
    }
    if (note) |n| {
        var e4: [512]u8 = undefined;
        appendFmt(line_buf[0..], &o, ",\"note\":{s}", .{escapeInto(e4[0..], n)});
    }

    append(line_buf[0..], &o, ",\"decisions\":[");
    var i: usize = 0;
    while (i < tr.n_tokens) : (i += 1) {
        if (i > 0) append(line_buf[0..], &o, ",");
        const tok = tr.tokens[i];
        var ef: [256]u8 = undefined;
        var es: [256]u8 = undefined;
        const jf = escapeInto(ef[0..], tok.src[0..tok.src_len]);
        const js = escapeInto(es[0..], tok.sense[0..tok.sense_len]);
        appendFmt(line_buf[0..], &o, "{{\"i\":{d},\"form\":{s},\"sense\":{s},\"method\":\"{s}\",\"resolved\":{s},\"duality\":{s}", .{
            i,
            jf,
            js,
            tok.method.name(),
            if (tok.resolved) "true" else "false",
            if (tok.duality) "true" else "false",
        });
        if (tok.alt_len > 0) {
            var ea: [256]u8 = undefined;
            appendFmt(line_buf[0..], &o, ",\"alt_pack\":{s}", .{escapeInto(ea[0..], tok.alt[0..tok.alt_len])});
        }
        append(line_buf[0..], &o, "}");
    }
    append(line_buf[0..], &o, "]}\n");
    try file.writeAll(line_buf[0..o]);
}

/// Print human decision table (for CLI / TUI).
pub fn printDecisionTable(tr: *const translate_mod.TranslateResult) void {
    std.debug.print("  #  form                 method   sense                duality/alt\n", .{});
    std.debug.print("  -- -------------------- -------- -------------------- ------------\n", .{});
    var i: usize = 0;
    while (i < tr.n_tokens) : (i += 1) {
        const tok = tr.tokens[i];
        const dual_note: []const u8 = if (tok.duality and tok.alt_len > 0)
            tok.alt[0..tok.alt_len]
        else if (tok.duality)
            "YES"
        else
            "-";
        std.debug.print("  {d:<2} {s:<20} {s:<8} {s:<20} {s}\n", .{
            i + 1,
            tok.src[0..tok.src_len],
            tok.method.name(),
            tok.sense[0..tok.sense_len],
            dual_note,
        });
    }
    if (tr.n_duality > 0) {
        std.debug.print("  !! duality conflicts (closed overrode pack): {d} — refine pack or closed table\n", .{tr.n_duality});
    }
    if (tr.n_miss > 0) {
        std.debug.print("  !! misses (no densify): {d} — add binds to pack\n", .{tr.n_miss});
    }
}
