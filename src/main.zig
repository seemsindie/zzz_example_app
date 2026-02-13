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

// ── Router ─────────────────────────────────────────────────────────────

const App = zzz.Router.define(.{
    .middleware = &.{
        zzz.logger,
        requestId,
        zzz.cors(.{}),
        zzz.bodyParser,
        zzz.staticFiles(.{ .dir = "public", .prefix = "/static" }),
    },
    .routes = &.{
        zzz.Router.get("/", index),
        zzz.Router.get("/about", about),

        // API routes
        zzz.Router.get("/api/status", apiStatus),
        zzz.Router.get("/api/users", listUsers),
        zzz.Router.get("/api/users/:id", getUser),
        zzz.Router.post("/api/users", createUser),
        zzz.Router.post("/api/echo", echoBody),
        zzz.Router.post("/api/upload", uploadHandler),
        zzz.Router.get("/api/posts", listPosts),
        zzz.Router.get("/api/posts/:slug", getPost),
    },
});

// ── Main ───────────────────────────────────────────────────────────────

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var server = zzz.Server.init(allocator, .{
        .host = "127.0.0.1",
        .port = 5000,
    }, App.handler);

    try server.listen(io);
}
