const std = @import("std");
const zzz = @import("zzz");
const home = @import("home.zig");

const AppLayout = home.AppLayout;

// ── Templates ──────────────────────────────────────────────────────────

const HtmxDemoContent = zzz.templateWithPartials(
    @embedFile("../templates/htmx_demo.html.zzz"),
    .{ .counter = @embedFile("../templates/partials/counter.html.zzz") },
);
const CounterPartial = zzz.template(@embedFile("../templates/partials/counter.html.zzz"));

const HtmxTodosContent = zzz.templateWithPartials(
    @embedFile("../templates/htmx_todos.html.zzz"),
    .{ .todo_item = @embedFile("../templates/partials/todo_item.html.zzz") },
);
const TodoListPartial = zzz.templateWithPartials(
    @embedFile("../templates/partials/todo_list.html.zzz"),
    .{ .todo_item = @embedFile("../templates/partials/todo_item.html.zzz") },
);

// ── Routes ─────────────────────────────────────────────────────────────

pub const ctrl = zzz.Controller.define(.{}, &.{
    zzz.Router.get("/htmx", htmxDemo),
    zzz.Router.post("/htmx/increment", htmxIncrement),
    zzz.Router.get("/htmx/greeting", htmxGreeting),
    zzz.Router.get("/todos", htmxTodos),
    zzz.Router.post("/todos", htmxTodoAdd),
    zzz.Router.delete("/todos/:id", htmxTodoDelete),
});

// ── State ──────────────────────────────────────────────────────────────

const TodoItem = struct { id: []const u8, text: []const u8 };

var todo_store: [32]struct { text: [128]u8, len: u8, active: bool } = undefined;
var todo_count: usize = 0;
var todo_next_id: u32 = 1;

fn getTodoItems(buf: *[32]TodoItem, id_bufs: *[32][8]u8) []const TodoItem {
    var n: usize = 0;
    for (&todo_store, 0..) |*slot, i| {
        if (i >= todo_count) break;
        if (slot.active) {
            const id_str = std.fmt.bufPrint(&id_bufs[n], "{d}", .{i + 1}) catch "0";
            buf[n] = .{ .id = id_str, .text = slot.text[0..slot.len] };
            n += 1;
        }
    }
    return buf[0..n];
}

// ── Handlers ───────────────────────────────────────────────────────────

fn htmxDemo(ctx: *zzz.Context) !void {
    const csrf_token = ctx.getAssign("csrf_token") orelse "";
    try ctx.renderWithLayoutAndYields(AppLayout, HtmxDemoContent, .ok, .{
        .title = "htmx Demo",
        .description = "Interactive demos powered by htmx.",
        .count = "0",
        .csrf_token = csrf_token,
    }, .{
        .head = ctx.htmxScriptTag(),
    });
}

fn htmxIncrement(ctx: *zzz.Context) !void {
    const raw = ctx.param("count") orelse "0";
    const current = std.fmt.parseInt(u32, raw, 10) catch 0;
    var buf: [16]u8 = undefined;
    const next_str = std.fmt.bufPrint(&buf, "{d}", .{current + 1}) catch "1";
    try ctx.renderPartial(CounterPartial, .ok, .{ .count = next_str });
    ctx.htmxTrigger("counterUpdated");
}

fn htmxGreeting(ctx: *zzz.Context) !void {
    const raw_name = ctx.param("name") orelse "stranger";
    const name = zzz.urlDecode(ctx.allocator, raw_name) catch raw_name;
    var buf: [256]u8 = undefined;
    const body = std.fmt.bufPrint(&buf, "<p>Hello, <strong>{s}</strong>!</p>", .{name}) catch "<p>Hello!</p>";
    ctx.html(.ok, body);
}

fn htmxTodos(ctx: *zzz.Context) !void {
    var item_buf: [32]TodoItem = undefined;
    var id_bufs: [32][8]u8 = undefined;
    const items = getTodoItems(&item_buf, &id_bufs);

    const csrf_token = ctx.getAssign("csrf_token") orelse "";
    try ctx.renderWithLayoutAndYields(AppLayout, HtmxTodosContent, .ok, .{
        .title = "Todo List",
        .description = "htmx-powered CRUD demo.",
        .has_items = items.len > 0,
        .items = items,
        .csrf_token = csrf_token,
    }, .{
        .head = ctx.htmxScriptTag(),
    });
}

fn htmxTodoAdd(ctx: *zzz.Context) !void {
    const raw_text = ctx.param("text") orelse "";
    const text = zzz.urlDecode(ctx.allocator, raw_text) catch raw_text;
    if (text.len > 0 and todo_count < 32) {
        var slot = &todo_store[todo_count];
        const copy_len = @min(text.len, 128);
        @memcpy(slot.text[0..copy_len], text[0..copy_len]);
        slot.len = @intCast(copy_len);
        slot.active = true;
        todo_count += 1;
        todo_next_id += 1;
    }

    var item_buf: [32]TodoItem = undefined;
    var id_bufs: [32][8]u8 = undefined;
    const items = getTodoItems(&item_buf, &id_bufs);

    try ctx.renderPartial(TodoListPartial, .ok, .{
        .has_items = items.len > 0,
        .items = items,
    });
}

fn htmxTodoDelete(ctx: *zzz.Context) !void {
    const id_str = ctx.param("id") orelse "0";
    const id = std.fmt.parseInt(usize, id_str, 10) catch 0;
    if (id > 0 and id <= todo_count) {
        todo_store[id - 1].active = false;
    }

    var item_buf: [32]TodoItem = undefined;
    var id_bufs: [32][8]u8 = undefined;
    const items = getTodoItems(&item_buf, &id_bufs);

    try ctx.renderPartial(TodoListPartial, .ok, .{
        .has_items = items.len > 0,
        .items = items,
    });
}
