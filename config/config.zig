/// Shared application config struct — the single source of truth for all settings.
/// Comptime defaults come from dev.zig / prod.zig (selected by `-Denv`).
/// Runtime overrides come from `.env` + system env via `zzz.mergeWithEnv`.
pub const AppConfig = struct {
    host: []const u8 = "127.0.0.1",
    port: u16 = 9000,
    secret_key_base: []const u8 = "change-me-in-production",
    database_url: []const u8 = "sqlite:example.db",
    pg_database_url: []const u8 = "postgres://zzz:zzz@localhost:5432/zzz_demo",
    pool_size: u16 = 5,
    log_level: LogLevel = .debug,
    show_error_details: bool = true,
};

pub const LogLevel = enum {
    debug,
    info,
    warn,
    err,
};
