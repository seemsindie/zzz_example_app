const AppConfig = @import("config").AppConfig;

/// Production defaults — bind all interfaces, info logging, larger pool.
pub const config: AppConfig = .{
    .host = "0.0.0.0",
    .port = 8080,
    .secret_key_base = "MUST-BE-SET-VIA-ENV",
    .database_url = "sqlite:example.db",
    .pg_database_url = "postgres://zzz:zzz@localhost:5432/zzz_prod",
    .pool_size = 10,
    .log_level = .info,
    .show_error_details = false,
};
