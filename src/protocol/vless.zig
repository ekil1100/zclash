const std = @import("std");
const net = std.net;

/// VLESS 命令类型
pub const Command = enum(u8) {
    tcp = 0x01,
    udp = 0x02,
    mux = 0x03,
};

/// VLESS 配置
pub const Config = struct {
    id: []const u8,       // UUID
    address: []const u8,  // 服务器地址
    port: u16,            // 服务器端口
};

/// VLESS 客户端（最小可用版本，仅 TCP）
pub const Client = struct {
    allocator: std.mem.Allocator,
    config: Config,
    uuid: [16]u8,

    pub fn init(allocator: std.mem.Allocator, config: Config) !Client {
        var uuid: [16]u8 = undefined;
        try parseUuid(config.id, &uuid);

        return .{
            .allocator = allocator,
            .config = config,
            .uuid = uuid,
        };
    }

    pub fn connect(self: *Client, target_host: []const u8, target_port: u16) !net.Stream {
        var stream = try net.tcpConnectToHost(self.allocator, self.config.address, self.config.port);
        errdefer stream.close();

        try self.handshake(&stream, target_host, target_port);
        return stream;
    }

    /// VLESS request:
    /// [version(1)] [uuid(16)] [addon_len(1)] [command(1)] [port(2)] [addr_type(1)] [addr]
    fn handshake(self: *Client, stream: *net.Stream, target_host: []const u8, target_port: u16) !void {
        var buf = std.ArrayList(u8).empty;
        defer buf.deinit(self.allocator);

        // Version
        try buf.append(self.allocator, 0x00);

        // UUID
        try buf.appendSlice(self.allocator, &self.uuid);

        // Addons length (none)
        try buf.append(self.allocator, 0x00);

        // Command: TCP
        try buf.append(self.allocator, @intFromEnum(Command.tcp));

        // Port (big endian)
        try buf.append(self.allocator, @intCast(target_port >> 8));
        try buf.append(self.allocator, @intCast(target_port & 0xFF));

        // Address
        try self.encodeAddress(&buf, target_host);

        try stream.writeAll(buf.items);
    }

    fn encodeAddress(self: *Client, buf: *std.ArrayList(u8), host: []const u8) !void {
        var ipv4: [4]u8 = undefined;
        if (parseIpv4(host, &ipv4)) {
            try buf.append(self.allocator, 0x01); // IPv4
            try buf.appendSlice(self.allocator, &ipv4);
            return;
        }

        var ipv6: [16]u8 = undefined;
        if (parseIpv6(host, &ipv6)) {
            try buf.append(self.allocator, 0x03); // IPv6
            try buf.appendSlice(self.allocator, &ipv6);
            return;
        }

        try buf.append(self.allocator, 0x02); // Domain
        try buf.append(self.allocator, @intCast(host.len));
        try buf.appendSlice(self.allocator, host);
    }
};

fn parseUuid(str: []const u8, out: *[16]u8) !void {
    if (str.len != 36) return error.InvalidUuid;

    var idx: usize = 0;
    var out_idx: usize = 0;

    while (idx < str.len and out_idx < 16) {
        if (str[idx] == '-') {
            idx += 1;
            continue;
        }

        if (idx + 1 >= str.len) return error.InvalidUuid;
        const high = try hexDigit(str[idx]);
        const low = try hexDigit(str[idx + 1]);
        out[out_idx] = (high << 4) | low;

        idx += 2;
        out_idx += 1;
    }

    if (out_idx != 16) return error.InvalidUuid;
}

fn hexDigit(c: u8) !u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'a'...'f' => c - 'a' + 10,
        'A'...'F' => c - 'A' + 10,
        else => error.InvalidHex,
    };
}

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

fn parseIpv6(str: []const u8, out: *[16]u8) bool {
    // 最小版本：先不做完整 IPv6 解析，避免误判
    _ = str;
    _ = out;
    return false;
}

const testing = std.testing;

test "VLESS init parses uuid" {
    const allocator = testing.allocator;

    const client = try Client.init(allocator, .{
        .id = "123e4567-e89b-12d3-a456-426614174000",
        .address = "127.0.0.1",
        .port = 443,
    });

    try testing.expectEqual(@as(usize, 16), client.uuid.len);
    try testing.expectEqual(@as(u8, 0x12), client.uuid[0]);
    try testing.expectEqual(@as(u8, 0x00), client.uuid[15]);
}

test "VLESS rejects invalid uuid" {
    const allocator = testing.allocator;
    try testing.expectError(error.InvalidUuid, Client.init(allocator, .{
        .id = "invalid-uuid",
        .address = "127.0.0.1",
        .port = 443,
    }));
}

test "VLESS encodeAddress IPv4" {
    const allocator = testing.allocator;

    const client = try Client.init(allocator, .{
        .id = "123e4567-e89b-12d3-a456-426614174000",
        .address = "127.0.0.1",
        .port = 443,
    });

    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(allocator);

    try client.encodeAddress(&buf, "8.8.8.8");

    try testing.expectEqual(@as(u8, 0x01), buf.items[0]);
    try testing.expectEqual(@as(u8, 8), buf.items[1]);
    try testing.expectEqual(@as(u8, 8), buf.items[2]);
    try testing.expectEqual(@as(u8, 8), buf.items[3]);
    try testing.expectEqual(@as(u8, 8), buf.items[4]);
}

test "VLESS encodeAddress domain" {
    const allocator = testing.allocator;

    const client = try Client.init(allocator, .{
        .id = "123e4567-e89b-12d3-a456-426614174000",
        .address = "127.0.0.1",
        .port = 443,
    });

    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(allocator);

    try client.encodeAddress(&buf, "example.com");

    try testing.expectEqual(@as(u8, 0x02), buf.items[0]);
    try testing.expectEqual(@as(u8, 11), buf.items[1]);
    try testing.expectEqualStrings("example.com", buf.items[2..]);
}
