const std = @import("std");

/// Protofluid Language Translator — bare-metal Zig (FSOT law + machine tongue).
/// Location: I:\pflt\embodiment\zig  (NOT the neuron reference tree).
/// Reference patterns only: I:\fsot nuron\embodiment\zig
///
/// Product binary: pflt (translate CLI people can run and share).
pub fn build(b: *std.Build) void {
    const target_host = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // --- PRODUCT: standalone translator ---
    const pflt = b.addExecutable(.{
        .name = "pflt",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main_translate.zig"),
            .target = target_host,
            .optimize = optimize,
        }),
    });
    b.installArtifact(pflt);
    const pflt_step = b.step("pflt", "Build standalone PFLT translator (product)");
    pflt_step.dependOn(&b.addInstallArtifact(pflt, .{}).step);
    // default install includes product
    const run_pflt = b.addRunArtifact(pflt);
    if (b.args) |args| {
        run_pflt.addArgs(args);
    }
    const run_translate = b.step("translate", "Run pflt translator (pass -- args after)");
    run_translate.dependOn(&run_pflt.step);

    const host = b.addExecutable(.{
        .name = "pflt_host",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main_host.zig"),
            .target = target_host,
            .optimize = optimize,
        }),
    });
    b.installArtifact(host);
    const host_step = b.step("host", "Build PFLT host self-test (run zig-out\\bin\\pflt_host.exe manually if AV allows)");
    host_step.dependOn(&b.addInstallArtifact(host, .{}).step);
    const run_host = b.addRunArtifact(host);
    const run_step = b.step("run-host", "Run PFLT host self-test");
    run_step.dependOn(&run_host.step);

    // Freestanding Multiboot kernel for QEMU (32-bit, like reference)
    const kernel_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86,
        .os_tag = .freestanding,
        .abi = .none,
    });
    const kernel = b.addExecutable(.{
        .name = "pflt_kernel",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main_kernel.zig"),
            .target = kernel_target,
            .optimize = .ReleaseSafe,
            .code_model = .kernel,
            .red_zone = false,
        }),
    });
    kernel.entry = .{ .symbol_name = "_start" };
    kernel.setLinkerScript(b.path("linker.ld"));
    kernel.pie = false;
    kernel.link_eh_frame_hdr = false;
    b.installArtifact(kernel);

    const kernel_step = b.step("kernel", "Build freestanding PFLT QEMU kernel");
    kernel_step.dependOn(&b.addInstallArtifact(kernel, .{}).step);

    // Stress + metric dump for Python parity harness
    const stress = b.addExecutable(.{
        .name = "pflt_stress",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main_stress.zig"),
            .target = target_host,
            .optimize = optimize,
        }),
    });
    b.installArtifact(stress);
    const stress_step = b.step("stress", "Build PFLT stress/metrics host binary");
    stress_step.dependOn(&b.addInstallArtifact(stress, .{}).step);
}
