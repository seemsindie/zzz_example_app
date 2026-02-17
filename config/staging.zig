const AppConfig = @import("config").AppConfig;

/// Staging defaults — production-like but with more verbose logging.
pub const config: AppConfig = .{
    .host = "0.0.0.0",
    .port = 8080,
    .secret_key_base = "MUST-BE-SET-VIA-ENV",
    .database_url = "sqlite:example.db",
    .pg_database_url = "postgres://zzz:zzz@localhost:5432/zzz_staging",
    .pool_size = 5,
    .log_level = .info,
    .show_error_details = true,
};
