//! Stable FNV-1a token hash (same spirit as embodiment memory_fixed.hashToken).

pub fn hashToken(bytes: []const u8) u32 {
    var h: u32 = 2166136261;
    for (bytes) |c| {
        h ^= c;
        h *%= 16777619;
    }
    return if (h == 0) 1 else h;
}
