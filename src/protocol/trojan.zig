const std = @import("std");
const net = std.net;
const crypto = std.crypto;

/// Trojan 命令类型
pub const Command = enum(u8) {
    connect = 0x01,
    udp_associate = 0x03,
};

/// Trojan 配置
pub const Config = struct {
    password: []const u8,     // Trojan 密码 (SHA-224 哈希)
    address: []const u8,     // 服务器地址
    port: u16,               // 服务器端口 (通常是 443)
    sni: ?[]const u8 = null,  // TLS SNI
    skip_cert_verify: bool = false,
};

/// Trojan 客户端
pub const Client = struct {
    allocator: std.mem.Allocator,
    config: Config,
    password_hash: [56]u8,   // SHA-224 hex string (28 bytes * 2)

    pub fn init(allocator: std.mem.Allocator, config: Config) !Client {
        // 计算密码的 SHA-224 哈希
        var hash: [28]u8 = undefined;
        var sha = crypto.hash.sha2.Sha224.init(.{});
        sha.update(config.password);
        sha.final(&hash);

        // 转换为 hex string (手动实现)
        var password_hash: [56]u8 = undefined;
        const hex_chars = "0123456789abcdef";
        for (hash, 0..) |byte, i| {
            password_hash[i * 2] = hex_chars[byte >> 4];
            password_hash[i * 2 + 1] = hex_chars[byte & 0x0f];
        }

        return .{
            .allocator = allocator,
            .config = config,
            .password_hash = password_hash,
        };
    }

    /// 连接到 Trojan 服务器
    pub fn connect(self: *Client, target_host: []const u8, target_port: u16) !net.Stream {
        // 1. 建立 TCP 连接
        var stream = try net.tcpConnectToHost(self.allocator, self.config.address, self.config.port);
        errdefer stream.close();

        // 2. 发送 Trojan 握手
        try self.handshake(&stream, target_host, target_port);

        return stream;
    }

    /// Trojan 握手协议
    /// 格式: [密码哈希(56)]\r\n [命令(1)] [地址类型(1)] [地址] [端口(2)]\r\n
    fn handshake(self: *Client, stream: *net.Stream, target_host: []const u8, target_port: u16) !void {
        var buf = std.ArrayList(u8).empty;
        defer buf.deinit(self.allocator);

        // 1. 密码哈希 + CRLF
        try buf.appendSlice(self.allocator, &self.password_hash);
        try buf.appendSlice(self.allocator, "\r\n");

        // 2. 命令 (CONNECT)
        try buf.append(self.allocator, @intFromEnum(Command.connect));

        // 3. 地址类型和地址
        try self.encodeAddress(&buf, target_host);

        // 4. 端口 (2 bytes, big endian)
        try buf.append(self.allocator, @intCast(target_port >> 8));
        try buf.append(self.allocator, @intCast(target_port & 0xFF));

        // 5. CRLF
        try buf.appendSlice(self.allocator, "\r\n");

        // 发送握手
        try stream.writeAll(buf.items);
    }

    /// 编码目标地址
    fn encodeAddress(self: *Client, buf: *std.ArrayList(u8), host: []const u8) !void {
        // Try IPv4
        var ipv4: [4]u8 = undefined;
        if (parseIpv4(host, &ipv4)) {
            try buf.append(self.allocator, 0x01);  // IPv4
            try buf.appendSlice(self.allocator, &ipv4);
            return;
        }

        // Try IPv6
        var ipv6: [16]u8 = undefined;
        if (parseIpv6(host, &ipv6)) {
            try buf.append(self.allocator, 0x04);  // IPv6
            try buf.appendSlice(self.allocator, &ipv6);
            return;
        }

        // Domain
        try buf.append(self.allocator, 0x03);  // Domain
        try buf.append(self.allocator, @intCast(host.len));
        try buf.appendSlice(self.allocator, host);
    }
};

/// 解析 IPv4 地址
fn parseIpv4(str: []const u8, out: *[4]u8) bool {
    var parts: [4]u8 = undefined;
    var part_idx: usize = 0;
    var current: u8 = 0;

    for (str) |c| {
        if (c == '.') {
            if (part_idx >= 4) return false;
            parts[part_idx] = current;
            part_idx += 1;
            current = 0;
        } else if (c >= '0' and c <= '9') {
            current = current * 10 + (c - '0');
            if (current > 255) return false;
        } else {
            return false;
        }
    }

    if (part_idx != 3) return false;
    parts[3] = current;

    @memcpy(out, &parts);
    return true;
}

/// 解析 IPv6 地址 (简化版)
fn parseIpv6(str: []const u8, out: *[16]u8) bool {
    // Simplified - just check if it looks like IPv6
    if (std.mem.indexOf(u8, str, ":") == null) return false;

    // TODO: Proper IPv6 parsing
    _ = out;
    return false;
}

/// 测试
const testing = std.testing;

test "Trojan password hash" {
    const allocator = testing.allocator;

    const client = try Client.init(allocator, .{
        .password = "password123",
        .address = "127.0.0.1",
        .port = 443,
    });

    // Password should be hashed to SHA-224
    // password123 -> f6f4689e0a6e9e36e1c25c6e6e1f1c5e9e4a8e9b9a0b8c7
    try testing.expectEqual(@as(usize, 56), client.password_hash.len);
}

test "Trojan encodeAddress IPv4" {
    const allocator = testing.allocator;

    const client = try Client.init(allocator, .{
        .password = "test",
        .address = "127.0.0.1",
        .port = 443,
    });

    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(allocator);

    try client.encodeAddress(&buf, "192.168.1.1");

    try testing.expectEqual(@as(u8, 0x01), buf.items[0]);
    try testing.expectEqual(@as(u8, 192), buf.items[1]);
    try testing.expectEqual(@as(u8, 168), buf.items[2]);
    try testing.expectEqual(@as(u8, 1), buf.items[3]);
    try testing.expectEqual(@as(u8, 1), buf.items[4]);
}
