const std = @import("std");
const zzz = @import("zzz");
const zzz_db = @import("zzz_db");

const pg_enabled = zzz_db.postgres_enabled;

// ── Templates ──────────────────────────────────────────────────────────

pub const AppLayout = zzz.templateWithPartials(
    @embedFile("../templates/layout.html.zzz"),
    .{
        .nav = @embedFile("../templates/partials/nav.html.zzz"),
    },
);

const IndexContent = zzz.template(@embedFile("../templates/index.html.zzz"));
const AboutContent = zzz.template(@embedFile("../templates/about.html.zzz"));

// ── Routes ─────────────────────────────────────────────────────────────

pub const ctrl = zzz.Controller.define(.{}, &.{
    zzz.Router.get("/", index).named("home"),
    zzz.Router.get("/about", about).named("about"),
});

// ── Handlers ───────────────────────────────────────────────────────────

const RouteItem = struct { html: []const u8 };

const index_routes = [_]RouteItem{
    .{ .html = "<a href=\"/about\">About</a>" },
    .{ .html = "<a href=\"/api/status\">API Status</a>" },
    .{ .html = "<a href=\"/api/users/1\">User 1</a>" },
    .{ .html = "<a href=\"/api/users/42\">User 42</a>" },
    .{ .html = "<a href=\"/api/posts\">Posts</a>" },
    .{ .html = "<a href=\"/api/posts/hello-world\">Post: hello-world</a>" },
    .{ .html = "POST /api/echo &mdash; body parser echo (JSON, form, multipart, text)" },
    .{ .html = "POST /api/upload &mdash; file upload demo" },
    .{ .html = "<a href=\"/login\">Login</a> &mdash; session + CSRF token demo" },
    .{ .html = "<a href=\"/dashboard\">Dashboard</a> &mdash; session data demo" },
    .{ .html = "POST /api/protected &mdash; CSRF-protected endpoint" },
    .{ .html = "<a href=\"/old-page\">Old Page</a> &mdash; redirect demo (301)" },
    .{ .html = "<a href=\"/set-cookie\">Set Cookie</a> &mdash; cookie demo" },
    .{ .html = "<a href=\"/delete-cookie\">Delete Cookie</a> &mdash; cookie deletion demo" },
    .{ .html = "<a href=\"/api/limited\">Rate Limited</a> &mdash; rate limiting demo (10 req/min)" },
    .{ .html = "<a href=\"/download/build.zig\">Download build.zig</a> &mdash; sendFile demo" },
    .{ .html = "<a href=\"/error-demo\">Error Demo</a> &mdash; global error handler demo" },
    .{ .html = "GET /auth/bearer &mdash; Bearer token auth demo (requires Authorization header)" },
    .{ .html = "GET /auth/basic &mdash; Basic auth demo (curl -u user:pass)" },
    .{ .html = "GET /auth/jwt &mdash; JWT auth demo (requires valid HS256 token)" },
    .{ .html = "<a href=\"/htmx\">htmx Demo</a> &mdash; htmx counter + greeting demos" },
    .{ .html = "<a href=\"/todos\">Todo List</a> &mdash; htmx CRUD demo" },
    .{ .html = "<a href=\"/ws-demo\">WebSocket Demo</a> &mdash; WebSocket echo with zzz.js" },
    .{ .html = "<a href=\"/chat\">Channel Chat</a> &mdash; Phoenix-style channel chat with zzz.js" },
    .{ .html = "<a href=\"/db\">Database Demo</a> &mdash; SQLite CRUD with zzz_db" },
    .{ .html = "<a href=\"/jobs\">Background Jobs</a> &mdash; zzz_jobs demo" },
    .{ .html = "<a href=\"/api/docs\">API Docs</a> &mdash; Swagger UI (OpenAPI 3.1.0)" },
} ++ if (pg_enabled) [_]RouteItem{
    .{ .html = "<a href=\"/pg\">PostgreSQL Demo</a> &mdash; CRUD with PostgreSQL via zzz_db" },
} else [_]RouteItem{};

fn index(ctx: *zzz.Context) !void {
    try ctx.renderWithLayout(AppLayout, IndexContent, .ok, .{
        .title = "Zzz Example App",
        .description = "A sample app built with the Zzz web framework.",
        .show_routes = true,
        .routes = @as([]const RouteItem, &index_routes),
    });
}

fn about(ctx: *zzz.Context) !void {
    try ctx.renderWithLayout(AppLayout, AboutContent, .ok, .{
        .title = "About",
    });
}
