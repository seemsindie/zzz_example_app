const std = @import("std");
const zzz = @import("zzz");
const zzz_mailer = @import("zzz_mailer");
const home = @import("home.zig");

const AppLayout = home.AppLayout;
const DevAdapter = zzz_mailer.DevAdapter;
const DevMailer = zzz_mailer.DevMailer;
const DevMailbox = zzz_mailer.DevMailbox;
const Email = zzz_mailer.Email;

// ── State ──────────────────────────────────────────────────────────────

var dev_adapter: DevAdapter = DevAdapter.init(.{});
var dev_mailer: DevMailer = DevMailer.init(.{});
var mailbox: DevMailbox = undefined;
var initialized: bool = false;

fn ensureInit() void {
    if (!initialized) {
        dev_mailer.adapter = dev_adapter;
        mailbox = DevMailbox.init(&dev_mailer.adapter);
        initialized = true;
    }
}

// ── Routes ─────────────────────────────────────────────────────────────

pub const ctrl = zzz.Controller.define(.{
    .prefix = "/mail",
    .tag = "Mailer",
}, &.{
    zzz.Router.get("/send-test", sendTestEmail)
        .doc(.{ .summary = "Send a test email", .description = "Sends a test email via the DevAdapter (viewable at /__zzz/mailbox)." }),
});

// ── Handlers ───────────────────────────────────────────────────────────

fn sendTestEmail(ctx: *zzz.Context) !void {
    ensureInit();

    const email = Email{
        .from = .{ .email = "noreply@example.com", .name = "Example App" },
        .to = &.{.{ .email = "user@example.com", .name = "Test User" }},
        .cc = &.{.{ .email = "cc@example.com" }},
        .subject = "Welcome to zzz_mailer!",
        .text_body = "Hello from zzz_mailer!\n\nThis is a test email sent via the DevAdapter.\nView all sent emails at /__zzz/mailbox.",
        .html_body =
        \\<!DOCTYPE html>
        \\<html>
        \\<body style="font-family: sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        \\  <h1 style="color: #667eea;">Welcome to zzz_mailer!</h1>
        \\  <p>Hello from zzz_mailer!</p>
        \\  <p>This is a test email sent via the <strong>DevAdapter</strong>.</p>
        \\  <p>View all sent emails at <a href="/__zzz/mailbox">/__zzz/mailbox</a>.</p>
        \\  <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">
        \\  <p style="color: #999; font-size: 12px;">Sent by the zzz web framework</p>
        \\</body>
        \\</html>
        ,
    };

    _ = dev_mailer.send(email, ctx.allocator);

    ctx.redirect("/__zzz/mailbox", .see_other);
}

// ── Dev Mailbox Handlers ───────────────────────────────────────────────

pub fn mailboxInbox(ctx: *zzz.Context) !void {
    ensureInit();
    var buf: [32768]u8 = undefined;
    if (mailbox.renderInbox(&buf)) |html| {
        ctx.html(.ok, html);
    } else {
        ctx.text(.internal_server_error, "Failed to render mailbox");
    }
}

pub fn mailboxDetail(ctx: *zzz.Context) !void {
    ensureInit();
    const index_str = ctx.param("index") orelse {
        ctx.text(.bad_request, "Missing index");
        return;
    };
    const index = std.fmt.parseInt(usize, index_str, 10) catch {
        ctx.text(.bad_request, "Invalid index");
        return;
    };
    var buf: [32768]u8 = undefined;
    if (mailbox.renderDetail(index, &buf)) |html| {
        ctx.html(.ok, html);
    } else {
        ctx.text(.not_found, "Email not found");
    }
}

pub fn mailboxHtml(ctx: *zzz.Context) !void {
    ensureInit();
    const index_str = ctx.param("index") orelse {
        ctx.text(.bad_request, "Missing index");
        return;
    };
    const index = std.fmt.parseInt(usize, index_str, 10) catch {
        ctx.text(.bad_request, "Invalid index");
        return;
    };
    if (mailbox.renderHtmlBody(index)) |html| {
        ctx.html(.ok, html);
    } else {
        ctx.text(.not_found, "No HTML body");
    }
}

pub fn mailboxClear(ctx: *zzz.Context) !void {
    ensureInit();
    dev_mailer.adapter.clear();
    ctx.redirect("/__zzz/mailbox", .see_other);
}
