const std = @import("std");
const net = std.net;
const Engine = @import("../rule/engine.zig").Engine;
const OutboundManager = @import("outbound/manager.zig").OutboundManager;

pub fn start(allocator: std.mem.Allocator, port: u16, engine: *Engine, manager: *OutboundManager) !void {
    const address = try net.Address.parseIp4("0.0.0.0", port);
    var server = try address.listen(.{
        .reuse_address = true,
    });
    defer server.deinit();

    std.debug.print("HTTP proxy listening on port {}\n", .{port});

    while (true) {
        const conn = try server.accept();
        
        handleConnection(allocator, conn, engine, manager) catch |err| {
            std.debug.print("Connection error: {}\n", .{err});
            conn.stream.close();
        };
    }
}

fn handleConnection(_: std.mem.Allocator, conn: net.Server.Connection, engine: *Engine, manager: *OutboundManager) !void {
    defer conn.stream.close();

    var buf: [4096]u8 = undefined;
    const n = try conn.stream.read(&buf);
    if (n == 0) return;

    const request = buf[0..n];
    
    const method_end = std.mem.indexOf(u8, request, " ");
    if (method_end == null) return error.InvalidRequest;
    
    const method = request[0..method_end.?];

    if (std.mem.eql(u8, method, "CONNECT")) {
        try handleConnect(conn, request, engine, manager);
    } else {
        try handleHttp(conn, request, engine, manager);
    }
}

fn handleConnect(conn: net.Server.Connection, request: []const u8, engine: *Engine, manager: *OutboundManager) !void {
    const parts = std.mem.splitScalar(u8, request, ' ');
    var part_iter = parts;
    _ = part_iter.next();
    const target = part_iter.next();
    
    if (target == null) return error.InvalidRequest;
    
    const host_port = target.?;
    const colon_pos = std.mem.lastIndexOf(u8, host_port, ":");
    if (colon_pos == null) return error.InvalidHost;
    
    const host = host_port[0..colon_pos.?];
    const port_str = host_port[colon_pos.? + 1 ..];
    const port = try std.fmt.parseInt(u16, port_str, 10);

    std.debug.print("[HTTP] CONNECT {s}:{d}\n", .{ host, port });

    const proxy_name = engine.match(host, true) orelse "DIRECT";
    std.debug.print("[HTTP] Rule matched: {s}\n", .{proxy_name});

    var target_stream = manager.connect(proxy_name, host, port) catch |err| {
        std.debug.print("[HTTP] Connection failed: {}\n", .{err});
        try conn.stream.writeAll("HTTP/1.1 502 Bad Gateway\r\n\r\n");
        return;
    };
    defer target_stream.close();

    try conn.stream.writeAll("HTTP/1.1 200 Connection established\r\n\r\n");
    try relay(conn.stream.handle, target_stream.handle);
}

fn handleHttp(conn: net.Server.Connection, request: []const u8, engine: *Engine, manager: *OutboundManager) !void {
    const host = try extractHost(request);
    const uri = try extractUri(request);
    
    std.debug.print("[HTTP] {s} {s} (Host: {s})\n", .{ request[0..std.mem.indexOf(u8, request, " ").?], uri, host });

    const proxy_name = engine.match(host, true) orelse "DIRECT";
    std.debug.print("[HTTP] Rule matched: {s}\n", .{proxy_name});

    // Parse port from host (default 80)
    var port: u16 = 80;
    const host_to_connect = blk: {
        if (std.mem.indexOf(u8, host, ":")) |colon| {
            port = try std.fmt.parseInt(u16, host[colon + 1 ..], 10);
            break :blk host[0..colon];
        }
        break :blk host;
    };

    var target_stream = manager.connect(proxy_name, host_to_connect, port) catch |err| {
        std.debug.print("[HTTP] Connection failed: {}\n", .{err});
        try conn.stream.writeAll("HTTP/1.1 502 Bad Gateway\r\n\r\n");
        return;
    };
    defer target_stream.close();

    // Forward the request
    try target_stream.writeAll(request);

    // Relay response back
    try relay(conn.stream.handle, target_stream.handle);
}

fn extractHost(request: []const u8) ![]const u8 {
    const host_prefix = "Host: ";
    var lines = std.mem.splitSequence(u8, request, "\r\n");
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, host_prefix)) {
            return std.mem.trim(u8, line[host_prefix.len..], " \t\r\n");
        }
    }
    return error.HostNotFound;
}

fn extractUri(request: []const u8) ![]const u8 {
    const first_space = std.mem.indexOf(u8, request, " ") orelse return error.InvalidRequest;
    const second_space = std.mem.indexOf(u8, request[first_space + 1 ..], " ") orelse return error.InvalidRequest;
    return request[first_space + 1 .. first_space + 1 + second_space];
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
