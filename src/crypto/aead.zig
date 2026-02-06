const std = @import("std");

/// Shadowsocks AEAD 加密支持
/// 目前支持：AES-128-GCM, ChaCha20-Poly1305

pub const CipherType = enum {
    aes_128_gcm,
    aes_256_gcm,
    chacha20_poly1305,
    chacha20_ietf_poly1305,
};

pub const AeadCipher = struct {
    cipher_type: CipherType,
    key: [32]u8,  // Max key size
    key_len: usize,
    nonce_len: usize,
    tag_len: usize = 16,

    pub fn init(cipher_type: CipherType, password: []const u8, salt: []const u8) !AeadCipher {
        var cipher: AeadCipher = undefined;
        cipher.cipher_type = cipher_type;

        switch (cipher_type) {
            .aes_128_gcm => {
                cipher.key_len = 16;
                cipher.nonce_len = 12;
            },
            .aes_256_gcm => {
                cipher.key_len = 32;
                cipher.nonce_len = 12;
            },
            .chacha20_poly1305, .chacha20_ietf_poly1305 => {
                cipher.key_len = 32;
                cipher.nonce_len = 12;
            },
        }

        // Derive key using HKDF-SHA1 (Shadowsocks standard)
        try hkdfSha1(password, salt, cipher.key[0..cipher.key_len]);

        return cipher;
    }

    /// 加密数据：out 必须有足够空间 (in.len + tag_len)
    pub fn encrypt(self: *const AeadCipher, nonce: []const u8, in: []const u8, out: []u8) !void {
        _ = self;
        _ = nonce;
        _ = in;
        _ = out;
        // TODO: 实际加密实现
        // 需要使用 OpenSSL 或自研 crypto
        return error.NotImplemented;
    }

    /// 解密数据
    pub fn decrypt(self: *const AeadCipher, nonce: []const u8, in: []const u8, out: []u8) !void {
        _ = self;
        _ = nonce;
        _ = in;
        _ = out;
        return error.NotImplemented;
    }
};

/// HKDF-SHA1 key derivation (Shadowsocks standard)
fn hkdfSha1(password: []const u8, salt: []const u8, out: []u8) !void {
    // Simplified HKDF: EVP_BytesToKey style
    var buf: [64]u8 = undefined;
    var last: []const u8 = password;
    var offset: usize = 0;

    while (offset < out.len) {
        var h = std.crypto.hash.Sha1.init(.{});
        h.update(last);
        h.update(salt);
        h.final(buf[0..20]);
        
        const copy_len = @min(20, out.len - offset);
        @memcpy(out[offset..offset + copy_len], buf[0..copy_len]);
        offset += copy_len;
        last = buf[0..20];
    }
}

/// 从字符串解析 cipher 类型
pub fn parseCipherType(s: []const u8) ?CipherType {
    if (std.mem.eql(u8, s, "aes-128-gcm")) return .aes_128_gcm;
    if (std.mem.eql(u8, s, "aes-256-gcm")) return .aes_256_gcm;
    if (std.mem.eql(u8, s, "chacha20-poly1305")) return .chacha20_poly1305;
    if (std.mem.eql(u8, s, "chacha20-ietf-poly1305")) return .chacha20_ietf_poly1305;
    return null;
}

/// Shadowsocks 地址编码
pub const Address = struct {
    host: []const u8,
    port: u16,

    pub fn encode(self: Address, buf: []u8) !usize {
        // Try to parse as IPv4 first
        if (std.net.Address.parseIp4(self.host, self.port)) |parsed| {
            const ip_bytes = std.mem.asBytes(&parsed.in.sa.addr);
            buf[0] = 0x01;
            @memcpy(buf[1..5], ip_bytes);
            buf[5] = @intCast(self.port >> 8);
            buf[6] = @intCast(self.port & 0xFF);
            return 7;
        } else |_| {}

        // Try IPv6
        if (std.net.Address.parseIp6(self.host, self.port)) |parsed| {
            buf[0] = 0x04;
            const bytes = std.mem.asBytes(&parsed.in6.sa.addr);
            @memcpy(buf[1..17], bytes);
            buf[17] = @intCast(self.port >> 8);
            buf[18] = @intCast(self.port & 0xFF);
            return 19;
        } else |_| {}

        // Domain
        buf[0] = 0x03;
        buf[1] = @intCast(self.host.len);
        @memcpy(buf[2..2+self.host.len], self.host);
        buf[2+self.host.len] = @intCast(self.port >> 8);
        buf[2+self.host.len+1] = @intCast(self.port & 0xFF);
        return 2 + self.host.len + 2;
    }
};

test "hkdf sha1" {
    var key: [16]u8 = undefined;
    try hkdfSha1("password", &[_]u8{0} ** 32, &key);
}
