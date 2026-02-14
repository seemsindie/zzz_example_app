const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const tls_enabled = b.option(bool, "tls", "Enable TLS/HTTPS support (requires OpenSSL)") orelse false;

    const zzz_dep = b.dependency("zzz", .{
        .target = target,
        .tls = tls_enabled,
    });

    const exe = b.addExecutable(.{
        .name = "example_app",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zzz", .module = zzz_dep.module("zzz") },
            },
        }),
    });

    if (tls_enabled) {
        exe.root_module.addSystemIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/openssl@3/include" });
        exe.root_module.linkSystemLibrary("ssl", .{});
        exe.root_module.linkSystemLibrary("crypto", .{});
        exe.root_module.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/openssl@3/lib" });
        exe.root_module.link_libc = true;
    }

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the example app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
