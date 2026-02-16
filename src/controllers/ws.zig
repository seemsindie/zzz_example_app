const std = @import("std");
const zzz = @import("zzz");
const home = @import("home.zig");

const AppLayout = home.AppLayout;

// ── Templates ──────────────────────────────────────────────────────────

const WsDemoContent = zzz.template(@embedFile("../templates/ws_demo.html.zzz"));
const ChatDemoContent = zzz.template(@embedFile("../templates/chat.html.zzz"));

// ── Channel Definition ─────────────────────────────────────────────────

fn roomJoin(_: *zzz.Socket, _: []const u8, _: []const u8) zzz.JoinResult {
    return .ok;
}

fn roomLeave(_: *zzz.Socket, _: []const u8) void {}

fn roomHandleNewMsg(socket: *zzz.Socket, topic: []const u8, _: []const u8, payload: []const u8) void {
    socket.broadcast(topic, "new_msg", payload);
}

const roomChannelDef: zzz.ChannelDef = .{
    .topic_pattern = "room:*",
    .join = &roomJoin,
    .leave = &roomLeave,
    .handlers = &.{
        .{ .event = "new_msg", .handler = &roomHandleNewMsg },
    },
};

// ── WebSocket Callbacks ────────────────────────────────────────────────

fn wsEchoOpen(ws: *zzz.WebSocket) void {
    _ = ws;
    std.log.info("[WS] client connected", .{});
}

fn wsEchoMessage(ws: *zzz.WebSocket, msg: zzz.WsMessage) void {
    switch (msg) {
        .text => |text| {
            std.log.info("[WS] echo: {s}", .{text});
            ws.send(text);
        },
        .binary => |data| {
            ws.sendBinary(data);
        },
    }
}

fn wsEchoClose(_: *zzz.WebSocket, code: u16, _: []const u8) void {
    std.log.info("[WS] client disconnected (code: {d})", .{code});
}

// ── Routes ─────────────────────────────────────────────────────────────

pub const ctrl = zzz.Controller.define(.{}, &.{
    zzz.Router.get("/ws-demo", wsDemo),
    zzz.Router.ws("/ws/echo", .{
        .on_open = wsEchoOpen,
        .on_message = wsEchoMessage,
        .on_close = wsEchoClose,
    }),
    zzz.Router.get("/chat", chatDemo),
    zzz.Router.channel("/socket", .{
        .channels = &.{roomChannelDef},
    }),
});

// ── Handlers ───────────────────────────────────────────────────────────

fn wsDemo(ctx: *zzz.Context) !void {
    try ctx.renderWithLayout(AppLayout, WsDemoContent, .ok, .{
        .title = "WebSocket Demo",
    });
}

fn chatDemo(ctx: *zzz.Context) !void {
    try ctx.renderWithLayout(AppLayout, ChatDemoContent, .ok, .{
        .title = "Channel Chat Demo",
    });
}
