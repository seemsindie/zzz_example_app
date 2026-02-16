const std = @import("std");
const zzz = @import("zzz");

// Auth handlers are exported directly — each uses a different auth middleware,
// so they're wired via Router.scope() in main.zig rather than Controller.define().

pub fn bearerDemo(ctx: *zzz.Context) !void {
    const token = ctx.getAssign("bearer_token") orelse "none";
    var buf: [256]u8 = undefined;
    const body = std.fmt.bufPrint(&buf,
        \\{{"auth":"bearer","token":"{s}"}}
    , .{token}) catch
        \\{"error":"response too large"}
    ;
    ctx.json(.ok, body);
}

pub fn basicDemo(ctx: *zzz.Context) !void {
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

pub fn jwtDemo(ctx: *zzz.Context) !void {
    const payload = ctx.getAssign("jwt_payload") orelse "none";
    var buf: [512]u8 = undefined;
    const body = std.fmt.bufPrint(&buf,
        \\{{"auth":"jwt","payload":"{s}"}}
    , .{payload}) catch
        \\{"error":"response too large"}
    ;
    ctx.json(.ok, body);
}
