const std = @import("std");
const net = std.net;
const Config = @import("../../config.zig").Config;
const Proxy = @import("../../config.zig").Proxy;
const ProxyType = @import("../../config.zig").ProxyType;
const ss = @import("shadowsocks.zig");
const vmess = @import("../../protocol/vmess.zig");
const trojan = @import("../../protocol/trojan.zig");

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
    vmess_clients: std.StringHashMap(*vmess.Client),
    trojan_clients: std.StringHashMap(*trojan.Client),

    pub fn init(allocator: std.mem.Allocator, config: *const Config) !OutboundManager {
        var manager = OutboundManager{
            .allocator = allocator,
            .config = config,
            .ss_clients = std.StringHashMap(*ss.ShadowsocksClient).init(allocator),
            .vmess_clients = std.StringHashMap(*vmess.Client).init(allocator),
            .trojan_clients = std.StringHashMap(*trojan.Client).init(allocator),
        };

        // 预初始化代理客户端
        for (config.proxies.items) |*proxy| {
            switch (proxy.proxy_type) {
                .ss => {
                    const client = try allocator.create(ss.ShadowsocksClient);
                    client.* = try ss.ShadowsocksClient.init(
                        allocator,
                        proxy.server,
                        proxy.port,
                        proxy.password orelse "",
                        proxy.cipher orelse "aes-128-gcm",
                    );
                    try manager.ss_clients.put(proxy.name, client);
                },
                .vmess => {
                    const client = try allocator.create(vmess.Client);
                    client.* = try vmess.Client.init(allocator, .{
                        .id = proxy.uuid orelse return error.MissingUuid,
                        .address = proxy.server,
                        .port = proxy.port,
                        .alter_id = proxy.alter_id,
                    });
                    try manager.vmess_clients.put(proxy.name, client);
                },
                .trojan => {
                    const client = try allocator.create(trojan.Client);
                    client.* = try trojan.Client.init(allocator, .{
                        .password = proxy.password orelse return error.MissingPassword,
                        .address = proxy.server,
                        .port = proxy.port,
                        .sni = proxy.sni,
                        .skip_cert_verify = proxy.skip_cert_verify,
                    });
                    try manager.trojan_clients.put(proxy.name, client);
                },
                else => {},
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

        var vmess_iter = self.vmess_clients.valueIterator();
        while (vmess_iter.next()) |client| {
            self.allocator.destroy(client.*);
        }
        self.vmess_clients.deinit();

        var trojan_iter = self.trojan_clients.valueIterator();
        while (trojan_iter.next()) |client| {
            self.allocator.destroy(client.*);
        }
        self.trojan_clients.deinit();
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
            .vmess => {
                const client = self.vmess_clients.get(proxy_name) orelse return error.ClientNotFound;
                return try client.connect(target, port);
            },
            .trojan => {
                const client = self.trojan_clients.get(proxy_name) orelse return error.ClientNotFound;
                return try client.connect(target, port);
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
