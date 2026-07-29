//! Modern terminal UI for PFLT — input / output / decision log panels.
//! ANSI + box drawing; works in Windows Terminal / modern consoles.
//! Line-oriented (portable): no raw mode required.

const std = @import("std");
const densify_pack = @import("densify_pack.zig");
const translate_mod = @import("translate.zig");
const decision_log = @import("decision_log.zig");

const VERSION = "2.0.0-zig";

// ANSI
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const DIM = "\x1b[2m";
const CYAN = "\x1b[36m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const RED = "\x1b[31m";
const MAGENTA = "\x1b[35m";
const BLUE = "\x1b[34m";
const WHITE = "\x1b[37m";
const BG_DARK = "\x1b[48;5;235m";
const FG_TITLE = "\x1b[38;5;81m";
const FG_MUTED = "\x1b[38;5;245m";
const FG_OK = "\x1b[38;5;114m";
const FG_WARN = "\x1b[38;5;215m";
const FG_ERR = "\x1b[38;5;203m";
const FG_DUAL = "\x1b[38;5;177m";

const W: usize = 76;

fn hline() void {
    var i: usize = 0;
    while (i < W) : (i += 1) std.debug.print("-", .{});
}

fn boxTop(title: []const u8) void {
    std.debug.print("{s}{s}+", .{ BOLD, FG_TITLE });
    hline();
    std.debug.print("+{s}\n", .{RESET});
    std.debug.print("{s}{s}|{s} {s}{s:<74}{s}{s}|{s}\n", .{ BOLD, FG_TITLE, RESET, BOLD, title, RESET, FG_TITLE, RESET });
    std.debug.print("{s}{s}+", .{ BOLD, FG_TITLE });
    hline();
    std.debug.print("+{s}\n", .{RESET});
}

fn boxMid() void {
    std.debug.print("{s}{s}+", .{ DIM, FG_TITLE });
    hline();
    std.debug.print("+{s}\n", .{RESET});
}

fn boxBottom() void {
    std.debug.print("{s}{s}+", .{ BOLD, FG_TITLE });
    hline();
    std.debug.print("+{s}\n", .{RESET});
}

fn boxRow(label: []const u8, color: []const u8, body: []const u8) void {
    var shown: [68]u8 = undefined;
    const n = @min(body.len, shown.len);
    if (n > 0) @memcpy(shown[0..n], body[0..n]);
    const s = shown[0..n];
    std.debug.print("{s}|{s} {s}{s:<6}{s} {s}{s:<67}{s}{s}|{s}\n", .{
        FG_TITLE,
        RESET,
        color,
        label,
        RESET,
        WHITE,
        s,
        RESET,
        FG_TITLE,
        RESET,
    });
}

fn clearScreen() void {
    std.debug.print("\x1b[2J\x1b[H", .{});
}

fn methodColor(m: densify_pack.Method) []const u8 {
    return switch (m) {
        .closed => FG_OK,
        .pack => CYAN,
        .miss => FG_ERR,
    };
}

fn paintHeader(src: []const u8, tgt: []const u8, pack_rows: u32, log_path: []const u8) void {
    boxTop("PFLT 2.0  ·  Protofluid Language Translator  ·  form→SENSE→form");
    std.debug.print("{s}|{s}  pin {s}D1D38A{s}   {s}{s}->{s}{s}   pack {s}{d}{s} rows   log {s}{s}{s}\n", .{
        FG_TITLE,
        RESET,
        YELLOW,
        RESET,
        GREEN,
        src,
        tgt,
        RESET,
        CYAN,
        pack_rows,
        RESET,
        DIM,
        log_path,
        RESET,
    });
    std.debug.print("{s}|{s}  {s}type text | Enter=translate | :help | :compare path | :ref text | :q{s}\n", .{
        FG_TITLE,
        RESET,
        FG_MUTED,
        RESET,
    });
    boxMid();
}

fn paintResult(
    input: []const u8,
    tr: *const translate_mod.TranslateResult,
    ref: ?[]const u8,
) void {
    const out = translate_mod.translationSlice(tr);
    boxRow("IN", GREEN, input);
    boxRow("OUT", CYAN, out);
    if (ref) |r| {
        boxRow("REF", YELLOW, r);
        var obuf: [32]u8 = undefined;
        const ov = translate_mod.tokenOverlap(out, r);
        const omsg = std.fmt.bufPrint(&obuf, "token_overlap={d:.2}", .{ov}) catch "overlap=?";
        boxRow("CMP", MAGENTA, omsg);
    }
    boxMid();
    std.debug.print("{s}|{s}  {s}DECISION LOG{s}  closed={s}{d}{s} pack={s}{d}{s} miss={s}{d}{s} duality={s}{d}{s}  exact={s}{d:.2}{s} S={s}{d:.5}{s}\n", .{
        FG_TITLE,
        RESET,
        BOLD,
        RESET,
        FG_OK,
        tr.n_closed,
        RESET,
        CYAN,
        tr.n_pack,
        RESET,
        FG_ERR,
        tr.n_miss,
        RESET,
        FG_DUAL,
        tr.n_duality,
        RESET,
        if (tr.exact_rate >= 0.99) FG_OK else FG_WARN,
        tr.exact_rate,
        RESET,
        YELLOW,
        tr.S,
        RESET,
    });
    std.debug.print("{s}|{s}  {s}#{s}  {s}form{s}                 {s}method{s}   {s}sense{s}                {s}alt/duality{s}\n", .{
        FG_TITLE,
        RESET,
        FG_MUTED,
        RESET,
        FG_MUTED,
        RESET,
        FG_MUTED,
        RESET,
        FG_MUTED,
        RESET,
        FG_MUTED,
        RESET,
    });

    var i: usize = 0;
    const max_show: usize = 16;
    while (i < tr.n_tokens and i < max_show) : (i += 1) {
        const tok = tr.tokens[i];
        const mc = methodColor(tok.method);
        const dual_col = if (tok.duality) FG_DUAL else FG_MUTED;
        const alt: []const u8 = if (tok.alt_len > 0) tok.alt[0..tok.alt_len] else if (tok.duality) "DUAL" else ".";
        std.debug.print("{s}|{s}  {s}{d:<2}{s} {s}{s:<20}{s} {s}{s:<8}{s} {s}{s:<20}{s} {s}{s}{s}\n", .{
            FG_TITLE,
            RESET,
            FG_MUTED,
            i + 1,
            RESET,
            WHITE,
            tok.src[0..tok.src_len],
            RESET,
            mc,
            tok.method.name(),
            RESET,
            if (tok.resolved) FG_OK else FG_ERR,
            tok.sense[0..tok.sense_len],
            RESET,
            dual_col,
            alt,
            RESET,
        });
    }
    if (tr.n_tokens > max_show) {
        std.debug.print("{s}|{s}  {s}... {d} more tokens (see decision log file){s}\n", .{ FG_TITLE, RESET, FG_MUTED, tr.n_tokens - max_show, RESET });
    }
    if (tr.n_duality > 0) {
        std.debug.print("{s}|{s}  {s}!! yin-yang: closed overrode pack on {d} form(s) - pack sense was debris or dual{s}\n", .{
            FG_TITLE,
            RESET,
            FG_DUAL,
            tr.n_duality,
            RESET,
        });
    }
    if (tr.n_miss > 0) {
        std.debug.print("{s}|{s}  {s}!! miss: {d} form(s) have no densify bind - competitive gap{s}\n", .{
            FG_TITLE,
            RESET,
            FG_ERR,
            tr.n_miss,
            RESET,
        });
    }
    boxBottom();
}

fn printHelp() void {
    std.debug.print(
        \\
        \\  {s}Commands{s}
        \\    <text>              translate (current src→tgt)
        \\    :src de             set source language
        \\    :tgt en             set target language
        \\    :ref <text>         set reference translation (for live compare)
        \\    :ref                clear reference
        \\    :compare <file>     run gold pairs file (src\\ttgt\\tsource\\treference)
        \\    :log [path]         show / set decision log path
        \\    :nolog              disable session logging
        \\    :clear              clear screen / redraw chrome
        \\    :help               this help
        \\    :q                  quit
        \\
        \\  {s}Decision methods{s}
        \\    {s}closed{s}  DE closed-class (wins over pack debris)
        \\    {s}pack{s}    densify_pack.tsv content bind
        \\    {s}miss{s}    unresolved — honest pass-through
        \\    {s}duality{s} closed ≠ pack — yin–yang / wrong densify signal
        \\
    , .{ BOLD, RESET, BOLD, RESET, FG_OK, RESET, CYAN, RESET, FG_ERR, RESET, FG_DUAL, RESET });
}

pub const Session = struct {
    lookup: ?*const densify_pack.Lookup,
    pack_rows: u32,
    src: [16]u8 = undefined,
    src_len: usize = 2,
    tgt: [16]u8 = undefined,
    tgt_len: usize = 2,
    log_path: [256]u8 = undefined,
    log_len: usize = 0,
    log_enabled: bool = true,
    ref_buf: [2048]u8 = undefined,
    ref_len: usize = 0,
    has_ref: bool = false,

    pub fn init(lookup: ?*const densify_pack.Lookup, pack_rows: u32) Session {
        var s: Session = .{
            .lookup = lookup,
            .pack_rows = pack_rows,
        };
        @memcpy(s.src[0..2], "de");
        s.src_len = 2;
        @memcpy(s.tgt[0..2], "en");
        s.tgt_len = 2;
        const def = decision_log.DEFAULT_PATH;
        @memcpy(s.log_path[0..def.len], def);
        s.log_len = def.len;
        return s;
    }

    fn srcSlice(self: *const Session) []const u8 {
        return self.src[0..self.src_len];
    }
    fn tgtSlice(self: *const Session) []const u8 {
        return self.tgt[0..self.tgt_len];
    }
    fn logSlice(self: *const Session) []const u8 {
        return self.log_path[0..self.log_len];
    }
    fn refSlice(self: *const Session) ?[]const u8 {
        if (!self.has_ref) return null;
        return self.ref_buf[0..self.ref_len];
    }

    pub fn run(self: *Session) !void {
        clearScreen();
        paintHeader(self.srcSlice(), self.tgtSlice(), self.pack_rows, self.logSlice());
        std.debug.print("{s}  Ready. Type German (or source) text and press Enter.{s}\n\n", .{ FG_MUTED, RESET });

        var in_buf: [4096]u8 = undefined;
        var stdin_reader = std.fs.File.stdin().readerStreaming(&in_buf);

        while (true) {
            std.debug.print("{s}{s} pflt▸ {s}", .{ BOLD, FG_TITLE, RESET });
            const line = stdin_reader.interface.takeDelimiterExclusive('\n') catch break;
            const text = std.mem.trim(u8, line, " \t\r\n");
            if (text.len == 0) continue;

            if (std.mem.eql(u8, text, ":q") or std.mem.eql(u8, text, ":quit") or std.mem.eql(u8, text, ":exit")) {
                std.debug.print("{s}bye{s}\n", .{ DIM, RESET });
                break;
            }
            if (std.mem.eql(u8, text, ":help") or std.mem.eql(u8, text, ":h") or std.mem.eql(u8, text, "?")) {
                printHelp();
                continue;
            }
            if (std.mem.eql(u8, text, ":clear") or std.mem.eql(u8, text, ":c")) {
                clearScreen();
                paintHeader(self.srcSlice(), self.tgtSlice(), self.pack_rows, self.logSlice());
                continue;
            }
            if (std.mem.eql(u8, text, ":nolog")) {
                self.log_enabled = false;
                std.debug.print("  logging off\n", .{});
                continue;
            }
            if (std.mem.startsWith(u8, text, ":log")) {
                const rest = std.mem.trim(u8, text[4..], " \t");
                if (rest.len == 0) {
                    std.debug.print("  log={s} enabled={}\n", .{ self.logSlice(), self.log_enabled });
                } else if (rest.len < self.log_path.len) {
                    @memcpy(self.log_path[0..rest.len], rest);
                    self.log_len = rest.len;
                    self.log_enabled = true;
                    std.debug.print("  log → {s}\n", .{self.logSlice()});
                }
                continue;
            }
            if (std.mem.startsWith(u8, text, ":src ")) {
                const v = std.mem.trim(u8, text[5..], " \t");
                if (v.len > 0 and v.len < self.src.len) {
                    @memcpy(self.src[0..v.len], v);
                    self.src_len = v.len;
                    std.debug.print("  src={s}\n", .{self.srcSlice()});
                }
                continue;
            }
            if (std.mem.startsWith(u8, text, ":tgt ")) {
                const v = std.mem.trim(u8, text[5..], " \t");
                if (v.len > 0 and v.len < self.tgt.len) {
                    @memcpy(self.tgt[0..v.len], v);
                    self.tgt_len = v.len;
                    std.debug.print("  tgt={s}\n", .{self.tgtSlice()});
                }
                continue;
            }
            if (std.mem.eql(u8, text, ":ref")) {
                self.has_ref = false;
                self.ref_len = 0;
                std.debug.print("  reference cleared\n", .{});
                continue;
            }
            if (std.mem.startsWith(u8, text, ":ref ")) {
                const v = std.mem.trim(u8, text[5..], " \t");
                if (v.len > 0 and v.len < self.ref_buf.len) {
                    @memcpy(self.ref_buf[0..v.len], v);
                    self.ref_len = v.len;
                    self.has_ref = true;
                    std.debug.print("  reference set\n", .{});
                }
                continue;
            }
            if (std.mem.startsWith(u8, text, ":compare ")) {
                const path = std.mem.trim(u8, text[9..], " \t");
                try runCompareFile(self.lookup, path, self.logSlice(), self.log_enabled);
                continue;
            }

            // translate
            var tr: translate_mod.TranslateResult = .{};
            translate_mod.translate(self.lookup, self.srcSlice(), self.tgtSlice(), text, &tr);
            paintResult(text, &tr, self.refSlice());

            if (self.log_enabled) {
                decision_log.appendEvent(
                    self.logSlice(),
                    self.srcSlice(),
                    self.tgtSlice(),
                    text,
                    &tr,
                    self.refSlice(),
                    "tui",
                ) catch |err| {
                    std.debug.print("  {s}log write failed: {}{s}\n", .{ FG_ERR, err, RESET });
                };
            }
        }
    }
};

/// Gold file: optional header; rows `src_lang\ttgt_lang\tsource\treference`
pub fn runCompareFile(
    lookup: ?*const densify_pack.Lookup,
    path: []const u8,
    log_path: []const u8,
    log_enabled: bool,
) !void {
    const data = std.fs.cwd().readFileAlloc(std.heap.page_allocator, path, 8 * 1024 * 1024) catch |err| {
        std.debug.print("  {s}compare open failed: {}{s}\n", .{ FG_ERR, err, RESET });
        return;
    };
    defer std.heap.page_allocator.free(data);

    std.debug.print("\n{s}{s}=== COMPARATIVE EVAL  {s} ==={s}\n", .{ BOLD, FG_TITLE, path, RESET });
    var n: usize = 0;
    var sum_ov: f64 = 0;
    var sum_exact: f64 = 0;
    var dual_total: usize = 0;
    var miss_total: usize = 0;

    var start: usize = 0;
    var i: usize = 0;
    while (i <= data.len) : (i += 1) {
        if (i != data.len and data[i] != '\n') continue;
        var line = data[start..i];
        start = i + 1;
        if (line.len > 0 and line[line.len - 1] == '\r') line = line[0 .. line.len - 1];
        if (line.len == 0 or line[0] == '#') continue;

        // split tabs into 4 fields
        var fields: [4][]const u8 = .{ "", "", "", "" };
        var fi: usize = 0;
        var p0: usize = 0;
        var j: usize = 0;
        while (j <= line.len and fi < 4) : (j += 1) {
            if (j == line.len or line[j] == '\t') {
                fields[fi] = line[p0..j];
                fi += 1;
                p0 = j + 1;
            }
        }
        if (fi < 4) continue;
        const src = fields[0];
        const tgt = fields[1];
        const source = fields[2];
        const reference = fields[3];
        if (source.len == 0) continue;

        var tr: translate_mod.TranslateResult = .{};
        translate_mod.translate(lookup, src, tgt, source, &tr);
        const out = translate_mod.translationSlice(&tr);
        const ov = translate_mod.tokenOverlap(out, reference);
        n += 1;
        sum_ov += ov;
        sum_exact += tr.exact_rate;
        dual_total += tr.n_duality;
        miss_total += tr.n_miss;

        const mark: []const u8 = if (ov >= 0.8) FG_OK else if (ov >= 0.4) FG_WARN else FG_ERR;
        std.debug.print("  {s}#{d}{s} ov={s}{d:.2}{s} exact={d:.2} dual={d} miss={d}\n", .{
            FG_MUTED,
            n,
            RESET,
            mark,
            ov,
            RESET,
            tr.exact_rate,
            tr.n_duality,
            tr.n_miss,
        });
        std.debug.print("     IN  {s}\n     OUT {s}\n     REF {s}\n", .{ source, out, reference });
        if (tr.n_duality > 0 or tr.n_miss > 0 or ov < 0.8) {
            decision_log.printDecisionTable(&tr);
        }

        if (log_enabled) {
            decision_log.appendEvent(log_path, src, tgt, source, &tr, reference, "compare") catch {};
        }
    }

    if (n == 0) {
        std.debug.print("  no pairs in {s}\n", .{path});
        return;
    }
    const avg_ov = sum_ov / @as(f64, @floatFromInt(n));
    const avg_ex = sum_exact / @as(f64, @floatFromInt(n));
    std.debug.print("\n{s}SUMMARY{s} n={d}  mean_overlap={s}{d:.3}{s}  mean_exact={d:.3}  duality_tokens={d}  miss_tokens={d}\n", .{
        BOLD,
        RESET,
        n,
        if (avg_ov >= 0.7) FG_OK else FG_WARN,
        avg_ov,
        RESET,
        avg_ex,
        dual_total,
        miss_total,
    });
    std.debug.print("{s}Competitive note:{s} raise mean_overlap via densify pack binds; kill duality via closed-class / pack hygiene.\n\n", .{ FG_MUTED, RESET });
}
