const std = @import("std");
const net = std.net;
const aead = @import("../../crypto/aead.zig");
pub const Address = aead.Address;

const log = std.log.scoped(.ss_outbound);

/// Shadowsocks 出站连接
pub const ShadowsocksClient = struct {
    allocator: std.mem.Allocator,
    server: []const u8,
    port: u16,
    password: []const u8,
    cipher_type: aead.CipherType,
    stream: ?net.Stream = null,

    pub fn init(allocator: std.mem.Allocator, server: []const u8, port: u16, password: []const u8, cipher: []const u8) !ShadowsocksClient {
        const cipher_type = aead.parseCipherType(cipher) orelse return error.UnsupportedCipher;
        
        return ShadowsocksClient{
            .allocator = allocator,
            .server = try allocator.dupe(u8, server),
            .port = port,
            .password = try allocator.dupe(u8, password),
            .cipher_type = cipher_type,
            .stream = null,
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
        
        // 3. Shadowsocks 握手 (AEAD)
        // 生成随机 salt
        var salt: [32]u8 = undefined;
        std.crypto.random.bytes(&salt);
        
        // 发送 salt
        try stream.writeAll(&salt);
        
        // 4. 初始化加密器
        const cipher = try aead.AeadCipher.init(self.cipher_type, self.password, &salt);
        _ = cipher;
        
        // 5. 编码目标地址
        var addr_buf: [260]u8 = undefined;
        const addr_len = try target.encode(&addr_buf);
        
        // 6. 发送加密的地址
        // TODO: 实际加密
        try stream.writeAll(addr_buf[0..addr_len]);
        
        self.stream = stream;
        return stream;
    }

    ///  relay 数据
    pub fn relay(self: *ShadowsocksClient, local_stream: net.Stream) !void {
        _ = self;
        _ = local_stream;
        // TODO: 实现双向加密 relay
    }
};

test "Shadowsocks client init" {
    const allocator = std.testing.allocator;
    var client = try ShadowsocksClient.init(allocator, "127.0.0.1", 8388, "password", "aes-128-gcm");
    defer client.deinit();
}
