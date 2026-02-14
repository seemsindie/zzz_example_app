const std = @import("std");
const zzz = @import("zzz");

// ── Middleware ──────────────────────────────────────────────────────────

fn requestId(ctx: *zzz.Context) !void {
    ctx.assign("request_id", "zzz-0001");
    try ctx.next();
}

// ── Handlers ───────────────────────────────────────────────────────────

fn index(ctx: *zzz.Context) !void {
    ctx.html(.ok,
        \\<!DOCTYPE html>
        \\<html>
        \\<head>
        \\  <title>Zzz Example App</title>
        \\  <link rel="stylesheet" href="/static/css/style.css">
        \\</head>
        \\<body>
        \\  <h1>Zzz Example App</h1>
        \\  <p>A sample app built with the Zzz web framework.</p>
        \\  <h2>Routes</h2>
        \\  <ul>
        \\    <li><a href="/about">About</a></li>
        \\    <li><a href="/api/status">API Status</a></li>
        \\    <li><a href="/api/users/1">User 1</a></li>
        \\    <li><a href="/api/users/42">User 42</a></li>
        \\    <li><a href="/api/posts">Posts</a></li>
        \\    <li><a href="/api/posts/hello-world">Post: hello-world</a></li>
        \\    <li>POST /api/echo — body parser echo (JSON, form, multipart, text)</li>
        \\    <li>POST /api/upload — file upload demo</li>
        \\    <li><a href="/login">Login</a> — session + CSRF token demo</li>
        \\    <li><a href="/dashboard">Dashboard</a> — session data demo</li>
        \\    <li>POST /api/protected — CSRF-protected endpoint</li>
        \\    <li><a href="/old-page">Old Page</a> — redirect demo (301)</li>
        \\    <li><a href="/set-cookie">Set Cookie</a> — cookie demo</li>
        \\    <li><a href="/delete-cookie">Delete Cookie</a> — cookie deletion demo</li>
        \\    <li><a href="/api/limited">Rate Limited</a> — rate limiting demo (10 req/min)</li>
        \\    <li><a href="/download/build.zig">Download build.zig</a> — sendFile demo</li>
        \\    <li><a href="/error-demo">Error Demo</a> — global error handler demo</li>
        \\    <li>GET /auth/bearer — Bearer token auth demo (requires Authorization header)</li>
        \\    <li>GET /auth/basic — Basic auth demo (curl -u user:pass)</li>
        \\    <li>GET /auth/jwt — JWT auth demo (requires valid HS256 token)</li>
        \\  </ul>
        \\  <script src="/static/js/app.js"></script>
        \\</body>
        \\</html>
    );
}

fn about(ctx: *zzz.Context) !void {
    ctx.html(.ok,
        \\<!DOCTYPE html>
        \\<html>
        \\<head>
        \\  <title>About - Zzz</title>
        \\  <link rel="stylesheet" href="/static/css/style.css">
        \\</head>
        \\<body>
        \\  <h1>About Zzz</h1>
        \\  <p>Zzz is a Phoenix-inspired web framework written in Zig.</p>
        \\  <p>Blazing fast. Memory safe. Compile-time route resolution.</p>
        \\  <p><a href="/">Back to home</a></p>
        \\  <script src="/static/js/app.js"></script>
        \\</body>
        \\</html>
    );
}

fn apiStatus(ctx: *zzz.Context) !void {
    ctx.json(.ok,
        \\{"status": "ok", "framework": "zzz", "version": "0.1.0"}
    );
}

fn listUsers(ctx: *zzz.Context) !void {
    ctx.json(.ok,
        \\{"users": [{"id": 1, "name": "Alice"}, {"id": 2, "name": "Bob"}, {"id": 3, "name": "Charlie"}]}
    );
}

fn getUser(ctx: *zzz.Context) !void {
    const id = ctx.param("id") orelse "0";
    _ = id;
    // In a real app, you'd look up the user by ID.
    // For now, return a static response.
    ctx.json(.ok,
        \\{"id": 1, "name": "Alice", "email": "alice@example.com"}
    );
}

fn createUser(ctx: *zzz.Context) !void {
    // Unified param() — works with JSON body, form POST, or query string
    const name = ctx.param("name") orelse "anonymous";
    const email = ctx.param("email") orelse "not provided";

    var buf: [512]u8 = undefined;
    const body = std.fmt.bufPrint(&buf,
        \\{{"id":4,"name":"{s}","email":"{s}","created":true}}
    , .{ name, email }) catch
        \\{"error":"response too large"}
    ;
    ctx.json(.created, body);
}

/// Echo endpoint — demonstrates all body parser features.
///
/// Try these:
///   curl -X POST -H "Content-Type: application/json" -d '{"name":"zig","lang":"systems"}' http://127.0.0.1:5000/api/echo
///   curl -X POST -d "name=zig&lang=systems" http://127.0.0.1:5000/api/echo
///   curl -X POST -F "name=zig" -F "file=@somefile.txt" http://127.0.0.1:5000/api/echo
///   curl -X POST -H "Content-Type: text/plain" -d "hello world" http://127.0.0.1:5000/api/echo
fn echoBody(ctx: *zzz.Context) !void {
    const content_type = ctx.request.contentType() orelse "none";
    const name = ctx.param("name") orelse "anonymous";

    var buf: [2048]u8 = undefined;

    const body = switch (ctx.parsed_body) {
        .json => |fd| blk: {
            const lang = fd.get("lang") orelse "unknown";
            const raw = ctx.jsonBody() orelse "null";
            break :blk std.fmt.bufPrint(&buf,
                \\{{"type":"json","name":"{s}","lang":"{s}","raw_length":{d},"content_type":"{s}"}}
            , .{ name, lang, raw.len, content_type }) catch
                \\{"error":"response too large"}
            ;
        },
        .form => |fd| blk: {
            const lang = fd.get("lang") orelse "unknown";
            break :blk std.fmt.bufPrint(&buf,
                \\{{"type":"form","name":"{s}","lang":"{s}","field_count":{d},"content_type":"{s}"}}
            , .{ name, lang, fd.count(), content_type }) catch
                \\{"error":"response too large"}
            ;
        },
        .multipart => |md| blk: {
            const file_count = md.file_count;
            const has_file = if (ctx.file("file") != null) "true" else "false";
            break :blk std.fmt.bufPrint(&buf,
                \\{{"type":"multipart","name":"{s}","field_count":{d},"file_count":{d},"has_file_field":{s},"content_type":"{s}"}}
            , .{ name, md.fields.count(), file_count, has_file, content_type }) catch
                \\{"error":"response too large"}
            ;
        },
        .text => |text_body| blk: {
            const len = text_body.len;
            break :blk std.fmt.bufPrint(&buf,
                \\{{"type":"text","body_length":{d},"content_type":"{s}"}}
            , .{ len, content_type }) catch
                \\{"error":"response too large"}
            ;
        },
        .binary => |bin| blk: {
            break :blk std.fmt.bufPrint(&buf,
                \\{{"type":"binary","body_length":{d},"content_type":"{s}"}}
            , .{ bin.len, content_type }) catch
                \\{"error":"response too large"}
            ;
        },
        .none => blk: {
            break :blk std.fmt.bufPrint(&buf,
                \\{{"type":"none","content_type":"{s}"}}
            , .{content_type}) catch
                \\{"error":"response too large"}
            ;
        },
    };

    ctx.json(.ok, body);
}

/// Demonstrates formValue() and file() for multipart uploads.
///
/// Try: curl -X POST -F "description=My photo" -F "avatar=@photo.jpg" http://127.0.0.1:5000/api/upload
fn uploadHandler(ctx: *zzz.Context) !void {
    const description = ctx.formValue("description") orelse "no description";

    var buf: [512]u8 = undefined;

    if (ctx.file("avatar")) |f| {
        const body = std.fmt.bufPrint(&buf,
            \\{{"description":"{s}","filename":"{s}","content_type":"{s}","size":{d}}}
        , .{ description, f.filename, f.content_type, f.data.len }) catch
            \\{"error":"response too large"}
        ;
        ctx.json(.ok, body);
    } else {
        ctx.json(.bad_request,
            \\{"error":"missing avatar file field"}
        );
    }
}

// ── Session / Cookie / Redirect demos ─────────────────────────────────

/// Shows a login page with a CSRF token. Sets a session cookie.
///
/// Try: curl -v http://127.0.0.1:5000/login
fn loginPage(ctx: *zzz.Context) !void {
    const csrf_token = ctx.getAssign("csrf_token") orelse "no-token";
    const session_id = ctx.getAssign("session_id") orelse "no-session";

    var buf: [1024]u8 = undefined;
    const body = std.fmt.bufPrint(&buf,
        \\{{"page":"login","session_id":"{s}","csrf_token":"{s}"}}
    , .{ session_id, csrf_token }) catch
        \\{{"error":"response too large"}}
    ;
    ctx.json(.ok, body);
}

/// Dashboard — shows session data. Requires a session cookie.
///
/// Try: curl -v -b "zzz_session=<id>" http://127.0.0.1:5000/dashboard
fn dashboard(ctx: *zzz.Context) !void {
    const session_id = ctx.getAssign("session_id") orelse "no-session";
    const user = ctx.getAssign("user_name") orelse "guest";

    var buf: [512]u8 = undefined;
    const body = std.fmt.bufPrint(&buf,
        \\{{"page":"dashboard","session_id":"{s}","user":"{s}"}}
    , .{ session_id, user }) catch
        \\{{"error":"response too large"}}
    ;
    ctx.json(.ok, body);
}

/// Protected endpoint — requires valid CSRF token.
///
/// Try: curl -X POST -d "_csrf_token=<token>" -b "zzz_session=<id>" http://127.0.0.1:5000/api/protected
fn protectedAction(ctx: *zzz.Context) !void {
    ctx.assign("user_name", "alice");
    ctx.json(.ok,
        \\{"result":"success","message":"CSRF validation passed"}
    );
}

/// Redirect demo.
///
/// Try: curl -v http://127.0.0.1:5000/old-page
fn oldPage(ctx: *zzz.Context) !void {
    ctx.redirect("/about", .moved_permanently);
}

/// Cookie demo — sets a custom cookie and returns it.
///
/// Try: curl -v http://127.0.0.1:5000/set-cookie
fn setCookieDemo(ctx: *zzz.Context) !void {
    ctx.setCookie("theme", "dark", .{ .path = "/", .max_age = 86400 });
    ctx.json(.ok,
        \\{"message":"theme cookie set to dark"}
    );
}

/// Cookie demo — reads and deletes a cookie.
///
/// Try: curl -v -b "theme=dark" http://127.0.0.1:5000/delete-cookie
fn deleteCookieDemo(ctx: *zzz.Context) !void {
    const theme = ctx.getCookie("theme") orelse "not set";
    ctx.deleteCookie("theme", "/");

    var buf: [256]u8 = undefined;
    const body = std.fmt.bufPrint(&buf,
        \\{{"message":"deleted theme cookie","was":"{s}"}}
    , .{theme}) catch
        \\{{"error":"response too large"}}
    ;
    ctx.json(.ok, body);
}

fn listPosts(ctx: *zzz.Context) !void {
    ctx.json(.ok,
        \\{"posts": [{"slug": "hello-world", "title": "Hello World"}, {"slug": "zig-is-great", "title": "Zig Is Great"}]}
    );
}

fn getPost(ctx: *zzz.Context) !void {
    const slug = ctx.param("slug") orelse "unknown";
    _ = slug;
    ctx.json(.ok,
        \\{"slug": "hello-world", "title": "Hello World", "body": "This is the first post."}
    );
}

fn createPost(ctx: *zzz.Context) !void {
    const title = ctx.param("title") orelse "untitled";
    _ = title;
    ctx.json(.created,
        \\{"id": 1, "created": true}
    );
}

fn updatePost(ctx: *zzz.Context) !void {
    const id = ctx.param("id") orelse "0";
    _ = id;
    ctx.json(.ok,
        \\{"updated": true}
    );
}

fn deletePost(ctx: *zzz.Context) !void {
    const id = ctx.param("id") orelse "0";
    _ = id;
    ctx.json(.ok,
        \\{"deleted": true}
    );
}

/// Rate-limited endpoint demo.
///
/// Try: curl http://127.0.0.1:9000/api/limited (rapid requests → 429)
fn rateLimitedHandler(ctx: *zzz.Context) !void {
    ctx.json(.ok,
        \\{"message": "You are within the rate limit"}
    );
}

/// File download demo.
///
/// Try: curl http://127.0.0.1:9000/download/build.zig
fn downloadFile(ctx: *zzz.Context) !void {
    const filename = ctx.param("filename") orelse {
        ctx.text(.bad_request, "missing filename");
        return;
    };
    ctx.sendFile(filename, null);
}

/// Endpoint that deliberately errors — for error handler demo.
fn errorDemo(_: *zzz.Context) !void {
    return error.IntentionalDemoError;
}

// ── Auth demos ────────────────────────────────────────────────────────

/// Bearer token demo.
///
/// Try: curl -H "Authorization: Bearer my-secret-token" http://127.0.0.1:9000/auth/bearer
fn bearerDemo(ctx: *zzz.Context) !void {
    const token = ctx.getAssign("bearer_token") orelse "none";
    var buf: [256]u8 = undefined;
    const body = std.fmt.bufPrint(&buf,
        \\{{"auth":"bearer","token":"{s}"}}
    , .{token}) catch
        \\{"error":"response too large"}
    ;
    ctx.json(.ok, body);
}

/// Basic auth demo.
///
/// Try: curl -u alice:secret http://127.0.0.1:9000/auth/basic
fn basicDemo(ctx: *zzz.Context) !void {
    const username = ctx.getAssign("auth_username") orelse "none";
    const password = ctx.getAssign("auth_password") orelse "none";
    var buf: [256]u8 = undefined;
    const body = std.fmt.bufPrint(&buf,
        \\{{"auth":"basic","username":"{s}","password":"{s}"}}
    , .{ username, password }) catch
        \\{"error":"response too large"}
    ;
    ctx.json(.ok, body);
}

/// JWT auth demo.
///
/// Try: generate a JWT at jwt.io with secret "zzz-demo-secret", then:
///   curl -H "Authorization: Bearer <token>" http://127.0.0.1:9000/auth/jwt
fn jwtDemo(ctx: *zzz.Context) !void {
    const payload = ctx.getAssign("jwt_payload") orelse "none";
    var buf: [512]u8 = undefined;
    const body = std.fmt.bufPrint(&buf,
        \\{{"auth":"jwt","payload":"{s}"}}
    , .{payload}) catch
        \\{"error":"response too large"}
    ;
    ctx.json(.ok, body);
}

// ── Router ─────────────────────────────────────────────────────────────

const App = zzz.Router.define(.{
    .middleware = &.{
        zzz.errorHandler(.{ .show_details = true }),
        zzz.logger,
        zzz.gzipCompress(.{}),
        requestId,
        zzz.cors(.{}),
        zzz.bodyParser,
        zzz.session(.{}),
        zzz.csrf(.{}),
        zzz.staticFiles(.{ .dir = "public", .prefix = "/static" }),
    },
    .routes = zzz.Router.resource("/api/posts", .{
        .index = listPosts,
        .show = getPost,
        .create = createPost,
        .update = updatePost,
        .delete_handler = deletePost,
    }) ++ &[_]zzz.RouteDef{
        zzz.Router.get("/", index).named("home"),
        zzz.Router.get("/about", about).named("about"),

        // Session / Cookie / Redirect demos
        zzz.Router.get("/login", loginPage).named("login"),
        zzz.Router.get("/dashboard", dashboard).named("dashboard"),
        zzz.Router.post("/api/protected", protectedAction),
        zzz.Router.get("/old-page", oldPage),
        zzz.Router.get("/set-cookie", setCookieDemo),
        zzz.Router.get("/delete-cookie", deleteCookieDemo),

        // API routes
        zzz.Router.get("/api/status", apiStatus).named("api_status"),
        zzz.Router.get("/api/users", listUsers).named("users"),
        zzz.Router.get("/api/users/:id", getUser).named("user"),
        zzz.Router.post("/api/users", createUser),
        zzz.Router.post("/api/echo", echoBody),
        zzz.Router.post("/api/upload", uploadHandler),
    } ++ zzz.Router.scope("/api", &[_]zzz.HandlerFn{zzz.rateLimit(.{ .max_requests = 10, .window_seconds = 60 })}, &[_]zzz.RouteDef{
        zzz.Router.get("/limited", rateLimitedHandler),
    })
        // Auth demos — each scope applies its own auth middleware
    ++ zzz.Router.scope("/auth", &[_]zzz.HandlerFn{zzz.bearerAuth(.{ .required = true })}, &[_]zzz.RouteDef{
        zzz.Router.get("/bearer", bearerDemo),
    }) ++ zzz.Router.scope("/auth", &[_]zzz.HandlerFn{zzz.basicAuth(.{ .required = true })}, &[_]zzz.RouteDef{
        zzz.Router.get("/basic", basicDemo),
    }) ++ zzz.Router.scope("/auth", &[_]zzz.HandlerFn{zzz.jwtAuth(.{ .secret = "zzz-demo-secret", .required = true })}, &[_]zzz.RouteDef{
        zzz.Router.get("/jwt", jwtDemo),
    }) ++ &[_]zzz.RouteDef{

        // File download demo
        zzz.Router.get("/download/:filename", downloadFile),

        // Error handler demo
        zzz.Router.get("/error-demo", errorDemo),
    },
});

// ── Main ───────────────────────────────────────────────────────────────

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var server = zzz.Server.init(allocator, .{
        .host = "127.0.0.1",
        .port = 9000,
        // To enable HTTPS, build with: zig build -Dtls run
        // .tls = .{
        //     .cert_file = "certs/dev.pem",
        //     .key_file = "certs/dev-key.pem",
        // },
    }, App.handler);

    try server.listen(io);
}
