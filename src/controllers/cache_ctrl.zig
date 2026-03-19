const std = @import("std");
const zzz = @import("zzz");

// ── Routes ─────────────────────────────────────────────────────────────

pub const ctrl = zzz.Controller.define(.{}, &.{
    zzz.Router.get("/cache-demo", cacheDemo),
});

// Exported separately for use with Router.scope() in main.zig
pub fn cachedTime(ctx: *zzz.Context) !void {
    // This will be cached — same response for 10s
    // Use a simple counter to show caching works (same value returned while cached)
    const counter = struct {
        var val: u32 = 0;
    };
    counter.val +%= 1;
    var buf: [64]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "{{\"request_number\": {d}}}", .{counter.val}) catch "{}";
    ctx.json(.ok, msg);
}

// ── Handlers ───────────────────────────────────────────────────────────

fn cacheDemo(ctx: *zzz.Context) !void {
    ctx.html(.ok,
        \\<!DOCTYPE html>
        \\<html>
        \\<head><title>Cache Demo</title></head>
        \\<body>
        \\<h1>Response Cache Demo</h1>
        \\<p>The endpoint <code>/api/cached/time</code> returns the current timestamp but is cached for 10 seconds.</p>
        \\<p>First request: <code>X-Cache: MISS</code>. Subsequent: <code>X-Cache: HIT</code>.</p>
        \\<button onclick="fetch('/api/cached/time').then(r=>{document.getElementById('h').textContent=r.headers.get('X-Cache');return r.text()}).then(t=>document.getElementById('r').textContent=t)">Fetch</button>
        \\<p>Cache: <span id="h">-</span></p>
        \\<pre id="r"></pre>
        \\</body>
        \\</html>
    );
}
