const std = @import("std");
const zzz = @import("zzz");

// ── Doc Types ──────────────────────────────────────────────────────────

pub const ApiStatusResponse = struct {
    status: []const u8,
    framework: []const u8,
    version: []const u8,
};

pub const UserResponse = struct {
    id: i64,
    name: []const u8,
    email: []const u8,
};

pub const UserListResponse = struct {
    users: []const UserResponse,
};

pub const CreateUserRequest = struct {
    name: []const u8,
    email: []const u8,
};

pub const PostResponse = struct {
    slug: []const u8,
    title: []const u8,
    body: []const u8,
};

pub const PostListResponse = struct {
    posts: []const PostResponse,
};

pub const CreatePostRequest = struct {
    title: []const u8,
    body: []const u8,
};

// ── Routes ─────────────────────────────────────────────────────────────

pub const ctrl = zzz.Controller.define(.{
    .prefix = "/api",
    .tag = "API",
}, &.{
    zzz.Router.get("/status", apiStatus).named("api_status")
        .doc(.{ .summary = "Health check", .description = "Returns the API status and version info.", .response_body = ApiStatusResponse }),
    zzz.Router.get("/users", listUsers).named("users")
        .doc(.{ .summary = "List all users", .tag = "Users", .response_body = UserListResponse }),
    zzz.Router.get("/users/:id", getUser).named("user")
        .doc(.{ .summary = "Get user by ID", .tag = "Users", .response_body = UserResponse }),
    zzz.Router.post("/users", createUser)
        .doc(.{ .summary = "Create a new user", .tag = "Users", .request_body = CreateUserRequest, .response_body = UserResponse }),
    zzz.Router.post("/echo", echoBody)
        .doc(.{ .summary = "Echo request body", .description = "Echoes back the parsed request body. Supports JSON, form, multipart, and text.", .tag = "System" }),
    zzz.Router.post("/upload", uploadHandler)
        .doc(.{ .summary = "Upload a file", .description = "Upload a file via multipart form data.", .tag = "System" }),
});

pub const posts_resource = zzz.Router.resource("/api/posts", .{
    .index = listPosts,
    .show = getPost,
    .create = createPost,
    .update = updatePost,
    .delete_handler = deletePost,
});

// ── Handlers ───────────────────────────────────────────────────────────

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
    ctx.json(.ok,
        \\{"id": 1, "name": "Alice", "email": "alice@example.com"}
    );
}

fn createUser(ctx: *zzz.Context) !void {
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
