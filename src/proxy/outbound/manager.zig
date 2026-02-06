const std = @import("std");
const net = std.net;
const Config = @import("../../config.zig").Config;
const Proxy = @import("../../config.zig").Proxy;
const ProxyType = @import("../../config.zig").ProxyType;
const ss = @import("shadowsocks.zig");

/// 代理流包装器
pub const ProxyStream = struct {
    base_stream: net.Stream,
    ss_client: ?*ss.ShadowsocksClient = null,
    is_encrypted: bool = false,

    pub fn initDirect(stream: net.Stream) ProxyStream {
        return .{
            .base_stream = stream,
            .is_encrypted = false,
        };
    }

    pub fn initShadowsocks(stream: net.Stream, client: *ss.ShadowsocksClient) ProxyStream {
        return .{
            .base_stream = stream,
            .ss_client = client,
            .is_encrypted = true,
        };
    }

    pub fn write(self: *ProxyStream, data: []const u8) !void {
        if (self.is_encrypted) {
            try self.ss_client.?.write(data);
        } else {
            try self.base_stream.writeAll(data);
        }
    }

    pub fn read(self: *ProxyStream, buf: []u8) !usize {
        if (self.is_encrypted) {
            return try self.ss_client.?.read(buf);
        } else {
            return try self.base_stream.read(buf);
        }
    }

    pub fn close(self: *ProxyStream) void {
        self.base_stream.close();
    }
};

/// 代理出站管理器
pub const OutboundManager = struct {
    allocator: std.mem.Allocator,
    config: *const Config,
    ss_clients: std.StringHashMap(*ss.ShadowsocksClient),

    pub fn init(allocator: std.mem.Allocator, config: *const Config) !OutboundManager {
        var manager = OutboundManager{
            .allocator = allocator,
            .config = config,
            .ss_clients = std.StringHashMap(*ss.ShadowsocksClient).init(allocator),
        };

        // 预初始化 Shadowsocks 客户端
        for (config.proxies.items) |*proxy| {
            if (proxy.proxy_type == .ss) {
                const client = try allocator.create(ss.ShadowsocksClient);
                client.* = try ss.ShadowsocksClient.init(
                    allocator,
                    proxy.server,
                    proxy.port,
                    proxy.password orelse "",
                    proxy.cipher orelse "aes-128-gcm",
                );
                try manager.ss_clients.put(proxy.name, client);
            }
        }

        return manager;
    }

    pub fn deinit(self: *OutboundManager) void {
        var iter = self.ss_clients.valueIterator();
        while (iter.next()) |client| {
            client.*.deinit();
            self.allocator.destroy(client.*);
        }
        self.ss_clients.deinit();
    }

    /// 根据代理名称建立连接（返回原始 stream，加密由调用方处理）
    pub fn connect(self: *OutboundManager, proxy_name: []const u8, target: []const u8, port: u16) !net.Stream {
        const proxy = self.findProxy(proxy_name) orelse return error.ProxyNotFound;

        switch (proxy.proxy_type) {
            .direct => {
                var addr_list = try net.getAddressList(self.allocator, target, port);
                defer addr_list.deinit();
                if (addr_list.addrs.len == 0) return error.HostNotFound;
                return try net.tcpConnectToAddress(addr_list.addrs[0]);
            },
            .reject => {
                return error.ConnectionRejected;
            },
            .ss => {
                const client = self.ss_clients.get(proxy_name) orelse return error.ClientNotFound;
                const addr = ss.Address{
                    .host = target,
                    .port = port,
                };
                return try client.connect(addr);
            },
            else => {
                std.debug.print("Proxy type not implemented yet\n", .{});
                return error.NotImplemented;
            },
        }
    }

    fn findProxy(self: *OutboundManager, name: []const u8) ?*const Proxy {
        for (self.config.proxies.items) |*proxy| {
            if (std.mem.eql(u8, proxy.name, name)) {
                return proxy;
            }
        }
        return null;
    }
};
