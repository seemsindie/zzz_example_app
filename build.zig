const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zzz_dep = b.dependency("zzz", .{
        .target = target,
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

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the example app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
