const std = @import("std");
const zzz = @import("zzz");

// ── Routes ─────────────────────────────────────────────────────────────

pub const ctrl = zzz.Controller.define(.{}, &.{
    zzz.Router.get("/login", loginPage).named("login"),
    zzz.Router.get("/dashboard", dashboard).named("dashboard"),
    zzz.Router.post("/api/protected", protectedAction),
    zzz.Router.get("/old-page", oldPage),
    zzz.Router.get("/set-cookie", setCookieDemo),
    zzz.Router.get("/delete-cookie", deleteCookieDemo),
});

// ── Handlers ───────────────────────────────────────────────────────────

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

fn protectedAction(ctx: *zzz.Context) !void {
    ctx.assign("user_name", "alice");
    ctx.json(.ok,
        \\{"result":"success","message":"CSRF validation passed"}
    );
}

fn oldPage(ctx: *zzz.Context) !void {
    ctx.redirect("/about", .moved_permanently);
}

fn setCookieDemo(ctx: *zzz.Context) !void {
    ctx.setCookie("theme", "dark", .{ .path = "/", .max_age = 86400 });
    ctx.json(.ok,
        \\{"message":"theme cookie set to dark"}
    );
}

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
