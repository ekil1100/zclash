const std = @import("std");
const net = std.net;
const crypto = std.crypto;

/// VMess 协议版本
pub const Version = enum(u8) {
    v0 = 0x00,
};

/// VMess 命令类型
pub const Command = enum(u8) {
    tcp = 0x01,
    udp = 0x02,
    mux = 0x03,
};

/// VMess 地址类型
pub const AddressType = enum(u8) {
    ipv4 = 0x01,
    domain = 0x02,
    ipv6 = 0x03,
};

/// VMess 安全类型
pub const Security = enum(u8) {
    unknown = 0x00,
    aes_128_gcm = 0x02,
    chacha20_poly1305 = 0x03,
    none = 0x05,
    auto = 0x06,
};

/// VMess 配置
pub const Config = struct {
    id: []const u8,          // UUID
    address: []const u8,     // 服务器地址
    port: u16,               // 服务器端口
    security: Security = .auto,
    alter_id: u16 = 0,       // AlterID (已废弃，保持为0)
};

/// VMess 客户端
pub const Client = struct {
    allocator: std.mem.Allocator,
    config: Config,
    uuid: [16]u8,

    pub fn init(allocator: std.mem.Allocator, config: Config) !Client {
        // 解析 UUID
        var uuid: [16]u8 = undefined;
        try parseUuid(config.id, &uuid);

        return .{
            .allocator = allocator,
            .config = config,
            .uuid = uuid,
        };
    }

    /// 连接到 VMess 服务器
    pub fn connect(self: *Client, target_host: []const u8, target_port: u16) !net.Stream {
        // 1. 建立 TCP 连接
        var stream = try net.tcpConnectToHost(self.allocator, self.config.address, self.config.port);
        errdefer stream.close();

        // 2. 发送 VMess 握手
        try self.handshake(&stream, target_host, target_port);

        return stream;
    }

    /// VMess 握手
    fn handshake(self: *Client, stream: *net.Stream, target_host: []const u8, target_port: u16) !void {
        // 生成请求密钥和 IV
        var request_key: [16]u8 = undefined;
        var request_iv: [16]u8 = undefined;
        crypto.random.bytes(&request_key);
        crypto.random.bytes(&request_iv);

        // 生成响应密钥和 IV (基于请求密钥/IV)
        var response_key: [16]u8 = undefined;
        var response_iv: [16]u8 = undefined;
        deriveResponseKeyIv(&request_key, &request_iv, &response_key, &response_iv);

        // 构建请求头
        var header = std.ArrayList(u8).empty;
        defer header.deinit(self.allocator);

        // Version
        try header.append(self.allocator, @intFromEnum(Version.v0));

        // UUID (16 bytes)
        try header.appendSlice(self.allocator, &self.uuid);

        // Timestamp (8 bytes, big endian)
        const timestamp = @as(u64, @intCast(std.time.timestamp()));
        const ts_bytes = std.mem.toBytes(timestamp);
        try header.appendSlice(self.allocator, &ts_bytes);

        // Command (TCP)
        try header.append(self.allocator, @intFromEnum(Command.tcp));

        // Port (2 bytes, big endian)
        try header.append(self.allocator, @intCast(target_port >> 8));
        try header.append(self.allocator, @intCast(target_port & 0xFF));

        // Address type and address
        try self.encodeAddress(&header, target_host);

        // Security type
        const security = self.selectSecurity();
        try header.append(self.allocator, @intFromEnum(security));

        // Reserved byte
        try header.append(self.allocator, 0x00);

        // Generate command key and IV
        var cmd_key: [16]u8 = undefined;
        var cmd_iv: [16]u8 = undefined;
        deriveCommandKeyIv(&request_key, &request_iv, &cmd_key, &cmd_iv);

        // Encrypt header
        const encrypted_header = try self.encryptHeader(header.items, &cmd_key, &cmd_iv);
        defer self.allocator.free(encrypted_header);

        // Build authentication header (16 bytes)
        var auth: [16]u8 = undefined;
        crypto.random.bytes(&auth);

        // Send: auth(16) + encrypted_length(2) + encrypted_header
        // For simplicity, we use no encryption for length (legacy mode)
        const header_len = @as(u16, @intCast(encrypted_header.len));
        
        try stream.writeAll(&auth);
        try stream.writeAll(&[_]u8{
            @intCast(header_len >> 8),
            @intCast(header_len & 0xFF),
        });
        try stream.writeAll(encrypted_header);
    }

    /// 编码目标地址
    fn encodeAddress(self: *Client, buf: *std.ArrayList(u8), host: []const u8) !void {
        // Try IPv4
        var ipv4: [4]u8 = undefined;
        if (parseIpv4(host, &ipv4)) {
            try buf.append(self.allocator, @intFromEnum(AddressType.ipv4));
            try buf.appendSlice(self.allocator, &ipv4);
            return;
        }

        // Try IPv6
        var ipv6: [16]u8 = undefined;
        if (parseIpv6(host, &ipv6)) {
            try buf.append(self.allocator, @intFromEnum(AddressType.ipv6));
            try buf.appendSlice(self.allocator, &ipv6);
            return;
        }

        // Domain
        try buf.append(self.allocator, @intFromEnum(AddressType.domain));
        try buf.append(self.allocator, @intCast(host.len));
        try buf.appendSlice(self.allocator, host);
    }

    /// 选择加密方式
    fn selectSecurity(self: *Client) Security {
        return switch (self.config.security) {
            .auto => if (crypto.core.aes.has_hardware_support)
                .aes_128_gcm
            else
                .chacha20_poly1305,
            else => self.config.security,
        };
    }

    /// 加密请求头 (使用 AES-128-CFB)
    fn encryptHeader(self: *Client, data: []const u8, key: *[16]u8, iv: *[16]u8) ![]u8 {
        // For simplicity, use AES-128-CFB (VMess legacy)
        // In production, should use proper AEAD
        const encrypted = try self.allocator.alloc(u8, data.len);
        
        // Simple XOR for now (placeholder - should use proper AES-CFB)
        var xor_key: [16]u8 = undefined;
        for (0..16) |i| {
            xor_key[i] = key[i] ^ iv[i];
        }
        
        for (data, 0..) |byte, i| {
            encrypted[i] = byte ^ xor_key[i % 16];
        }
        
        return encrypted;
    }

    /// 发送数据 (加密)
    pub fn send(self: *Client, stream: *net.Stream, data: []const u8) !void {
        _ = self;
        // TODO: Implement proper encryption based on security type
        try stream.writeAll(data);
    }

    /// 接收数据 (解密)
    pub fn recv(self: *Client, stream: *net.Stream, buf: []u8) !usize {
        _ = self;
        // TODO: Implement proper decryption
        return try stream.read(buf);
    }
};

/// 解析 UUID 字符串 (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
fn parseUuid(str: []const u8, out: *[16]u8) !void {
    if (str.len != 36) return error.InvalidUuid;
    
    var idx: usize = 0;
    var out_idx: usize = 0;
    
    while (idx < str.len and out_idx < 16) {
        if (str[idx] == '-') {
            idx += 1;
            continue;
        }
        
        const high = try hexDigit(str[idx]);
        const low = try hexDigit(str[idx + 1]);
        out[out_idx] = (high << 4) | low;
        
        idx += 2;
        out_idx += 1;
    }
}

fn hexDigit(c: u8) !u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'a'...'f' => c - 'a' + 10,
        'A'...'F' => c - 'A' + 10,
        else => error.InvalidHex,
    };
}

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

/// 派生响应密钥和 IV
fn deriveResponseKeyIv(req_key: *[16]u8, req_iv: *[16]u8, resp_key: *[16]u8, resp_iv: *[16]u8) void {
    // VMess uses MD5(req_key) for response_key and MD5(req_iv) for response_iv
    // Simplified version:
    for (0..16) |i| {
        resp_key[i] = req_key[i] ^ 0x5A;
        resp_iv[i] = req_iv[i] ^ 0x5A;
    }
}

/// 派生命令密钥和 IV
fn deriveCommandKeyIv(req_key: *[16]u8, req_iv: *[16]u8, cmd_key: *[16]u8, cmd_iv: *[16]u8) void {
    // Similar to response derivation but different constant
    for (0..16) |i| {
        cmd_key[i] = req_key[i] ^ 0xA5;
        cmd_iv[i] = req_iv[i] ^ 0xA5;
    }
}
