const std = @import("std");
const config = @import("config.zig");

/// 测试目标网站列表
const TEST_TARGETS = [_]struct {
    name: []const u8,
    url: []const u8,
}{
    .{ .name = "IP/Location", .url = "http://httpbin.org/ip" },
    .{ .name = "Google", .url = "http://www.google.com/generate_204" },
    .{ .name = "YouTube", .url = "http://www.youtube.com/generate_204" },
    .{ .name = "Netflix", .url = "http://www.netflix.com" },
    .{ .name = "OpenAI", .url = "http://chat.openai.com" },
    .{ .name = "GitHub", .url = "http://github.com" },
    .{ .name = "Cloudflare", .url = "http://1.1.1.1" },
};

/// 网络连接性测试
pub fn testProxy(allocator: std.mem.Allocator, cfg: *const config.Config, proxy_name: ?[]const u8) !void {
    _ = proxy_name;

    std.debug.print("Network Connectivity Test\n", .{});
    std.debug.print("{s:-^60}\n", .{""});

    // 测试 HTTP 代理
    if (cfg.port > 0) {
        std.debug.print("\nTesting via HTTP Proxy (127.0.0.1:{d}):\n", .{cfg.port});
        try testViaProxy(allocator, cfg.port, .http);
    }

    // 测试 SOCKS5 代理
    if (cfg.socks_port > 0) {
        std.debug.print("\nTesting via SOCKS5 Proxy (127.0.0.1:{d}):\n", .{cfg.socks_port});
        try testViaProxy(allocator, cfg.socks_port, .socks5);
    }

    // 测试混合端口
    if (cfg.mixed_port > 0) {
        std.debug.print("\nTesting via Mixed Proxy (127.0.0.1:{d}):\n", .{cfg.mixed_port});
        try testViaProxy(allocator, cfg.mixed_port, .http);
    }

    std.debug.print("\n", .{});
}

const ProxyType = enum {
    http,
    socks5,
};

/// 通过代理测试连接
fn testViaProxy(allocator: std.mem.Allocator, port: u16, proxy_type: ProxyType) !void {
    _ = proxy_type;

    // 首先获取出口 IP
    std.debug.print("  Current IP: ", .{});
    const ip_info = try getIpInfo(allocator, port);
    defer if (ip_info) |info| allocator.free(info);

    if (ip_info) |info| {
        std.debug.print("{s}\n", .{info});
    } else {
        std.debug.print("Failed to get IP\n", .{});
    }

    std.debug.print("\n  Latency Test:\n", .{});
    std.debug.print("  {s:-^50}\n", .{""});

    // 测试各个目标
    for (TEST_TARGETS[1..]) |target| { // 跳过第一个（IP 已经测过）
        std.debug.print("  {s:12} ", .{target.name});

        const latency = try testUrlLatency(allocator, target.url, port);

        if (latency) |ms| {
            const color = if (ms < 100) "🟢" else if (ms < 300) "🟡" else "🔴";
            std.debug.print("{s} {d}ms\n", .{ color, ms });
        } else {
            std.debug.print("⚫ Timeout/Failed\n", .{});
        }
    }
}

/// 获取出口 IP 信息
fn getIpInfo(allocator: std.mem.Allocator, proxy_port: u16) !?[]const u8 {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    // 构建代理 URL
    const proxy_url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{proxy_port});
    defer allocator.free(proxy_url);

    // 使用 httpbin.org/ip 获取出口 IP
    var response_body = std.ArrayList(u8).empty;
    defer response_body.deinit(allocator);

    var writer_buffer: [8192]u8 = undefined;
    var adapter = response_body.writer(allocator).adaptToNewApi(&writer_buffer);

    const result = client.fetch(.{
        .location = .{ .url = "http://httpbin.org/ip" },
        .method = .GET,
        .response_writer = &adapter.new_interface,
    }) catch |err| {
        std.debug.print("({s}) ", .{@errorName(err)});
        return null;
    };

    if (result.status != .ok) {
        return null;
    }

    // 解析返回的 JSON {"origin": "xxx.xxx.xxx.xxx"}
    const body = response_body.items;
    const prefix = "{\"origin\": \"";
    const suffix = "\"}";

    if (std.mem.startsWith(u8, body, prefix) and std.mem.endsWith(u8, body, suffix)) {
        const ip_start = prefix.len;
        const ip_end = body.len - suffix.len;
        const ip = body[ip_start..ip_end];
        return try allocator.dupe(u8, ip);
    }

    return try allocator.dupe(u8, body);
}

/// 测试 URL 延迟
fn testUrlLatency(allocator: std.mem.Allocator, url: []const u8, _proxy_port: u16) !?u64 {
    _ = _proxy_port;
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    // 记录开始时间
    const start_time = std.time.milliTimestamp();

    // 使用较小的超时进行测试
    var response_body = std.ArrayList(u8).empty;
    defer response_body.deinit(allocator);

    var writer_buffer: [1024]u8 = undefined;
    var adapter = response_body.writer(allocator).adaptToNewApi(&writer_buffer);

    const result = client.fetch(.{
        .location = .{ .url = url },
        .method = .GET,
        .response_writer = &adapter.new_interface,
    }) catch {
        return null;
    };

    const end_time = std.time.milliTimestamp();

    // 只要收到响应（包括 204 No Content）就算成功
    if (result.status == .ok or result.status == .no_content or @intFromEnum(result.status) < 400) {
        return @intCast(end_time - start_time);
    }

    return null;
}
