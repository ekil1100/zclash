const std = @import("std");
const net = std.net;
const aead = @import("../../crypto/aead.zig");
pub const Address = aead.Address;

/// Shadowsocks 出站连接（AEAD 加密版）
pub const ShadowsocksClient = struct {
    allocator: std.mem.Allocator,
    server: []const u8,
    port: u16,
    password: []const u8,
    cipher_type: aead.CipherType,
    
    // Session state
    stream: ?net.Stream = null,
    stream_ctx: ?aead.AeadStream = null,

    pub fn init(allocator: std.mem.Allocator, server: []const u8, port: u16, password: []const u8, cipher: []const u8) !ShadowsocksClient {
        const cipher_type = aead.parseCipherType(cipher) orelse return error.UnsupportedCipher;
        
        return ShadowsocksClient{
            .allocator = allocator,
            .server = try allocator.dupe(u8, server),
            .port = port,
            .password = try allocator.dupe(u8, password),
            .cipher_type = cipher_type,
        };
    }

    pub fn deinit(self: *ShadowsocksClient) void {
        self.allocator.free(self.server);
        self.allocator.free(self.password);
        if (self.stream) |s| s.close();
    }

    /// 连接到 Shadowsocks 服务器并发送目标地址
    pub fn connect(self: *ShadowsocksClient, target: Address) !net.Stream {
        // 1. 解析服务器地址
        var addr_list = try net.getAddressList(self.allocator, self.server, self.port);
        defer addr_list.deinit();
        
        if (addr_list.addrs.len == 0) {
            return error.HostNotFound;
        }

        // 2. 建立 TCP 连接
        var stream = try net.tcpConnectToAddress(addr_list.addrs[0]);
        
        // 3. Shadowsocks AEAD 握手
        // 生成随机 salt (32 bytes for AEAD)
        var salt: [32]u8 = undefined;
        std.crypto.random.bytes(&salt);
        
        // 发送 salt
        try stream.writeAll(&salt);
        
        // 4. 初始化加密流
        self.stream_ctx = try aead.AeadStream.init(self.cipher_type, self.password, &salt);
        
        // 5. 编码目标地址
        var addr_buf: [260]u8 = undefined;
        const addr_len = try target.encode(&addr_buf);
        
        // 6. 加密并发送目标地址
        var enc_buf: [300]u8 = undefined;
        const enc_len = try self.stream_ctx.?.encryptChunk(addr_buf[0..addr_len], &enc_buf);
        try stream.writeAll(enc_buf[0..enc_len]);
        
        self.stream = stream;
        return stream;
    }

    /// 加密并发送数据
    pub fn write(self: *ShadowsocksClient, data: []const u8) !void {
        const stream = self.stream orelse return error.NotConnected;
        var ctx = &self.stream_ctx.?;
        
        // 分块发送（Shadowsocks 使用 16KB chunks）
        const max_chunk = 16384;
        var offset: usize = 0;
        
        while (offset < data.len) {
            const chunk_len = @min(max_chunk, data.len - offset);
            const chunk = data[offset..offset + chunk_len];
            
            var enc_buf: [max_chunk + 50]u8 = undefined;
            const enc_len = try ctx.encryptChunk(chunk, &enc_buf);
            try stream.writeAll(enc_buf[0..enc_len]);
            
            offset += chunk_len;
        }
    }

    /// 接收并解密数据
    pub fn read(self: *ShadowsocksClient, buf: []u8) !usize {
        const stream = self.stream orelse return error.NotConnected;
        var ctx = &self.stream_ctx.?;
        
        const tag_len = ctx.cipher.tagLen();
        
        // 读取长度头 (2 bytes + tag)
        var len_hdr: [18]u8 = undefined; // 2 + 16
        var read_n: usize = 0;
        while (read_n < len_hdr.len) {
            const n = try stream.read(len_hdr[read_n..]);
            if (n == 0) return error.ConnectionClosed;
            read_n += n;
        }
        
        // 解密长度
        const payload_len = try ctx.decryptLen(&len_hdr);
        if (payload_len > buf.len) return error.BufferTooSmall;
        
        // 读取 payload + tag
        const enc_payload_len = payload_len + tag_len;
        var enc_payload = try self.allocator.alloc(u8, enc_payload_len);
        defer self.allocator.free(enc_payload);
        
        read_n = 0;
        while (read_n < enc_payload_len) {
            const n = try stream.read(enc_payload[read_n..]);
            if (n == 0) return error.ConnectionClosed;
            read_n += n;
        }
        
        // 解密 payload
        try ctx.decryptPayload(enc_payload, buf);
        return payload_len;
    }
};

test "Shadowsocks client init" {
    const allocator = std.testing.allocator;
    var client = try ShadowsocksClient.init(allocator, "127.0.0.1", 8388, "password", "aes-128-gcm");
    defer client.deinit();
}
