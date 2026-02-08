const std = @import("std");
const net = std.net;
const Engine = @import("../rule/engine.zig").Engine;
const OutboundManager = @import("outbound/manager.zig").OutboundManager;

const Socks5Version = 0x05;
const AuthMethods = struct {
    const NoAuth: u8 = 0x00;
    const Password: u8 = 0x02;
    const NoAcceptable: u8 = 0xFF;
};

const Command = struct {
    const Connect: u8 = 0x01;
};

const AddressType = struct {
    const Ipv4: u8 = 0x01;
    const Domain: u8 = 0x03;
    const Ipv6: u8 = 0x04;
};

const Reply = struct {
    const Success: u8 = 0x00;
    const GeneralFailure: u8 = 0x01;
    const ConnectionRefused: u8 = 0x05;
    const HostUnreachable: u8 = 0x04;
    const AddressNotSupported: u8 = 0x08;
};

pub fn start(allocator: std.mem.Allocator, port: u16, engine: *Engine, manager: *OutboundManager) !void {
    const address = try net.Address.parseIp4("0.0.0.0", port);
    var server = try address.listen(.{
        .reuse_address = true,
    });
    defer server.deinit();

    std.debug.print("SOCKS5 proxy listening on port {}\n", .{port});

    while (true) {
        const conn = try server.accept();

        // Pass engine and manager to each connection handler
        const ctx = try allocator.create(ConnectionContext);
        ctx.* = .{
            .allocator = allocator,
            .engine = engine,
            .manager = manager,
        };

        const thread = try std.Thread.spawn(.{}, handleConnectionThread, .{ ctx, conn });
        thread.detach();
    }
}

const ConnectionContext = struct {
    allocator: std.mem.Allocator,
    engine: *Engine,
    manager: *OutboundManager,
};

fn handleConnectionThread(ctx: *ConnectionContext, conn: net.Server.Connection) !void {
    defer ctx.allocator.destroy(ctx);
    handleConnection(ctx.allocator, conn, ctx.engine, ctx.manager) catch |err| {
        std.debug.print("SOCKS5 connection error: {}\n", .{err});
        conn.stream.close();
    };
}

fn handleConnection(_allocator: std.mem.Allocator, conn: net.Server.Connection, engine: *Engine, manager: *OutboundManager) !void {
    _ = _allocator;
    defer conn.stream.close();

    // 1. Greeting phase
    var buf: [256]u8 = undefined;
    const n = try conn.stream.read(&buf);
    if (n < 3) return error.InvalidGreeting;

    if (buf[0] != Socks5Version) return error.InvalidVersion;

    const num_methods = buf[1];
    if (n < 2 + num_methods) return error.InvalidGreeting;

    var found_no_auth = false;
    for (0..num_methods) |i| {
        if (buf[2 + i] == AuthMethods.NoAuth) {
            found_no_auth = true;
            break;
        }
    }

    if (!found_no_auth) {
        try conn.stream.writeAll(&.{ Socks5Version, AuthMethods.NoAcceptable });
        return error.NoAcceptableAuth;
    }

    try conn.stream.writeAll(&.{ Socks5Version, AuthMethods.NoAuth });

    // 2. Request phase
    const req_n = try conn.stream.read(&buf);
    if (req_n < 10) return error.InvalidRequest;

    if (buf[0] != Socks5Version) return error.InvalidVersion;

    const cmd = buf[1];
    const atyp = buf[3];

    if (cmd != Command.Connect) {
        try sendReply(conn.stream, Reply.GeneralFailure, 0, &[_]u8{0} ** 4, 0);
        return error.CommandNotSupported;
    }

    var target_host: []const u8 = undefined;
    var target_port: u16 = undefined;
    var host_buf: [256]u8 = undefined;

    switch (atyp) {
        AddressType.Ipv4 => {
            if (req_n < 10) return error.InvalidRequest;
            target_host = try std.fmt.bufPrint(&host_buf, "{}.{}.{}.{}", .{ buf[4], buf[5], buf[6], buf[7] });
            target_port = (@as(u16, buf[8]) << 8) | buf[9];
        },
        AddressType.Domain => {
            const domain_len = buf[4];
            if (req_n < 5 + domain_len + 2) return error.InvalidRequest;
            target_host = buf[5 .. 5 + domain_len];
            target_port = (@as(u16, buf[5 + domain_len]) << 8) | buf[5 + domain_len + 1];
        },
        AddressType.Ipv6 => {
            try sendReply(conn.stream, Reply.AddressNotSupported, 0, &[_]u8{0} ** 4, 0);
            return error.Ipv6NotSupported;
        },
        else => return error.InvalidAddressType,
    }

    std.debug.print("[SOCKS5] CONNECT {s}:{d}\n", .{ target_host, target_port });

    // Apply rules from engine and connect via manager
    const proxy_name = engine.matchCtx(.{
        .target_host = target_host,
        .target_port = target_port,
        .is_domain = atyp == AddressType.Domain,
    }) orelse "DIRECT";
    std.debug.print("[SOCKS5] Rule matched: {s}\n", .{proxy_name});

    var target_stream = manager.connect(proxy_name, target_host, target_port) catch |err| {
        std.debug.print("[SOCKS5] Connection failed: {}\n", .{err});
        const reply_code = switch (err) {
            error.ConnectionRejected => Reply.ConnectionRefused,
            error.HostNotFound, error.ProxyNotFound => Reply.HostUnreachable,
            else => Reply.GeneralFailure,
        };
        try sendReply(conn.stream, reply_code, 0, &[_]u8{0} ** 4, 0);
        return;
    };
    defer target_stream.close();

    const bind_addr = net.Address.parseIp4("0.0.0.0", 0) catch unreachable;
    const bind_port: u16 = 0;
    const addr_bytes = std.mem.asBytes(&bind_addr.in.sa.addr);
    try sendReply(conn.stream, Reply.Success, AddressType.Ipv4, addr_bytes[0..4], bind_port);

    try relay(conn.stream.handle, target_stream.handle);
}

fn sendReply(stream: net.Stream, reply: u8, atyp: u8, addr: *const [4]u8, port: u16) !void {
    var resp: [10]u8 = undefined;
    resp[0] = Socks5Version;
    resp[1] = reply;
    resp[2] = 0x00;
    resp[3] = atyp;
    resp[4] = addr[0];
    resp[5] = addr[1];
    resp[6] = addr[2];
    resp[7] = addr[3];
    resp[8] = @intCast(port >> 8);
    resp[9] = @intCast(port & 0xFF);
    try stream.writeAll(&resp);
}

fn relay(client_fd: std.posix.fd_t, target_fd: std.posix.fd_t) !void {
    var poll_fds = [_]std.posix.pollfd{
        .{ .fd = client_fd, .events = std.posix.POLL.IN, .revents = 0 },
        .{ .fd = target_fd, .events = std.posix.POLL.IN, .revents = 0 },
    };

    var buf: [8192]u8 = undefined;

    while (true) {
        const ready = try std.posix.poll(&poll_fds, -1);
        _ = ready;

        if (poll_fds[0].revents & std.posix.POLL.IN != 0) {
            const n = try std.posix.read(client_fd, &buf);
            if (n == 0) break;
            var written: usize = 0;
            while (written < n) {
                const w = try std.posix.write(target_fd, buf[written..n]);
                written += w;
            }
        }

        if (poll_fds[1].revents & std.posix.POLL.IN != 0) {
            const n = try std.posix.read(target_fd, &buf);
            if (n == 0) break;
            var written: usize = 0;
            while (written < n) {
                const w = try std.posix.write(client_fd, buf[written..n]);
                written += w;
            }
        }

        if ((poll_fds[0].revents & (std.posix.POLL.ERR | std.posix.POLL.HUP)) != 0 or
            (poll_fds[1].revents & (std.posix.POLL.ERR | std.posix.POLL.HUP)) != 0)
        {
            break;
        }
    }
}
