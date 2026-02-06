const std = @import("std");
const yaml = @import("util/yaml.zig");

pub const ProxyType = enum {
    direct,
    reject,
    http,
    socks5,
    ss,        // Shadowsocks
    vmess,     // VMess
    trojan,    // Trojan
};

pub const Proxy = struct {
    name: []const u8,
    proxy_type: ProxyType,
    server: []const u8,
    port: u16,
    // Protocol-specific fields
    password: ?[]const u8 = null,
    cipher: ?[]const u8 = null,  // SS
    uuid: ?[]const u8 = null,    // VMess/Trojan
    alter_id: u16 = 0,           // VMess
    tls: bool = false,
    skip_cert_verify: bool = false,
    sni: ?[]const u8 = null,
    ws: bool = false,            // WebSocket
    ws_path: ?[]const u8 = null,
    ws_host: ?[]const u8 = null,

    pub fn deinit(self: *Proxy, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.server);
        if (self.password) |p| allocator.free(p);
        if (self.cipher) |c| allocator.free(c);
        if (self.uuid) |u| allocator.free(u);
        if (self.sni) |s| allocator.free(s);
        if (self.ws_path) |p| allocator.free(p);
        if (self.ws_host) |h| allocator.free(h);
    }
};

pub const RuleType = enum {
    domain,
    domain_suffix,
    domain_keyword,
    ip_cidr,
    ip_cidr6,
    geoip,
    src_ip_cidr,
    dst_port,
    src_port,
    process_name,
    final,  // MATCH
};

pub const Rule = struct {
    rule_type: RuleType,
    payload: []const u8,
    target: []const u8,  // Proxy name or DIRECT/REJECT
    no_resolve: bool = false,

    pub fn deinit(self: *Rule, allocator: std.mem.Allocator) void {
        allocator.free(self.payload);
        allocator.free(self.target);
    }
};

pub const ProxyGroupType = enum {
    select,
    url_test,
    fallback,
    load_balance,
    relay,
};

pub const ProxyGroup = struct {
    name: []const u8,
    group_type: ProxyGroupType,
    proxies: std.ArrayList([]const u8),
    url: ?[]const u8 = null,
    interval: u32 = 300,
    tolerance: u16 = 100,
    lazy: bool = true,

    pub fn deinit(self: *ProxyGroup, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        for (self.proxies.items) |proxy| {
            allocator.free(proxy);
        }
        self.proxies.deinit(allocator);
        if (self.url) |u| allocator.free(u);
    }
};

pub const Config = struct {
    allocator: std.mem.Allocator,
    port: u16 = 7890,
    socks_port: u16 = 7891,
    mixed_port: u16 = 0,
    redir_port: u16 = 0,
    tproxy_port: u16 = 0,
    allow_lan: bool = false,
    bind_address: []const u8 = "*",
    mode: []const u8 = "rule",
    log_level: []const u8 = "info",
    ipv6: bool = true,
    external_controller: ?[]const u8 = null,
    external_ui: ?[]const u8 = null,
    secret: ?[]const u8 = null,
    
    proxies: std.ArrayList(Proxy),
    proxy_groups: std.ArrayList(ProxyGroup),
    rules: std.ArrayList(Rule),

    pub fn deinit(self: *Config) void {
        for (self.proxies.items) |*proxy| {
            proxy.deinit(self.allocator);
        }
        self.proxies.deinit(self.allocator);

        for (self.proxy_groups.items) |*group| {
            group.deinit(self.allocator);
        }
        self.proxy_groups.deinit(self.allocator);

        for (self.rules.items) |*rule| {
            rule.deinit(self.allocator);
        }
        self.rules.deinit(self.allocator);

        self.allocator.free(self.mode);
        self.allocator.free(self.log_level);
        self.allocator.free(self.bind_address);
        if (self.external_controller) |ec| self.allocator.free(ec);
        if (self.external_ui) |ui| self.allocator.free(ui);
        if (self.secret) |s| self.allocator.free(s);
    }
};

/// 从文件加载配置
pub fn load(allocator: std.mem.Allocator, path: []const u8) !Config {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    return try parse(allocator, content);
}

/// 从 YAML 字符串解析配置
pub fn parse(allocator: std.mem.Allocator, content: []const u8) !Config {
    var root = try yaml.parse(allocator, content);
    defer root.deinit(allocator);

    var config = Config{
        .allocator = allocator,
        .mode = try allocator.dupe(u8, "rule"),
        .log_level = try allocator.dupe(u8, "info"),
        .bind_address = try allocator.dupe(u8, "*"),
        .proxies = std.ArrayList(Proxy).empty,
        .proxy_groups = std.ArrayList(ProxyGroup).empty,
        .rules = std.ArrayList(Rule).empty,
    };
    errdefer config.deinit();

    if (root != .map) {
        return error.InvalidConfig;
    }

    // 解析基础配置
    if (root.map.get("port")) |v| {
        if (v == .integer) config.port = @intCast(v.integer);
    }
    if (root.map.get("socks-port")) |v| {
        if (v == .integer) config.socks_port = @intCast(v.integer);
    }
    if (root.map.get("mixed-port")) |v| {
        if (v == .integer) config.mixed_port = @intCast(v.integer);
    }
    if (root.map.get("allow-lan")) |v| {
        if (v == .boolean) config.allow_lan = v.boolean;
    }
    if (root.map.get("mode")) |v| {
        if (v == .string) {
            allocator.free(config.mode);
            config.mode = try allocator.dupe(u8, v.string);
        }
    }
    if (root.map.get("log-level")) |v| {
        if (v == .string) {
            allocator.free(config.log_level);
            config.log_level = try allocator.dupe(u8, v.string);
        }
    }
    if (root.map.get("external-controller")) |v| {
        if (v == .string) config.external_controller = try allocator.dupe(u8, v.string);
    }

    // 解析代理列表
    if (root.map.get("proxies")) |proxies| {
        if (proxies == .array) {
            for (proxies.array.items) |*item| {
                if (item.* == .map) {
                    const proxy = try parseProxy(allocator, item.map);
                    try config.proxies.append(allocator, proxy);
                }
            }
        }
    }

    // 解析代理组
    if (root.map.get("proxy-groups")) |groups| {
        if (groups == .array) {
            for (groups.array.items) |*item| {
                if (item.* == .map) {
                    const group = try parseProxyGroup(allocator, item.map);
                    try config.proxy_groups.append(allocator, group);
                }
            }
        }
    }

    // 解析规则
    if (root.map.get("rules")) |rules| {
        if (rules == .array) {
            for (rules.array.items) |*item| {
                if (item.* == .string) {
                    const rule = try parseRule(allocator, item.string);
                    try config.rules.append(allocator, rule);
                }
            }
        }
    }

    // 如果没有规则，添加默认 MATCH 规则
    if (config.rules.items.len == 0) {
        try config.rules.append(allocator, .{
            .rule_type = .final,
            .payload = try allocator.dupe(u8, ""),
            .target = try allocator.dupe(u8, "DIRECT"),
        });
    }

    return config;
}

fn parseProxy(allocator: std.mem.Allocator, map: std.StringHashMap(yaml.YamlValue)) !Proxy {
    const name = map.get("name") orelse return error.MissingProxyName;
    const proxy_type = map.get("type") orelse return error.MissingProxyType;
    const server = map.get("server") orelse return error.MissingProxyServer;
    const port = map.get("port") orelse return error.MissingProxyPort;

    if (name != .string or proxy_type != .string or server != .string or port != .integer) {
        return error.InvalidProxyFormat;
    }

    const ptype = parseProxyType(proxy_type.string) orelse return error.UnknownProxyType;

    var proxy = Proxy{
        .name = try allocator.dupe(u8, name.string),
        .proxy_type = ptype,
        .server = try allocator.dupe(u8, server.string),
        .port = @intCast(port.integer),
    };

    // 协议特定字段
    if (map.get("password")) |v| {
        if (v == .string) proxy.password = try allocator.dupe(u8, v.string);
    }
    if (map.get("cipher")) |v| {
        if (v == .string) proxy.cipher = try allocator.dupe(u8, v.string);
    }
    if (map.get("uuid")) |v| {
        if (v == .string) proxy.uuid = try allocator.dupe(u8, v.string);
    }
    if (map.get("alterId")) |v| {
        if (v == .integer) proxy.alter_id = @intCast(v.integer);
    }
    if (map.get("tls")) |v| {
        if (v == .boolean) proxy.tls = v.boolean;
    }
    if (map.get("skip-cert-verify")) |v| {
        if (v == .boolean) proxy.skip_cert_verify = v.boolean;
    }
    if (map.get("sni")) |v| {
        if (v == .string) proxy.sni = try allocator.dupe(u8, v.string);
    }
    if (map.get("ws-opts")) |v| {
        if (v == .map) {
            proxy.ws = true;
            if (v.map.get("path")) |p| {
                if (p == .string) proxy.ws_path = try allocator.dupe(u8, p.string);
            }
            if (v.map.get("headers")) |h| {
                if (h == .map) {
                    if (h.map.get("Host")) |host| {
                        if (host == .string) proxy.ws_host = try allocator.dupe(u8, host.string);
                    }
                }
            }
        }
    }

    return proxy;
}

fn parseProxyGroup(allocator: std.mem.Allocator, map: std.StringHashMap(yaml.YamlValue)) !ProxyGroup {
    const name = map.get("name") orelse return error.MissingGroupName;
    const gtype = map.get("type") orelse return error.MissingGroupType;

    if (name != .string or gtype != .string) {
        return error.InvalidGroupFormat;
    }

    const group_type = parseGroupType(gtype.string) orelse return error.UnknownGroupType;

    var group = ProxyGroup{
        .name = try allocator.dupe(u8, name.string),
        .group_type = group_type,
        .proxies = std.ArrayList([]const u8).empty,
    };

    if (map.get("proxies")) |proxies| {
        if (proxies == .array) {
            for (proxies.array.items) |*item| {
                if (item.* == .string) {
                    const p = try allocator.dupe(u8, item.string);
                    try group.proxies.append(allocator, p);
                }
            }
        }
    }

    if (map.get("url")) |v| {
        if (v == .string) group.url = try allocator.dupe(u8, v.string);
    }
    if (map.get("interval")) |v| {
        if (v == .integer) group.interval = @intCast(v.integer);
    }
    if (map.get("tolerance")) |v| {
        if (v == .integer) group.tolerance = @intCast(v.integer);
    }
    if (map.get("lazy")) |v| {
        if (v == .boolean) group.lazy = v.boolean;
    }

    return group;
}

fn parseRule(allocator: std.mem.Allocator, rule_str: []const u8) !Rule {
    // Trim whitespace
    const trimmed = std.mem.trim(u8, rule_str, " \t\r\n");

    // Parse rule format: TYPE,PARAM,TARGET[,no-resolve] or TYPE,TARGET (for MATCH)
    var parts = std.mem.splitScalar(u8, trimmed, ',');

    const type_str = parts.next() orelse return error.InvalidRule;

    // MATCH rule has no payload: MATCH,TARGET
    // Other rules have payload: TYPE,PAYLOAD,TARGET
    const payload: []const u8 = blk: {
        if (std.mem.eql(u8, type_str, "MATCH")) {
            break :blk "";
        } else {
            break :blk parts.next() orelse return error.InvalidRule;
        }
    };

    const target = parts.next() orelse return error.InvalidRule;

    var no_resolve = false;
    while (parts.next()) |opt| {
        if (std.mem.eql(u8, std.mem.trim(u8, opt, " \t"), "no-resolve")) {
            no_resolve = true;
        }
    }

    const rule_type = parseRuleType(type_str) orelse return error.UnknownRuleType;

    return Rule{
        .rule_type = rule_type,
        .payload = try allocator.dupe(u8, std.mem.trim(u8, payload, " \t")),
        .target = try allocator.dupe(u8, std.mem.trim(u8, target, " \t")),
        .no_resolve = no_resolve,
    };
}

fn parseProxyType(s: []const u8) ?ProxyType {
    if (std.mem.eql(u8, s, "direct")) return .direct;
    if (std.mem.eql(u8, s, "reject")) return .reject;
    if (std.mem.eql(u8, s, "http")) return .http;
    if (std.mem.eql(u8, s, "socks5")) return .socks5;
    if (std.mem.eql(u8, s, "ss")) return .ss;
    if (std.mem.eql(u8, s, "vmess")) return .vmess;
    if (std.mem.eql(u8, s, "trojan")) return .trojan;
    return null;
}

fn parseGroupType(s: []const u8) ?ProxyGroupType {
    if (std.mem.eql(u8, s, "select")) return .select;
    if (std.mem.eql(u8, s, "url-test")) return .url_test;
    if (std.mem.eql(u8, s, "fallback")) return .fallback;
    if (std.mem.eql(u8, s, "load-balance")) return .load_balance;
    if (std.mem.eql(u8, s, "relay")) return .relay;
    return null;
}

fn parseRuleType(s: []const u8) ?RuleType {
    if (std.mem.eql(u8, s, "DOMAIN")) return .domain;
    if (std.mem.eql(u8, s, "DOMAIN-SUFFIX")) return .domain_suffix;
    if (std.mem.eql(u8, s, "DOMAIN-KEYWORD")) return .domain_keyword;
    if (std.mem.eql(u8, s, "IP-CIDR")) return .ip_cidr;
    if (std.mem.eql(u8, s, "IP-CIDR6")) return .ip_cidr6;
    if (std.mem.eql(u8, s, "GEOIP")) return .geoip;
    if (std.mem.eql(u8, s, "SRC-IP-CIDR")) return .src_ip_cidr;
    if (std.mem.eql(u8, s, "DST-PORT")) return .dst_port;
    if (std.mem.eql(u8, s, "SRC-PORT")) return .src_port;
    if (std.mem.eql(u8, s, "PROCESS-NAME")) return .process_name;
    if (std.mem.eql(u8, s, "MATCH")) return .final;
    return null;
}

/// 默认配置
pub fn loadDefault(allocator: std.mem.Allocator) !Config {
    const yaml_config = 
        \\port: 7890
        \\socks-port: 7891
        \\mode: rule
        \\log-level: info
        \\proxies:
        \\  - name: DIRECT
        \\    type: direct
        \\    server: ""
        \\    port: 0
        \\  - name: REJECT
        \\    type: reject
        \\    server: ""
        \\    port: 0
        \\rules:
        \\  - MATCH,DIRECT
    ;
    return try parse(allocator, yaml_config);
}

test "config parsing" {
    const allocator = std.testing.allocator;
    
    const yaml_config = 
        \\port: 1080
        \\proxies:
        \\  - name: Proxy1
        \\    type: ss
        \\    server: 127.0.0.1
        \\    port: 8388
        \\    cipher: aes-128-gcm
        \\    password: test
        \\rules:
        \\  - DOMAIN,google.com,Proxy1
        \\  - MATCH,DIRECT
    ;
    
    var config = try parse(allocator, yaml_config);
    defer config.deinit();
    
    try std.testing.expectEqual(@as(u16, 1080), config.port);
    try std.testing.expectEqual(@as(usize, 1), config.proxies.items.len);
    try std.testing.expectEqual(@as(usize, 2), config.rules.items.len);
}
