const std = @import("std");
const zzz = @import("zzz");
const zzz_jobs = @import("zzz_jobs");
const home = @import("home.zig");

const AppLayout = home.AppLayout;

// ── Templates ──────────────────────────────────────────────────────────

const JobsDemoContent = zzz.template(@embedFile("../templates/jobs_demo.html.zzz"));

// ── Doc Types ──────────────────────────────────────────────────────────

pub const JobEnqueueRequest = struct {
    worker: []const u8,
    args: []const u8,
};

pub const JobStatsResponse = struct {
    available: i64,
    executing: i64,
    completed: i64,
    discarded: i64,
};

// ── Routes ─────────────────────────────────────────────────────────────

pub const ctrl = zzz.Controller.define(.{
    .prefix = "/jobs",
    .tag = "Jobs",
}, &.{
    zzz.Router.get("", jobsDemo),
    zzz.Router.post("/enqueue", jobsEnqueue)
        .doc(.{ .summary = "Enqueue a background job", .description = "Enqueue a new background job for async processing.", .request_body = JobEnqueueRequest }),
    zzz.Router.get("/stats", jobsStats)
        .doc(.{ .summary = "Get job queue stats", .description = "Returns current job queue statistics.", .response_body = JobStatsResponse }),
});

// ── State ──────────────────────────────────────────────────────────────

var jobs_supervisor: zzz_jobs.MemorySupervisor = undefined;
var jobs_initialized: bool = false;
var jobs_telemetry: zzz_jobs.Telemetry = .{};

var jobs_log: [16][128]u8 = [_][128]u8{[_]u8{0} ** 128} ** 16;
var jobs_log_len: [16]usize = [_]usize{0} ** 16;
var jobs_log_count: usize = 0;

var jobs_args_store: [64][128]u8 = [_][128]u8{[_]u8{0} ** 128} ** 64;
var jobs_args_lens: [64]usize = [_]usize{0} ** 64;
var jobs_args_next: usize = 0;

fn storeArgs(args: []const u8) []const u8 {
    const idx = jobs_args_next % 64;
    const len = @min(args.len, 128);
    @memcpy(jobs_args_store[idx][0..len], args[0..len]);
    jobs_args_lens[idx] = len;
    jobs_args_next += 1;
    return jobs_args_store[idx][0..len];
}

fn addJobLog(msg: []const u8) void {
    const idx = jobs_log_count % 16;
    const copy_len = @min(msg.len, 128);
    @memcpy(jobs_log[idx][0..copy_len], msg[0..copy_len]);
    if (copy_len < 128) {
        @memset(jobs_log[idx][copy_len..], 0);
    }
    jobs_log_len[idx] = copy_len;
    jobs_log_count += 1;
}

fn jobsTelemetryHandler(event: zzz_jobs.Event) void {
    switch (event) {
        .job_enqueued => |j| {
            var buf: [128]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "Enqueued: {s}({s})", .{ j.worker, j.args }) catch "Enqueued job";
            addJobLog(msg);
        },
        .job_completed => |r| {
            var buf: [128]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "Completed: {s} in {d}ms", .{ r.job.worker, r.duration_ms }) catch "Completed job";
            addJobLog(msg);
        },
        .job_failed => |r| {
            var buf: [128]u8 = undefined;
            const err = r.error_msg orelse "unknown";
            const msg = std.fmt.bufPrint(&buf, "Failed: {s} - {s} (attempt {d})", .{ r.job.worker, err, r.job.attempt }) catch "Failed job";
            addJobLog(msg);
        },
        .job_discarded => |r| {
            var buf: [128]u8 = undefined;
            const err = r.error_msg orelse "unknown";
            const msg = std.fmt.bufPrint(&buf, "Discarded: {s} - {s}", .{ r.job.worker, err }) catch "Discarded job";
            addJobLog(msg);
        },
        .job_started => |j| {
            var buf: [128]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "Started: {s}({s})", .{ j.worker, j.args }) catch "Started job";
            addJobLog(msg);
        },
        .queue_paused, .queue_resumed => {},
    }
}

fn echoWorker(args: []const u8, _: *zzz_jobs.JobContext) anyerror!void {
    _ = args;
}

fn slowWorker(args: []const u8, _: *zzz_jobs.JobContext) anyerror!void {
    _ = args;
    zzz_jobs.time_utils.sleepMs(2000);
}

fn failingWorker(_: []const u8, _: *zzz_jobs.JobContext) anyerror!void {
    return error.SimulatedFailure;
}

fn initJobs() !void {
    if (jobs_initialized) return;

    jobs_supervisor = try zzz_jobs.MemorySupervisor.init(.{}, .{
        .queues = &.{.{ .name = "default", .concurrency = 2 }},
        .poll_interval_ms = 100,
        .rescue_interval_ms = 60_000,
    });

    jobs_supervisor.registerWorker(.{
        .name = "echo_worker",
        .handler = &echoWorker,
    });
    jobs_supervisor.registerWorker(.{
        .name = "slow_worker",
        .handler = &slowWorker,
    });
    jobs_supervisor.registerWorker(.{
        .name = "failing_worker",
        .handler = &failingWorker,
        .opts = .{ .max_attempts = 3 },
        .retry_strategy = .{ .constant = .{ .delay_seconds = 1 } },
    });

    jobs_telemetry.attach(&jobsTelemetryHandler);
    jobs_supervisor.telemetry = &jobs_telemetry;

    try jobs_supervisor.start();
    jobs_initialized = true;
}

fn renderStatsHtml(buf: *[2048]u8) []const u8 {
    const available = jobs_supervisor.store.countByState("default", .available) catch 0;
    const executing = jobs_supervisor.store.countByState("default", .executing) catch 0;
    const completed = jobs_supervisor.store.countByState("default", .completed) catch 0;
    const discarded = jobs_supervisor.store.countByState("default", .discarded) catch 0;

    var offset: usize = 0;
    const header =
        \\<table>
        \\<tr><th>State</th><th>Count</th></tr>
        \\
    ;
    @memcpy(buf[offset..][0..header.len], header);
    offset += header.len;

    const row1 = std.fmt.bufPrint(buf[offset..], "<tr><td>Available</td><td>{d}</td></tr>\n", .{available}) catch "";
    offset += row1.len;
    const row2 = std.fmt.bufPrint(buf[offset..], "<tr><td>Executing</td><td>{d}</td></tr>\n", .{executing}) catch "";
    offset += row2.len;
    const row3 = std.fmt.bufPrint(buf[offset..], "<tr><td>Completed</td><td>{d}</td></tr>\n", .{completed}) catch "";
    offset += row3.len;
    const row4 = std.fmt.bufPrint(buf[offset..], "<tr><td>Discarded</td><td>{d}</td></tr>\n", .{discarded}) catch "";
    offset += row4.len;

    const table_end = "</table>\n<h3>Activity Log</h3>\n<ul>\n";
    @memcpy(buf[offset..][0..table_end.len], table_end);
    offset += table_end.len;

    const total = jobs_log_count;
    const show = @min(total, 10);
    if (show > 0) {
        var i: usize = 0;
        while (i < show) : (i += 1) {
            const idx = (total - 1 - i) % 16;
            const entry = jobs_log[idx][0..jobs_log_len[idx]];
            if (entry.len > 0) {
                const li = std.fmt.bufPrint(buf[offset..], "<li>{s}</li>\n", .{entry}) catch "";
                offset += li.len;
            }
            if (offset >= 1900) break;
        }
    } else {
        const empty = "<li>No activity yet.</li>\n";
        @memcpy(buf[offset..][0..empty.len], empty);
        offset += empty.len;
    }

    const ul_end = "</ul>\n";
    @memcpy(buf[offset..][0..ul_end.len], ul_end);
    offset += ul_end.len;

    return buf[0..offset];
}

// ── Handlers ───────────────────────────────────────────────────────────

fn jobsDemo(ctx: *zzz.Context) !void {
    initJobs() catch {
        ctx.text(.internal_server_error, "Jobs initialization failed");
        return;
    };

    const csrf_token = ctx.getAssign("csrf_token") orelse "";

    var stats_buf: [2048]u8 = undefined;
    const stats_html = renderStatsHtml(&stats_buf);

    try ctx.renderWithLayoutAndYields(AppLayout, JobsDemoContent, .ok, .{
        .title = "Background Jobs Demo",
        .description = "Background job processing powered by zzz_jobs (in-memory store).",
        .csrf_token = csrf_token,
        .stats_html = stats_html,
    }, .{
        .head = ctx.htmxScriptTag(),
    });
}

fn jobsEnqueue(ctx: *zzz.Context) !void {
    initJobs() catch {
        ctx.text(.internal_server_error, "Jobs initialization failed");
        return;
    };

    const worker_param = ctx.param("worker") orelse "echo_worker";
    const worker: []const u8 = if (std.mem.eql(u8, worker_param, "slow_worker"))
        "slow_worker"
    else if (std.mem.eql(u8, worker_param, "failing_worker"))
        "failing_worker"
    else
        "echo_worker";

    const raw_args = ctx.param("args") orelse "";
    const decoded = zzz.urlDecode(ctx.allocator, raw_args) catch raw_args;
    const args = storeArgs(decoded);

    _ = jobs_supervisor.enqueue(worker, args, .{
        .max_attempts = if (std.mem.eql(u8, worker, "failing_worker")) @as(i32, 3) else @as(i32, 20),
    }) catch {};

    ctx.redirect("/jobs", .see_other);
}

fn jobsStats(ctx: *zzz.Context) !void {
    initJobs() catch {
        ctx.text(.internal_server_error, "Jobs initialization failed");
        return;
    };

    var stats_buf: [2048]u8 = undefined;
    const stats_html = renderStatsHtml(&stats_buf);
    ctx.html(.ok, stats_html);
}
