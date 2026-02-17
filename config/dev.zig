const AppConfig = @import("config").AppConfig;

/// Development defaults — localhost, debug logging, SQLite.
pub const config: AppConfig = .{
    .host = "127.0.0.1",
    .port = 9000,
    .secret_key_base = "dev-secret-not-for-production",
    .database_url = "sqlite:example.db",
    .pg_database_url = "postgres://zzz:zzz@localhost:5432/zzz_demo",
    .pool_size = 5,
    .log_level = .debug,
    .show_error_details = true,
};
