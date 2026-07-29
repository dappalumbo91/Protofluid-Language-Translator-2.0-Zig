//! PFLT freestanding Multiboot kernel — serial first, then tests.
//! Hang root-cause: heavy fixed i128 before FPU/soft-rt; use integer densify + milli align.
const densify = @import("densify_fixed.zig");
const mform = @import("machine_form_fixed.zig");
const pflt_ml = @import("pflt_machine_lang.zig");
const serial = @import("serial.zig");

const MULTIBOOT_MAGIC: u32 = 0x1BADB002;
const MULTIBOOT_FLAGS: u32 = 0x00000003;
const MULTIBOOT_CHECKSUM: u32 = 0 -% (MULTIBOOT_MAGIC +% MULTIBOOT_FLAGS);

export const multiboot_header align(4) linksection(".multiboot") = [_]u32{
    MULTIBOOT_MAGIC,
    MULTIBOOT_FLAGS,
    MULTIBOOT_CHECKSUM,
};

/// Larger stack: Multiboot may call with tiny bootloader stack before we switch.
var stack_bytes: [256 * 1024]u8 align(16) = undefined;

export fn _start() callconv(.c) noreturn {
    const stack_top = @intFromPtr(&stack_bytes) + stack_bytes.len;
    asm volatile (
        \\mov %[sp], %%esp
        \\mov %[sp], %%ebp
        :
        : [sp] "r" (stack_top),
        : .{ .memory = true }
    );
    kmain();
}

/// Enable x87/SSE like the reference mind kernel (safe if any soft path remains).
fn enableFpu() void {
    asm volatile (
        \\mov %%cr0, %%eax
        \\and $0xFFFFFFF3, %%eax
        \\or  $0x2, %%eax
        \\mov %%eax, %%cr0
        \\mov %%cr4, %%eax
        \\or  $0x600, %%eax
        \\mov %%eax, %%cr4
        \\fninit
        ::: .{ .eax = true, .memory = true }
    );
}

fn kmain() noreturn {
    // Serial FIRST so a hang later still shows how far we got.
    serial.init();
    serial.write("PFLT_KERNEL boot\n");

    enableFpu();
    serial.write("FPU ok\n");

    serial.write("test:densify...\n");
    const d = densify.densifySelfTest();
    if (d.ok) {
        serial.write("PFLT densify PASS hits=");
        serial.writeU32(d.hits);
        serial.write("/");
        serial.writeU32(d.n);
        serial.write("\n");
    } else {
        serial.write("PFLT densify FAIL\n");
    }

    serial.write("test:machine_form...\n");
    const a = mform.alignSelfTest();
    if (a.ok) serial.write("PFLT machine_form PASS\n") else serial.write("PFLT machine_form FAIL\n");

    serial.write("test:de_frame...\n");
    var frame: pflt_ml.MachineFrame = .{};
    densify.deTextToFrame("die regierung", &frame);
    serial.write("words=");
    serial.writeU32(@intCast(frame.n_words));
    serial.write("\n");
    if (frame.n_words >= 2) serial.write("PFLT de_frame PASS\n") else serial.write("PFLT de_frame FAIL\n");

    // Lightweight frame ABI check: pack one token
    const w = pflt_ml.tokenToWord(1);
    var f2: pflt_ml.MachineFrame = .{};
    f2.clear();
    f2.words[0] = w;
    f2.n_words = 1;
    f2.n_trits = 32;
    var raw: [pflt_ml.MAX_FRAME_BYTES]u8 = undefined;
    const nb = f2.toBytes(raw[0..]);
    if (nb >= 22) serial.write("PFLT frame_abi PASS\n") else serial.write("PFLT frame_abi FAIL\n");

    const ok = d.ok and a.ok and frame.n_words >= 2 and nb >= 22;
    if (ok) serial.write("PFLT_KERNEL PASS\n") else serial.write("PFLT_KERNEL FAIL\n");

    while (true) {
        asm volatile ("hlt");
    }
}
