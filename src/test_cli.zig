const std = @import("std");
const config = @import("config.zig");

/// 测试代理连接
pub fn testProxy(allocator: std.mem.Allocator, cfg: *const config.Config, proxy_name: ?[]const u8) !void {
    _ = allocator;

    std.debug.print("Testing zclash proxy connection...\n\n", .{});

    // 测试 HTTP 代理端口
    if (cfg.port > 0) {
        std.debug.print("HTTP Proxy (port {d}): ", .{cfg.port});
        const http_ok = try testHttpProxy(cfg.port);
        if (http_ok) {
            std.debug.print("✓ OK\n", .{});
        } else {
            std.debug.print("✗ Failed\n", .{});
        }
    }

    // 测试 SOCKS5 代理端口
    if (cfg.socks_port > 0) {
        std.debug.print("SOCKS5 Proxy (port {d}): ", .{cfg.socks_port});
        const socks_ok = try testSocks5Proxy(cfg.socks_port);
        if (socks_ok) {
            std.debug.print("✓ OK\n", .{});
        } else {
            std.debug.print("✗ Failed\n", .{});
        }
    }

    // 测试混合端口
    if (cfg.mixed_port > 0) {
        std.debug.print("Mixed Proxy (port {d}): ", .{cfg.mixed_port});
        const mixed_ok = try testHttpProxy(cfg.mixed_port);
        if (mixed_ok) {
            std.debug.print("✓ OK (HTTP mode)\n", .{});
        } else {
            std.debug.print("✗ Failed\n", .{});
        }
    }

    // 如果指定了代理名称，测试该代理节点
    if (proxy_name) |pn| {
        std.debug.print("\nTesting proxy node '{s}': ", .{pn});
        // 这里可以实现实际的节点延迟测试
        // 目前只是显示信息
        std.debug.print("(Use 'zclash tui' and press 't' to test latency)\n", .{});
    }

    std.debug.print("\n", .{});
}

/// 测试 HTTP 代理端口是否可连接
fn testHttpProxy(port: u16) !bool {
    const addr = std.net.Address.parseIp4("127.0.0.1", port) catch return false;

    const stream = std.net.tcpConnectToAddress(addr) catch |err| {
        std.debug.print("({s}) ", .{@errorName(err)});
        return false;
    };
    defer stream.close();

    // 发送一个简单的 HTTP CONNECT 请求测试
    const request = "CONNECT httpbin.org:443 HTTP/1.1\r\nHost: httpbin.org:443\r\n\r\n";
    _ = stream.write(request) catch |err| {
        std.debug.print("({s}) ", .{@errorName(err)});
        return false;
    };

    // 读取响应
    var buf: [256]u8 = undefined;
    const n = stream.read(&buf) catch |err| {
        std.debug.print("({s}) ", .{@errorName(err)});
        return false;
    };

    if (n == 0) return false;

    // 检查响应是否以 HTTP/1.1 开头
    const response = buf[0..n];
    return std.mem.startsWith(u8, response, "HTTP/1.1");
}

/// 测试 SOCKS5 代理端口是否可连接
fn testSocks5Proxy(port: u16) !bool {
    const addr = std.net.Address.parseIp4("127.0.0.1", port) catch return false;

    const stream = std.net.tcpConnectToAddress(addr) catch |err| {
        std.debug.print("({s}) ", .{@errorName(err)});
        return false;
    };
    defer stream.close();

    // SOCKS5 握手：无认证
    const handshake = [_]u8{ 0x05, 0x01, 0x00 }; // VER, NMETHODS, METHODS
    _ = stream.write(&handshake) catch |err| {
        std.debug.print("({s}) ", .{@errorName(err)});
        return false;
    };

    // 读取响应
    var buf: [2]u8 = undefined;
    const n = stream.read(&buf) catch |err| {
        std.debug.print("({s}) ", .{@errorName(err)});
        return false;
    };

    if (n < 2) return false;

    // 检查 SOCKS5 响应
    return buf[0] == 0x05 and buf[1] == 0x00;
}
