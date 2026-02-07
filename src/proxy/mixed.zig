const std = @import("std");
const net = std.net;
const Engine = @import("../rule/engine.zig").Engine;
const OutboundManager = @import("outbound/manager.zig").OutboundManager;

/// 混合端口（HTTP + SOCKS5）
pub fn start(allocator: std.mem.Allocator, port: u16, engine: *Engine, manager: *OutboundManager) !void {
    const address = try net.Address.parseIp4("0.0.0.0", port);
    var server = try address.listen(.{
        .reuse_address = true,
    });
    defer server.deinit();

    std.debug.print("Mixed proxy (HTTP+SOCKS5) listening on port {}\n", .{port});

    while (true) {
        const conn = try server.accept();

        // 为每个连接创建独立任务
        const conn_allocator = allocator;
        handleConnection(conn_allocator, conn, engine, manager) catch |err| {
            std.debug.print("Mixed connection error: {}\n", .{err});
            conn.stream.close();
        };
    }
}

fn handleConnection(allocator: std.mem.Allocator, conn: net.Server.Connection, engine: *Engine, manager: *OutboundManager) !void {
    // 读取第一个字节来判断协议类型
    var first_byte: [1]u8 = undefined;
    const n = try conn.stream.read(&first_byte);
    if (n == 0) {
        conn.stream.close();
        return;
    }

    // 判断协议类型
    if (first_byte[0] == 0x05) {
        // SOCKS5 协议
        std.debug.print("[Mixed] Detected SOCKS5 connection\n", .{});
        try handleSocks5(allocator, conn, first_byte[0], engine, manager);
    } else if (first_byte[0] == 0x04) {
        // SOCKS4 协议（暂不支持，按 SOCKS5 处理）
        std.debug.print("[Mixed] Detected SOCKS4 connection (not supported)\n", .{});
        conn.stream.close();
    } else {
        // HTTP/HTTPS 代理（第一个字节是可打印字符如 'C', 'G', 'P', 'H' 等）
        std.debug.print("[Mixed] Detected HTTP connection\n", .{});
        try handleHttp(allocator, conn, first_byte[0], engine, manager);
    }
}

fn handleSocks5(allocator: std.mem.Allocator, conn: net.Server.Connection, first_byte: u8, engine: *Engine, manager: *OutboundManager) !void {
    _ = allocator;
    _ = first_byte;
    // SOCKS5 实现 - 简化版，完整实现需要更多代码
    // 这里暂时关闭连接，提示使用专用 SOCKS5 端口
    std.debug.print("[Mixed] SOCKS5 on mixed port not fully implemented yet, use port 7891\n", .{});
    _ = try conn.stream.write("HTTP/1.1 400 Bad Request\r\n\r\n");
    conn.stream.close();
    _ = engine;
    _ = manager;
}

fn handleHttp(allocator: std.mem.Allocator, conn: net.Server.Connection, first_byte: u8, engine: *Engine, manager: *OutboundManager) !void {
    // 读取完整请求
    var buf: [4096]u8 = undefined;
    buf[0] = first_byte;
    const n = try conn.stream.read(buf[1..]);
    if (n == 0) {
        conn.stream.close();
        return;
    }
    const request = buf[0 .. n + 1];

    // 查找 HTTP 方法
    const method_end = std.mem.indexOf(u8, request, " ");
    if (method_end == null) {
        conn.stream.close();
        return;
    }
    const method = request[0..method_end.?];

    if (std.mem.eql(u8, method, "CONNECT")) {
        try handleHttpConnect(allocator, conn, request, engine, manager);
    } else {
        try handleHttpRequest(allocator, conn, request, engine, manager);
    }
}

fn handleHttpConnect(_: std.mem.Allocator, conn: net.Server.Connection, request: []const u8, engine: *Engine, manager: *OutboundManager) !void {
    // 解析 CONNECT 请求
    const parts = std.mem.splitScalar(u8, request, ' ');
    var part_iter = parts;
    _ = part_iter.next(); // "CONNECT"
    const target = part_iter.next();

    if (target == null) {
        conn.stream.close();
        return;
    }

    const host_port = target.?;
    const colon_pos = std.mem.lastIndexOf(u8, host_port, ":");
    if (colon_pos == null) {
        conn.stream.close();
        return;
    }

    const host = host_port[0..colon_pos.?];
    const port_str = host_port[colon_pos.? + 1 ..];
    const port = std.fmt.parseInt(u16, port_str, 10) catch {
        conn.stream.close();
        return;
    };

    std.debug.print("[Mixed] CONNECT {s}:{d}\n", .{ host, port });

    // 通过 outbound manager 连接
    const proxy_name = engine.match(host, true) orelse "DIRECT";
    var target_stream = manager.connect(proxy_name, host, port) catch |err| {
        std.debug.print("[Mixed] Connection failed: {}\n", .{err});
        _ = try conn.stream.write("HTTP/1.1 502 Bad Gateway\r\n\r\n");
        conn.stream.close();
        return;
    };
    defer target_stream.close();

    // 发送成功响应
    _ = try conn.stream.write("HTTP/1.1 200 Connection established\r\n\r\n");

    // 双向转发
    try relay(conn.stream, target_stream);
}

fn handleHttpRequest(allocator: std.mem.Allocator, conn: net.Server.Connection, request: []const u8, engine: *Engine, manager: *OutboundManager) !void {
    // 解析目标 host
    const host = extractHost(request) catch {
        conn.stream.close();
        return;
    };
    const port: u16 = 80;

    std.debug.print("[Mixed] HTTP {s}:{d}\n", .{ host, port });

    // 连接目标
    const proxy_name = engine.match(host, true) orelse "DIRECT";
    var target_stream = manager.connect(proxy_name, host, port) catch |err| {
        std.debug.print("[Mixed] Connection failed: {}\n", .{err});
        _ = try conn.stream.write("HTTP/1.1 502 Bad Gateway\r\n\r\n");
        conn.stream.close();
        return;
    };
    defer target_stream.close();

    // 转发请求
    _ = try target_stream.write(request);

    // 读取响应并返回
    var buf: [4096]u8 = undefined;
    while (true) {
        const n = try target_stream.read(&buf);
        if (n == 0) break;
        _ = try conn.stream.write(buf[0..n]);
    }

    conn.stream.close();
    _ = allocator;
}

fn extractHost(request: []const u8) ![]const u8 {
    const host_prefix = "Host: ";
    const host_start = std.mem.indexOf(u8, request, host_prefix);
    if (host_start == null) return error.NoHost;

    const after_host = host_start.? + host_prefix.len;
    const host_end = std.mem.indexOf(u8, request[after_host..], "\r\n");
    if (host_end == null) return error.NoHost;

    return request[after_host .. after_host + host_end.?];
}

fn relay(client_stream: net.Stream, target_stream: net.Stream) !void {
    // 简化的双向转发
    var buf: [4096]u8 = undefined;

    // 客户端 -> 目标
    while (true) {
        const n = client_stream.read(&buf) catch break;
        if (n == 0) break;
        _ = target_stream.write(buf[0..n]) catch break;
    }

    client_stream.close();
}
