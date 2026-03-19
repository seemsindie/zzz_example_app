const std = @import("std");
const zzz = @import("zzz");
const app_config = @import("app_config");

// ── Controllers ───────────────────────────────────────────────────────

const home = @import("controllers/home.zig");
const api = @import("controllers/api.zig");
const auth = @import("controllers/auth.zig");
const sessions = @import("controllers/sessions.zig");
const htmx_ctrl = @import("controllers/htmx.zig");
const db_ctrl = @import("controllers/db.zig");
const pg_ctrl = @import("controllers/pg.zig");
const jobs_ctrl = @import("controllers/jobs.zig");
const mail_ctrl = @import("controllers/mail.zig");
const ws_ctrl = @import("controllers/ws.zig");
const misc = @import("controllers/misc.zig");
const sse_ctrl = @import("controllers/sse_ctrl.zig");
const cache_ctrl = @import("controllers/cache_ctrl.zig");
const ssr_ctrl = @import("controllers/ssr_ctrl.zig");

// ── Middleware ─────────────────────────────────────────────────────────

fn requestId(ctx: *zzz.Context) !void {
    ctx.assign("request_id", "zzz-0001");
    try ctx.next();
}

// ── Routes ────────────────────────────────────────────────────────────

const routes = api.posts_resource
    ++ home.ctrl.routes
    ++ sessions.ctrl.routes
    ++ ws_ctrl.ctrl.routes
    ++ htmx_ctrl.ctrl.routes
    ++ db_ctrl.ctrl.routes
    ++ jobs_ctrl.ctrl.routes
    ++ mail_ctrl.ctrl.routes
    ++ pg_ctrl.routes
    ++ api.ctrl.routes
    ++ zzz.Router.scope("/api", &.{zzz.rateLimit(.{ .max_requests = 10, .window_seconds = 60 })}, &.{
        zzz.Router.get("/limited", misc.rateLimitedHandler).doc(.{
            .summary = "Rate-limited endpoint",
            .description = "Demonstrates rate limiting (10 requests/minute).",
            .tag = "System",
        }),
    })
    ++ zzz.Router.scope("/auth", &.{zzz.bearerAuth(.{ .required = true })}, &.{
        zzz.Router.get("/bearer", auth.bearerDemo),
    })
    ++ zzz.Router.scope("/auth", &.{zzz.basicAuth(.{ .required = true })}, &.{
        zzz.Router.get("/basic", auth.basicDemo),
    })
    ++ zzz.Router.scope("/auth", &.{zzz.jwtAuth(.{ .secret = "zzz-demo-secret", .required = true })}, &.{
        zzz.Router.get("/jwt", auth.jwtDemo),
    })
    ++ misc.ctrl.routes
    ++ sse_ctrl.ctrl.routes
    ++ cache_ctrl.ctrl.routes
    ++ ssr_ctrl.ctrl.routes
    ++ zzz.Router.scope("/api/cached", &.{zzz.cacheMiddleware(.{
        .cacheable_prefixes = &.{"/api/cached"},
        .default_ttl_s = 10,
    })}, &.{
        zzz.Router.get("/time", cache_ctrl.cachedTime),
    })
    ++ zzz.Router.scope("/__zzz/mailbox", &.{}, &.{
        zzz.Router.get("", mail_ctrl.mailboxInbox),
        zzz.Router.get("/:index", mail_ctrl.mailboxDetail),
        zzz.Router.get("/:index/html", mail_ctrl.mailboxHtml),
        zzz.Router.post("/clear", mail_ctrl.mailboxClear),
    });

// ── Swagger ───────────────────────────────────────────────────────────

const api_spec = zzz.swagger.generateSpec(.{
    .title = "Example App API",
    .version = "0.1.0",
    .description = "Demo API built with zzz",
}, routes);

// ── App ───────────────────────────────────────────────────────────────

const App = zzz.Router.define(.{
    .middleware = &.{
        zzz.errorHandler(.{ .show_details = true }),
        zzz.logger,
        zzz.gzipCompress(.{}),
        requestId,
        zzz.cors(.{}),
        zzz.htmx(.{ .htmx_cdn_version = "2.0.4" }),
        zzz.bodyParser,
        zzz.session(.{}),
        zzz.csrf(.{}),
        zzz.staticFiles(.{ .dir = "public", .prefix = "/static" }),
        zzz.zzzJs(.{}),
        zzz.swagger.ui(.{ .spec_json = api_spec }),
    },
    .routes = routes,
});

// ── Main ──────────────────────────────────────────────────────────────

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var env = try zzz.Env.init(allocator, .{});
    defer env.deinit();

    // Merge comptime config (from -Denv=dev/prod) with runtime .env overrides
    const config = zzz.mergeWithEnv(@TypeOf(app_config.config), app_config.config, &env);

    // Wire env into controllers that need it
    db_ctrl.env = &env;
    pg_ctrl.setEnv(&env);

    var server = zzz.Server.init(allocator, .{
        .host = config.host,
        .port = config.port,
        .drain_timeout_ms = 15_000, // 15s graceful shutdown
    }, App.handler);

    try server.listen(io);
}
