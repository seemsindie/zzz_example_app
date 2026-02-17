const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const tls_enabled = b.option(bool, "tls", "Enable TLS/HTTPS support (requires OpenSSL)") orelse false;
    const postgres_enabled = b.option(bool, "postgres", "Enable PostgreSQL support (requires libpq)") orelse false;
    const env_name = b.option([]const u8, "env", "Environment: dev (default), prod, staging") orelse "dev";

    const zzz_dep = b.dependency("zzz", .{
        .target = target,
        .tls = tls_enabled,
    });

    const zzz_db_dep = b.dependency("zzz_db", .{
        .target = target,
        .postgres = postgres_enabled,
    });

    const zzz_jobs_dep = b.dependency("zzz_jobs", .{
        .target = target,
        .postgres = postgres_enabled,
    });

    const zzz_db_mod = zzz_db_dep.module("zzz_db");
    const zzz_jobs_mod = zzz_jobs_dep.module("zzz_jobs");

    // Ensure zzz_jobs uses the same zzz_db module to avoid duplicate module errors
    zzz_jobs_mod.addImport("zzz_db", zzz_db_mod);

    // Build config path from -Denv option: config/dev.zig, config/prod.zig, etc.
    var config_path_buf: [64]u8 = undefined;
    const config_path = std.fmt.bufPrint(&config_path_buf, "config/{s}.zig", .{env_name}) catch "config/dev.zig";

    // Shared config.zig module (imported by dev.zig / prod.zig)
    const config_mod = b.createModule(.{
        .root_source_file = b.path("config/config.zig"),
        .target = target,
    });

    // Environment-specific config module
    const app_config_mod = b.createModule(.{
        .root_source_file = b.path(config_path),
        .target = target,
    });
    app_config_mod.addImport("config", config_mod);

    const exe = b.addExecutable(.{
        .name = "example_app",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zzz", .module = zzz_dep.module("zzz") },
                .{ .name = "zzz_db", .module = zzz_db_mod },
                .{ .name = "zzz_jobs", .module = zzz_jobs_mod },
                .{ .name = "app_config", .module = app_config_mod },
            },
        }),
    });

    // SQLite linking
    exe.root_module.linkSystemLibrary("sqlite3", .{});
    exe.root_module.link_libc = true;
    if (target.result.os.tag == .macos) {
        exe.root_module.addSystemIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/sqlite/include" });
        exe.root_module.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/sqlite/lib" });
    }

    // PostgreSQL linking
    if (postgres_enabled) {
        exe.root_module.linkSystemLibrary("pq", .{});
        if (target.result.os.tag == .macos) {
            exe.root_module.addSystemIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/libpq/include" });
            exe.root_module.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/libpq/lib" });
        }
    }

    if (tls_enabled) {
        exe.root_module.linkSystemLibrary("ssl", .{});
        exe.root_module.linkSystemLibrary("crypto", .{});
        if (target.result.os.tag == .macos) {
            exe.root_module.addSystemIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/openssl@3/include" });
            exe.root_module.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/openssl@3/lib" });
        }
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
