const std = @import("std");
const zzz = @import("zzz");
const zzz_db = @import("zzz_db");
const home = @import("home.zig");

const AppLayout = home.AppLayout;

// ── Templates ──────────────────────────────────────────────────────────

const DbDemoContent = zzz.template(@embedFile("../templates/db_demo.html.zzz"));

// ── Schema ─────────────────────────────────────────────────────────────

pub const DemoUser = struct {
    id: i64,
    name: []const u8,
    email: []const u8,
    inserted_at: i64 = 0,
    updated_at: i64 = 0,

    pub const Meta = zzz_db.Schema.define(@This(), .{
        .table = "demo_users",
        .primary_key = "id",
        .timestamps = true,
    });
};

pub const DbUserView = struct { id: []const u8, name: []const u8, email: []const u8, csrf_token: []const u8 };

// ── State ──────────────────────────────────────────────────────────────

var db_pool: zzz_db.SqlitePool = undefined;
var db_initialized: bool = false;

fn initDb() !void {
    if (db_initialized) return;
    db_pool = try zzz_db.SqlitePool.init(.{
        .size = 3,
        .connection = .{ .database = "example.db" },
    });

    var pc = try db_pool.checkout();
    defer pc.release();
    try pc.conn.exec(DemoUser.Meta.create_table);
    db_initialized = true;
}

// ── Routes ─────────────────────────────────────────────────────────────

pub const ctrl = zzz.Controller.define(.{ .prefix = "/db" }, &.{
    zzz.Router.get("", dbDemo),
    zzz.Router.post("/add", dbAddUser),
    zzz.Router.post("/delete/:id", dbDeleteUser),
});

// ── Handlers ───────────────────────────────────────────────────────────

fn dbDemo(ctx: *zzz.Context) !void {
    initDb() catch {
        ctx.text(.internal_server_error, "Database initialization failed");
        return;
    };

    const repo = zzz_db.SqliteRepo.init(&db_pool);
    const q = zzz_db.Query(DemoUser).init().orderBy("id", .desc);
    const users = repo.all(DemoUser, q, ctx.allocator) catch {
        ctx.text(.internal_server_error, "Failed to load users");
        return;
    };
    defer zzz_db.freeAll(DemoUser, users, ctx.allocator);

    const csrf_token = ctx.getAssign("csrf_token") orelse "";

    var views: [64]DbUserView = undefined;
    var id_bufs: [64][16]u8 = undefined;
    const view_count = @min(users.len, 64);
    for (0..view_count) |i| {
        const id_str = std.fmt.bufPrint(&id_bufs[i], "{d}", .{users[i].id}) catch "0";
        views[i] = .{ .id = id_str, .name = users[i].name, .email = users[i].email, .csrf_token = csrf_token };
    }

    var count_buf: [16]u8 = undefined;
    const count_str = std.fmt.bufPrint(&count_buf, "{d}", .{view_count}) catch "0";

    try ctx.renderWithLayout(AppLayout, DbDemoContent, .ok, .{
        .title = "Database Demo",
        .description = "SQLite CRUD operations powered by zzz_db.",
        .has_users = view_count > 0,
        .users = @as([]const DbUserView, views[0..view_count]),
        .user_count = count_str,
        .csrf_token = csrf_token,
    });
}

fn dbAddUser(ctx: *zzz.Context) !void {
    initDb() catch {
        ctx.text(.internal_server_error, "Database initialization failed");
        return;
    };

    const raw_name = ctx.param("name") orelse "";
    const raw_email = ctx.param("email") orelse "";
    const name = zzz.urlDecode(ctx.allocator, raw_name) catch raw_name;
    const email = zzz.urlDecode(ctx.allocator, raw_email) catch raw_email;

    if (name.len > 0 and email.len > 0) {
        const repo = zzz_db.SqliteRepo.init(&db_pool);
        var inserted = repo.insert(DemoUser, .{
            .id = 0,
            .name = name,
            .email = email,
        }, ctx.allocator) catch {
            ctx.text(.internal_server_error, "Failed to insert user");
            return;
        };
        zzz_db.freeOne(DemoUser, &inserted, ctx.allocator);
    }

    ctx.redirect("/db", .see_other);
}

fn dbDeleteUser(ctx: *zzz.Context) !void {
    initDb() catch {
        ctx.text(.internal_server_error, "Database initialization failed");
        return;
    };

    const id_str = ctx.param("id") orelse "0";
    const id = std.fmt.parseInt(i64, id_str, 10) catch 0;
    if (id > 0) {
        const repo = zzz_db.SqliteRepo.init(&db_pool);
        repo.delete(DemoUser, .{
            .id = id,
            .name = "",
            .email = "",
        }) catch {};
    }

    ctx.redirect("/db", .see_other);
}
