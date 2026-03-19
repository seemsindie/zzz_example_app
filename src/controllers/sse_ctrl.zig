const zzz = @import("zzz");

// ── Routes ─────────────────────────────────────────────────────────────

pub const ctrl = zzz.Controller.define(.{}, &.{
    zzz.Router.get("/sse-demo", sseDemo),
    zzz.Router.get("/events", sseEndpoint),
});

// ── Handlers ───────────────────────────────────────────────────────────

fn sseDemo(ctx: *zzz.Context) !void {
    ctx.html(.ok,
        \\<!DOCTYPE html>
        \\<html>
        \\<head><title>SSE Demo</title></head>
        \\<body>
        \\<h1>Server-Sent Events Demo</h1>
        \\<div id="events"></div>
        \\<script>
        \\const es = new EventSource('/events');
        \\es.addEventListener('message', e => {
        \\  document.getElementById('events').innerHTML += '<p>' + e.data + '</p>';
        \\});
        \\es.addEventListener('ping', e => {
        \\  document.getElementById('events').innerHTML += '<p style="color:gray">[ping] ' + e.data + '</p>';
        \\});
        \\</script>
        \\</body>
        \\</html>
    );
}

fn sseEndpoint(ctx: *zzz.Context) !void {
    // Send SSE-formatted response
    // In a real app, you'd use the SseWriter with a long-lived connection.
    // This demo sends initial events and lets the EventSource reconnect.
    ctx.respond(.ok, "text/event-stream",
        "event: message\ndata: Hello from SSE!\n\nevent: ping\ndata: connected\n\n"
    );
}
