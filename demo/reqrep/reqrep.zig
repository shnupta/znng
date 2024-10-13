const std = @import("std");
const c = @cImport({
    @cInclude("nng/nng.h");
    @cInclude("nng/protocol/reqrep0/rep.h");
    @cInclude("nng/protocol/reqrep0/req.h");
});

fn fatal(rv: i32, message: []const u8) noreturn {
    std.debug.print("{s}: {s}\n", .{ message, c.nng_strerror(rv) });
    @panic(message);
}

fn checkOrPanic(rv: i32, message: []const u8) void {
    if (rv != 0) {
        fatal(rv, message);
    }
}

fn client(url: []const u8) void {
    const c_url: [*]const u8 = @ptrCast(url);
    var sock: c.nng_socket = undefined;
    var dialer: c.nng_dialer = undefined;
    var rv: i32 = 0;
    var cmd: [8]u8 = undefined;
    cmd[0] = 'c';
    cmd[1] = 'a';
    cmd[2] = 's';
    cmd[3] = 'e';
    cmd[4] = 'y';

    rv = c.nng_req_open(&sock);
    checkOrPanic(rv, "Unable to open client socket");
    defer _ = c.nng_close(sock);

    rv = c.nng_dialer_create(&dialer, sock, c_url);
    checkOrPanic(rv, "Unable to create dialer");

    rv = c.nng_dialer_start(dialer, c.NNG_FLAG_NONBLOCK);
    checkOrPanic(rv, "Failed to start dialer");

    while (true) {
        rv = c.nng_send(sock, @ptrCast(@as([*]u8, &cmd)), @sizeOf(@TypeOf(cmd)), 0);
        checkOrPanic(rv, "Failed to send from client");
        break;
    }
}

fn server(url: []const u8) void {
    const c_url: [*]const u8 = @ptrCast(url);
    var sock: c.nng_socket = undefined;
    var listener: c.nng_listener = undefined;
    var rv: i32 = 0;
    var count: u64 = 0;

    rv = c.nng_rep0_open(&sock);
    checkOrPanic(rv, "Unable to open server socket");

    rv = c.nng_listener_create(&listener, sock, c_url);
    checkOrPanic(rv, "Unable to create listener");

    rv = c.nng_listener_start(listener, 0);
    checkOrPanic(rv, "Unable to start listener");

    while (true) {
        var buf: [*]u8 = undefined;
        var sz: usize = undefined;
        count += 1;

        std.debug.print("waiting for data\n", .{});
        rv = c.nng_recv(sock, @as(?*anyopaque, @ptrCast(&buf)), &sz, c.NNG_FLAG_ALLOC);
        checkOrPanic(rv, "Failed to receive from socket");
        defer c.nng_free(@as(?*anyopaque, buf), sz);

        std.debug.print("received: {s}\n", .{buf[0..sz]});

        break;
    }
}
pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    const argc = args.len;

    if (argc > 1 and std.mem.eql(u8, args[1], "client")) {
        return client(args[2]);
    }

    if (argc > 1 and std.mem.eql(u8, args[1], "server")) {
        return server(args[2]);
    }

    std.debug.print("Usage: reqrep {s}|{s} <url> ...\n", .{ "client", "server" });
}
