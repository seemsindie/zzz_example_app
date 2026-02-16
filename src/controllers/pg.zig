const std = @import("std");
const zzz = @import("zzz");
const zzz_db = @import("zzz_db");

pub const pg_enabled = zzz_db.postgres_enabled;

// Routes — empty when PostgreSQL is disabled
pub const routes: []const zzz.RouteDef = if (pg_enabled) pg_impl.routes else &[_]zzz.RouteDef{};

// Implementation — only compiled when PostgreSQL is enabled
const pg_impl = if (pg_enabled) struct {
    const db_mod = @import("db.zig");
    const home = @import("home.zig");
    const AppLayout = home.AppLayout;
    const PgDemoContent = zzz.template(@embedFile("../templates/pg_demo.html.zzz"));
    const DemoUser = db_mod.DemoUser;
    const DbUserView = db_mod.DbUserView;

    var pg_pool: zzz_db.PgPool = undefined;
    var pg_initialized: bool = false;

    fn initPgDb() !void {
        if (pg_initialized) return;
        pg_pool = try zzz_db.PgPool.init(.{
            .size = 3,
            .connection = .{ .database = "host=localhost dbname=zzz_demo user=zzz password=zzz" },
        });

        var pc = try pg_pool.checkout();
        defer pc.release();
        try pc.conn.exec(DemoUser.Meta.create_table_pg);
        pg_initialized = true;
    }

    const routes: []const zzz.RouteDef = &[_]zzz.RouteDef{
        zzz.Router.get("/pg", pgDemo),
        zzz.Router.post("/pg/add", pgAddUser),
        zzz.Router.post("/pg/delete/:id", pgDeleteUser),
    };

    fn pgDemo(ctx: *zzz.Context) !void {
        initPgDb() catch {
            ctx.text(.internal_server_error, "PostgreSQL initialization failed");
            return;
        };

        const repo = zzz_db.PgRepo.init(&pg_pool);
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

        try ctx.renderWithLayout(AppLayout, PgDemoContent, .ok, .{
            .title = "PostgreSQL Demo",
            .description = "PostgreSQL CRUD operations powered by zzz_db.",
            .has_users = view_count > 0,
            .users = @as([]const DbUserView, views[0..view_count]),
            .user_count = count_str,
            .csrf_token = csrf_token,
        });
    }

    fn pgAddUser(ctx: *zzz.Context) !void {
        initPgDb() catch {
            ctx.text(.internal_server_error, "PostgreSQL initialization failed");
            return;
        };

        const raw_name = ctx.param("name") orelse "";
        const raw_email = ctx.param("email") orelse "";
        const name = zzz.urlDecode(ctx.allocator, raw_name) catch raw_name;
        const email = zzz.urlDecode(ctx.allocator, raw_email) catch raw_email;

        if (name.len > 0 and email.len > 0) {
            const repo = zzz_db.PgRepo.init(&pg_pool);
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

        ctx.redirect("/pg", .see_other);
    }

    fn pgDeleteUser(ctx: *zzz.Context) !void {
        initPgDb() catch {
            ctx.text(.internal_server_error, "PostgreSQL initialization failed");
            return;
        };

        const id_str = ctx.param("id") orelse "0";
        const id = std.fmt.parseInt(i64, id_str, 10) catch 0;
        if (id > 0) {
            const repo = zzz_db.PgRepo.init(&pg_pool);
            repo.delete(DemoUser, .{
                .id = id,
                .name = "",
                .email = "",
            }) catch {};
        }

        ctx.redirect("/pg", .see_other);
    }
} else struct {
    const routes: []const zzz.RouteDef = &[_]zzz.RouteDef{};
};
