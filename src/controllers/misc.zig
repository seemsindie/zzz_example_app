const zzz = @import("zzz");

// ── Routes ─────────────────────────────────────────────────────────────

pub const ctrl = zzz.Controller.define(.{}, &.{
    zzz.Router.get("/download/:filename", downloadFile),
    zzz.Router.get("/error-demo", errorDemo),
});

// Rate-limited handler is exported directly — wired via Router.scope() in main.zig
pub fn rateLimitedHandler(ctx: *zzz.Context) !void {
    ctx.json(.ok,
        \\{"message": "You are within the rate limit"}
    );
}

// ── Handlers ───────────────────────────────────────────────────────────

fn downloadFile(ctx: *zzz.Context) !void {
    const filename = ctx.param("filename") orelse {
        ctx.text(.bad_request, "missing filename");
        return;
    };
    ctx.sendFile(filename, null);
}

fn errorDemo(_: *zzz.Context) !void {
    return error.IntentionalDemoError;
}
