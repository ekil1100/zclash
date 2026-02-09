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

    // 获取出口 IP 和地区信息
    std.debug.print("  Current IP/Location: ", .{});
    const ip_geo = try getIpGeoInfo(allocator);
    defer if (ip_geo) |info| {
        allocator.free(info.ip);
        if (info.city) |c| allocator.free(c);
        if (info.region) |r| allocator.free(r);
        if (info.country) |c| allocator.free(c);
        allocator.destroy(info);
    };

    if (ip_geo) |info| {
        std.debug.print("{s}", .{info.ip});
        if (info.city) |city| {
            std.debug.print(" ({s}", .{city});
            if (info.region) |region| {
                std.debug.print(", {s}", .{region});
            }
            if (info.country) |country| {
                std.debug.print(", {s}", .{country});
            }
            std.debug.print(")", .{});
        }
        std.debug.print("\n", .{});
    } else {
        std.debug.print("Failed to get IP/Location\n", .{});
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

/// IP 地理信息
const IpGeoInfo = struct {
    ip: []const u8,
    city: ?[]const u8,
    region: ?[]const u8,
    country: ?[]const u8,
};

/// 获取出口 IP 和地理位置信息
fn getIpGeoInfo(allocator: std.mem.Allocator) !?*IpGeoInfo {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    // 使用 ipapi.co/json 获取 IP 和地理位置
    var response_body = std.ArrayList(u8).empty;
    defer response_body.deinit(allocator);

    var writer_buffer: [8192]u8 = undefined;
    var adapter = response_body.writer(allocator).adaptToNewApi(&writer_buffer);

    const result = client.fetch(.{
        .location = .{ .url = "http://ipapi.co/json/" },
        .method = .GET,
        .response_writer = &adapter.new_interface,
    }) catch |err| {
        std.debug.print("({s}) ", .{@errorName(err)});
        return null;
    };

    if (result.status != .ok) {
        return null;
    }

    // 解析 JSON 响应
    const body = response_body.items;

    var info = try allocator.create(IpGeoInfo);
    info.city = null;
    info.region = null;
    info.country = null;

    // 简单解析 IP
    if (extractJsonField(allocator, body, "ip")) |ip| {
        info.ip = ip;
    } else {
        allocator.destroy(info);
        return null;
    }

    // 解析城市
    if (extractJsonField(allocator, body, "city")) |city| {
        info.city = city;
    }

    // 解析地区/省份
    if (extractJsonField(allocator, body, "region")) |region| {
        info.region = region;
    }

    // 解析国家
    if (extractJsonField(allocator, body, "country_name")) |country| {
        info.country = country;
    }

    return info;
}

/// 从 JSON 中提取字段值（简单实现）
fn extractJsonField(allocator: std.mem.Allocator, json: []const u8, field: []const u8) ?[]const u8 {
    // 查找字段: "field": "value"
    const pattern = std.fmt.allocPrint(allocator, "\"{s}\": \"", .{field}) catch return null;
    defer allocator.free(pattern);

    if (std.mem.indexOf(u8, json, pattern)) |start| {
        const value_start = start + pattern.len;
        if (std.mem.indexOfScalar(u8, json[value_start..], '"')) |end| {
            const value = json[value_start .. value_start + end];
            return allocator.dupe(u8, value) catch return null;
        }
    }

    return null;
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
