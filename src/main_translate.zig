//! PFLT 2.0 standalone translator — product binary people can run and share.
//! form → SENSE → form (densify table + FSOT law panel). Not NMT.
//!
//! Usage:
//!   pflt                    # modern TUI (default)
//!   pflt tui
//!   pflt translate de en "die regierung hat wasser"
//!   pflt de en "..."
//!   pflt --json translate de en "..."
//!   pflt compare data/gold_pairs.tsv
//!   pflt selftest

const std = @import("std");
const densify_pack = @import("densify_pack.zig");
const densify_fixed = @import("densify_fixed.zig");
const translate_mod = @import("translate.zig");
const decision_log = @import("decision_log.zig");
const tui = @import("tui.zig");
const mform = @import("machine_form_fixed.zig");
const pflt_ml = @import("pflt_machine_lang.zig");

const VERSION = "2.0.0-zig";

fn printUsage() void {
    std.debug.print(
        \\PFLT 2.0 — Protofluid Language Translator (Zig)
        \\Version {s}
        \\
        \\Usage:
        \\  pflt                         modern TUI (default)
        \\  pflt tui                     modern terminal UI
        \\  pflt translate <src> <tgt> <text...>
        \\  pflt <src> <tgt> <text...>
        \\  pflt <text...>               default de→en
        \\  pflt compare <gold.tsv>      competitive probe vs references
        \\  pflt --pack <path> ...
        \\  pflt --json translate de en "..."
        \\  pflt --log <path> ...        decision log JSONL (default logs/decisions.jsonl)
        \\  pflt --nolog ...
        \\  pflt selftest
        \\  pflt version
        \\
        \\Doctrine: form → SENSE → form (finite densify). No NMT. Pin D1D38A.
        \\Decision log records method (closed|pack|miss) and yin–yang duality overrides.
        \\
    , .{VERSION});
}

fn findPackPath(allocator: std.mem.Allocator, explicit: ?[]const u8) !?[]const u8 {
    if (explicit) |p| {
        std.fs.cwd().access(p, .{}) catch return null;
        return try allocator.dupe(u8, p);
    }
    const candidates = [_][]const u8{
        "densify_pack.tsv",
        "data\\densify_pack.tsv",
        "data/densify_pack.tsv",
        "I:\\pflt\\embodiment\\zig\\data\\densify_pack.tsv",
    };
    for (candidates) |c| {
        std.fs.cwd().access(c, .{}) catch continue;
        return try allocator.dupe(u8, c);
    }
    var exe_buf: [std.fs.max_path_bytes]u8 = undefined;
    const exe = std.fs.selfExePath(&exe_buf) catch return null;
    if (std.fs.path.dirname(exe)) |dir| {
        const beside = try std.fs.path.join(allocator, &[_][]const u8{ dir, "densify_pack.tsv" });
        defer allocator.free(beside);
        std.fs.cwd().access(beside, .{}) catch {
            const data_beside = try std.fs.path.join(allocator, &[_][]const u8{ dir, "data", "densify_pack.tsv" });
            std.fs.cwd().access(data_beside, .{}) catch {
                allocator.free(data_beside);
                return null;
            };
            return data_beside;
        };
        return try allocator.dupe(u8, beside);
    }
    return null;
}

fn runSelftest() !void {
    var fails: u32 = 0;
    const d = densify_fixed.densifySelfTest();
    if (!d.ok) {
        std.debug.print("densify FAIL {}/{}\n", .{ d.hits, d.n });
        fails += 1;
    } else {
        std.debug.print("densify PASS {}/{}\n", .{ d.hits, d.n });
    }
    const a = mform.alignSelfTest();
    if (!a.ok) {
        std.debug.print("machine_form FAIL\n", .{});
        fails += 1;
    } else {
        std.debug.print("machine_form PASS\n", .{});
    }
    var frame: pflt_ml.MachineFrame = .{};
    densify_fixed.deTextToFrame("die regierung hat wasser", &frame);
    if (frame.n_words < 3) {
        std.debug.print("de_frame FAIL words={}\n", .{frame.n_words});
        fails += 1;
    } else {
        std.debug.print("de_frame PASS words={}\n", .{frame.n_words});
    }
    var tr: translate_mod.TranslateResult = .{};
    translate_mod.translate(null, "de", "en", "die regierung hat wasser", &tr);
    const out = translate_mod.translationSlice(&tr);
    std.debug.print("translate smoke: {s}\n", .{out});
    std.debug.print("exact_rate={d:.2} tokens={d} resolved={d} S={d:.5} duality={d}\n", .{
        tr.exact_rate,
        tr.n_tokens,
        tr.n_resolved,
        tr.S,
        tr.n_duality,
    });
    if (tr.n_resolved < 3) fails += 1;
    if (fails != 0) {
        std.debug.print("PFLT selftest FAIL fails={d}\n", .{fails});
        std.process.exit(1);
    }
    std.debug.print("PFLT selftest PASS\n", .{});
}

fn doTranslate(
    lookup: ?*const densify_pack.Lookup,
    src: []const u8,
    tgt: []const u8,
    text: []const u8,
    as_json: bool,
    log_path: ?[]const u8,
) void {
    var tr: translate_mod.TranslateResult = .{};
    translate_mod.translate(lookup, src, tgt, text, &tr);
    const out = translate_mod.translationSlice(&tr);
    if (as_json) {
        printJson(text, src, tgt, &tr, out);
    } else {
        std.debug.print("IN  [{s}] {s}\n", .{ src, text });
        std.debug.print("OUT [{s}] {s}\n", .{ tgt, out });
        std.debug.print("exact_rate={d:.2}  resolved={d}/{d}  closed={d} pack={d} miss={d} duality={d}  S={d:.5}  pin=D1D38A\n", .{
            tr.exact_rate,
            tr.n_resolved,
            tr.n_tokens,
            tr.n_closed,
            tr.n_pack,
            tr.n_miss,
            tr.n_duality,
            tr.S,
        });
        decision_log.printDecisionTable(&tr);
    }
    if (log_path) |lp| {
        decision_log.appendEvent(lp, src, tgt, text, &tr, null, "cli") catch |err| {
            std.debug.print("warn: decision log write failed: {}\n", .{err});
        };
    }
}

fn escapeJson(s: []const u8, buf: []u8) []const u8 {
    var o: usize = 0;
    if (o < buf.len) {
        buf[o] = '"';
        o += 1;
    }
    for (s) |c| {
        const piece: []const u8 = switch (c) {
            '"' => "\\\"",
            '\\' => "\\\\",
            '\n' => "\\n",
            '\r' => "\\r",
            '\t' => "\\t",
            else => blk: {
                if (o < buf.len) {
                    buf[o] = c;
                    o += 1;
                }
                break :blk "";
            },
        };
        for (piece) |pc| {
            if (o < buf.len) {
                buf[o] = pc;
                o += 1;
            }
        }
    }
    if (o < buf.len) {
        buf[o] = '"';
        o += 1;
    }
    return buf[0..o];
}

fn printJson(text: []const u8, src: []const u8, tgt: []const u8, tr: *const translate_mod.TranslateResult, out: []const u8) void {
    var b1: [2048]u8 = undefined;
    var b2: [2048]u8 = undefined;
    const je_in = escapeJson(text, b1[0..]);
    const je_out = escapeJson(out, b2[0..]);
    std.debug.print(
        \\{{
        \\  "input": {s},
        \\  "source_lang": "{s}",
        \\  "target_lang": "{s}",
        \\  "translation": {s},
        \\  "exact_rate": {d:.4},
        \\  "resolved": {d},
        \\  "tokens": {d},
        \\  "n_closed": {d},
        \\  "n_pack": {d},
        \\  "n_miss": {d},
        \\  "n_duality": {d},
        \\  "S": {d:.6},
        \\  "pin": "D1D38A",
        \\  "authority_ok": true
        \\}}
        \\
    , .{
        je_in,
        src,
        tgt,
        je_out,
        tr.exact_rate,
        tr.n_resolved,
        tr.n_tokens,
        tr.n_closed,
        tr.n_pack,
        tr.n_miss,
        tr.n_duality,
        tr.S,
    });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next();

    var pack_explicit: ?[]const u8 = null;
    var as_json: bool = false;
    var log_enabled: bool = true;
    var log_path_explicit: ?[]const u8 = null;
    var positional: std.ArrayListUnmanaged([]const u8) = .{};
    defer positional.deinit(allocator);

    while (args.next()) |a| {
        if (std.mem.eql(u8, a, "--help") or std.mem.eql(u8, a, "-h")) {
            printUsage();
            return;
        }
        if (std.mem.eql(u8, a, "--json")) {
            as_json = true;
            continue;
        }
        if (std.mem.eql(u8, a, "--nolog")) {
            log_enabled = false;
            continue;
        }
        if (std.mem.eql(u8, a, "--log")) {
            log_path_explicit = args.next() orelse {
                std.debug.print("--log requires path\n", .{});
                std.process.exit(2);
            };
            log_enabled = true;
            continue;
        }
        if (std.mem.eql(u8, a, "--pack")) {
            pack_explicit = args.next() orelse {
                std.debug.print("--pack requires path\n", .{});
                std.process.exit(2);
            };
            continue;
        }
        try positional.append(allocator, a);
    }

    // no args → TUI
    if (positional.items.len == 0) {
        // fall through after pack load
    } else {
        const cmd0 = positional.items[0];
        if (std.mem.eql(u8, cmd0, "version") or std.mem.eql(u8, cmd0, "--version")) {
            std.debug.print("pflt {s}\n", .{VERSION});
            return;
        }
        if (std.mem.eql(u8, cmd0, "selftest")) {
            try runSelftest();
            return;
        }
        if (std.mem.eql(u8, cmd0, "help")) {
            printUsage();
            return;
        }
    }

    var lookup = densify_pack.Lookup.init(allocator);
    defer lookup.deinit();
    var lookup_ptr: ?*const densify_pack.Lookup = null;
    var pack_rows: u32 = 0;
    const pack_path = try findPackPath(allocator, pack_explicit);
    defer if (pack_path) |p| allocator.free(p);
    if (pack_path) |p| {
        lookup.loadTsv(p) catch |err| {
            std.debug.print("warn: pack load failed ({s}): {}\n", .{ p, err });
        };
        if (lookup.n_rows > 0) {
            lookup_ptr = &lookup;
            pack_rows = lookup.n_rows;
        }
    }

    const log_path: ?[]const u8 = if (log_enabled)
        (log_path_explicit orelse decision_log.DEFAULT_PATH)
    else
        null;

    if (positional.items.len == 0) {
        var session = tui.Session.init(lookup_ptr, pack_rows);
        if (log_path_explicit) |lp| {
            if (lp.len < session.log_path.len) {
                @memcpy(session.log_path[0..lp.len], lp);
                session.log_len = lp.len;
            }
        }
        session.log_enabled = log_enabled;
        try session.run();
        return;
    }

    const cmd0 = positional.items[0];
    if (std.mem.eql(u8, cmd0, "tui") or std.mem.eql(u8, cmd0, "ui") or std.mem.eql(u8, cmd0, "repl")) {
        var session = tui.Session.init(lookup_ptr, pack_rows);
        if (log_path_explicit) |lp| {
            if (lp.len < session.log_path.len) {
                @memcpy(session.log_path[0..lp.len], lp);
                session.log_len = lp.len;
            }
        }
        session.log_enabled = log_enabled;
        try session.run();
        return;
    }

    if (std.mem.eql(u8, cmd0, "compare")) {
        if (positional.items.len < 2) {
            std.debug.print("usage: pflt compare <gold.tsv>\n", .{});
            std.process.exit(2);
        }
        try tui.runCompareFile(lookup_ptr, positional.items[1], log_path orelse decision_log.DEFAULT_PATH, log_enabled);
        return;
    }

    var idx: usize = 0;
    if (std.mem.eql(u8, cmd0, "translate")) idx = 1;

    var src: []const u8 = "de";
    var tgt: []const u8 = "en";
    var text_start: usize = idx;

    if (positional.items.len >= idx + 3) {
        const a = positional.items[idx];
        const b = positional.items[idx + 1];
        if (a.len <= 8 and b.len <= 8 and isLangish(a) and isLangish(b)) {
            src = a;
            tgt = b;
            text_start = idx + 2;
        }
    } else if (positional.items.len == idx + 1) {
        text_start = idx;
    }

    if (text_start >= positional.items.len) {
        std.debug.print("error: missing text to translate\n", .{});
        printUsage();
        std.process.exit(2);
    }

    var text_list: std.ArrayListUnmanaged(u8) = .{};
    defer text_list.deinit(allocator);
    var ti: usize = text_start;
    while (ti < positional.items.len) : (ti += 1) {
        if (ti > text_start) try text_list.append(allocator, ' ');
        try text_list.appendSlice(allocator, positional.items[ti]);
    }

    doTranslate(lookup_ptr, src, tgt, text_list.items, as_json, log_path);
}

fn isLangish(s: []const u8) bool {
    if (s.len == 0 or s.len > 8) return false;
    for (s) |c| {
        const ok = (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '-';
        if (!ok) return false;
    }
    return true;
}
