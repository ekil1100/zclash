const std = @import("std");
const net = std.net;
const Config = @import("../../config.zig").Config;
const Proxy = @import("../../config.zig").Proxy;
const ProxyType = @import("../../config.zig").ProxyType;
const ss = @import("shadowsocks.zig");

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

    /// 根据代理名称获取连接
    pub fn connect(self: *OutboundManager, proxy_name: []const u8, target: []const u8, port: u16) !net.Stream {
        // 查找代理配置
        const proxy = self.findProxy(proxy_name) orelse return error.ProxyNotFound;

        switch (proxy.proxy_type) {
            .direct => {
                // 直接连接目标
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
