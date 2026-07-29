//! Runtime densify pack loader for shippable PFLT translator.
//! Format: TSV lines `lang\tform\tsense` (comments start with #).
//! Doctrine: form → SENSE; closed-class rows in pack already override debris.

const std = @import("std");
const densify_fixed = @import("densify_fixed.zig");

pub const Lookup = struct {
    map: std.StringHashMapUnmanaged([]const u8) = .{},
    arena: std.heap.ArenaAllocator,
    n_rows: u32 = 0,

    pub fn init(backing: std.mem.Allocator) Lookup {
        return .{
            .arena = std.heap.ArenaAllocator.init(backing),
            .map = .{},
        };
    }

    pub fn deinit(self: *Lookup) void {
        // arena frees all keys/values
        self.arena.deinit();
        self.* = undefined;
    }

    fn foldInto(dst: []u8, src: []const u8) void {
        for (src, 0..) |c, i| {
            dst[i] = if (c >= 'A' and c <= 'Z') c + 32 else c;
        }
    }

    fn makeKey(allocator: std.mem.Allocator, lang: []const u8, form: []const u8) ![]u8 {
        const key = try allocator.alloc(u8, lang.len + 1 + form.len);
        @memcpy(key[0..lang.len], lang);
        key[lang.len] = 0;
        foldInto(key[lang.len + 1 ..], form);
        return key;
    }

    pub fn put(self: *Lookup, lang: []const u8, form: []const u8, sense: []const u8) !void {
        const a = self.arena.allocator();
        const key = try makeKey(a, lang, form);
        const val = try a.dupe(u8, sense);
        const gop = try self.map.getOrPut(a, key);
        if (!gop.found_existing) {
            self.n_rows += 1;
        }
        gop.value_ptr.* = val;
    }

    pub fn get(self: *const Lookup, lang: []const u8, form: []const u8) ?[]const u8 {
        var buf: [128]u8 = undefined;
        if (lang.len + 1 + form.len > buf.len) return null;
        @memcpy(buf[0..lang.len], lang);
        buf[lang.len] = 0;
        foldInto(buf[lang.len + 1 ..][0..form.len], form);
        return self.map.get(buf[0 .. lang.len + 1 + form.len]);
    }

    pub fn loadTsv(self: *Lookup, path: []const u8) !void {
        const data = try std.fs.cwd().readFileAlloc(self.arena.child_allocator, path, 64 * 1024 * 1024);
        defer self.arena.child_allocator.free(data);
        try self.loadTsvBytes(data);
    }

    pub fn loadTsvBytes(self: *Lookup, data: []const u8) !void {
        var start: usize = 0;
        var i: usize = 0;
        while (i <= data.len) : (i += 1) {
            if (i != data.len and data[i] != '\n') continue;
            var line = data[start..i];
            start = i + 1;
            if (line.len > 0 and line[line.len - 1] == '\r') line = line[0 .. line.len - 1];
            if (line.len == 0 or line[0] == '#') continue;

            var t1: ?usize = null;
            var t2: ?usize = null;
            var j: usize = 0;
            while (j < line.len) : (j += 1) {
                if (line[j] == '\t') {
                    if (t1 == null) t1 = j else if (t2 == null) {
                        t2 = j;
                        break;
                    }
                }
            }
            if (t1 == null or t2 == null) continue;
            const lang = line[0..t1.?];
            const form = line[t1.? + 1 .. t2.?];
            const sense = line[t2.? + 1 ..];
            if (lang.len == 0 or form.len == 0 or sense.len == 0) continue;
            try self.put(lang, form, sense);
        }
    }
};

/// Where the winning sense came from (for decision log / TUI).
pub const Method = enum {
    closed, // embedded DE closed-class (always wins over pack debris)
    pack, // densify_pack.tsv content
    miss, // unresolved — honest pass-through

    pub fn name(m: Method) []const u8 {
        return switch (m) {
            .closed => "closed",
            .pack => "pack",
            .miss => "miss",
        };
    }
};

pub const Trace = struct {
    sense: ?[]const u8 = null,
    method: Method = .miss,
    /// Losing candidate when closed overrides pack (yin–yang / debris conflict).
    alt_sense: ?[]const u8 = null,
    duality: bool = false,
};

/// Resolve form→sense with full decision trace.
/// DE closed-class ALWAYS wins over pack — catalog debris must not clobber.
pub fn densifyTrace(lookup: ?*const Lookup, lang: []const u8, form: []const u8) Trace {
    var t: Trace = .{};
    const pack_hit: ?[]const u8 = if (lookup) |L| L.get(lang, form) else null;

    if (std.mem.eql(u8, lang, "de")) {
        if (densify_fixed.densifyDe(form)) |closed| {
            t.sense = closed;
            t.method = .closed;
            if (pack_hit) |p| {
                if (!eqlFold(p, closed)) {
                    t.alt_sense = p;
                    t.duality = true; // pack wanted different sense (debris / dual)
                }
            }
            return t;
        }
    }
    if (pack_hit) |p| {
        t.sense = p;
        t.method = .pack;
        return t;
    }
    t.method = .miss;
    return t;
}

/// Resolve form→sense (no trace).
pub fn densify(lookup: ?*const Lookup, lang: []const u8, form: []const u8) ?[]const u8 {
    return densifyTrace(lookup, lang, form).sense;
}

fn eqlFold(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        const xa = if (ca >= 'A' and ca <= 'Z') ca + 32 else ca;
        const xb = if (cb >= 'A' and cb <= 'Z') cb + 32 else cb;
        if (xa != xb) return false;
    }
    return true;
}
