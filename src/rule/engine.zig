const std = @import("std");
const Rule = @import("../config.zig").Rule;
const RuleType = @import("../config.zig").RuleType;
const dns = @import("../dns.zig");

const log = std.log.scoped(.rule_engine);

/// 规则匹配上下文
pub const MatchContext = struct {
    host: []const u8,
    port: u16,
    is_domain: bool,
    process_name: ?[]const u8 = null,
    source_ip: ?[]const u8 = null,
};

/// RuleEngine matches requests against rules and returns the target proxy
pub const Engine = struct {
    allocator: std.mem.Allocator,
    rules: *const std.ArrayList(Rule),
    dns_client: ?dns.DnsClient,
    domain_set: std.StringHashMap(void),
    domain_suffix_trie: TrieNode,
    domain_keywords: std.ArrayList([]const u8),
    ip_cidrs: std.ArrayList(IpCidr),

    pub fn init(allocator: std.mem.Allocator, rules: *const std.ArrayList(Rule)) !Engine {
        return try initWithDns(allocator, rules, null);
    }

    pub fn initWithDns(allocator: std.mem.Allocator, rules: *const std.ArrayList(Rule), dns_config: ?dns.DnsConfig) !Engine {
        var engine = Engine{
            .allocator = allocator,
            .rules = rules,
            .dns_client = if (dns_config) |cfg| dns.DnsClient.init(allocator, cfg) else null,
            .domain_set = std.StringHashMap(void).init(allocator),
            .domain_suffix_trie = TrieNode{
                .children = std.AutoHashMap(u8, *TrieNode).init(allocator),
                .is_end = false,
            },
            .domain_keywords = std.ArrayList([]const u8).empty,
            .ip_cidrs = std.ArrayList(IpCidr).empty,
        };

        // Preprocess rules for fast matching
        for (rules.items) |rule| {
            switch (rule.rule_type) {
                .domain => {
                    try engine.domain_set.put(rule.payload, {});
                },
                .domain_suffix => {
                    try engine.addDomainSuffix(rule.payload);
                },
                .domain_keyword => {
                    try engine.domain_keywords.append(allocator, rule.payload);
                },
                .ip_cidr => {
                    const cidr = try parseCidr(rule.payload);
                    try engine.ip_cidrs.append(allocator, cidr);
                },
                else => {},
            }
        }

        return engine;
    }

    pub fn deinit(self: *Engine) void {
        if (self.dns_client) |*client| {
            client.deinit();
        }
        self.domain_set.deinit();
        self.domain_suffix_trie.deinit(self.allocator);
        self.domain_keywords.deinit(self.allocator);
        self.ip_cidrs.deinit(self.allocator);
    }

    /// Match a request and return the target proxy name
    /// 这是简化版，直接传入 host 和是否为域名
    pub fn match(self: *Engine, host: []const u8, is_domain: bool) ?[]const u8 {
        // Check domain rules first (if it's a domain)
        if (is_domain) {
            // 1. Exact domain match
            if (self.domain_set.contains(host)) {
                return self.findRuleTarget(.domain, host);
            }

            // 2. Domain suffix match
            if (self.matchDomainSuffix(host)) {
                const suffix = self.findMatchingSuffix(host) orelse host;
                return self.findRuleTarget(.domain_suffix, suffix);
            }

            // 3. Domain keyword match
            for (self.domain_keywords.items) |keyword| {
                if (std.mem.indexOf(u8, host, keyword) != null) {
                    return self.findRuleTarget(.domain_keyword, keyword);
                }
            }

            // Try to resolve and check IP rules (if DNS available and not no-resolve)
            if (self.dns_client) |*client| {
                const addresses = client.resolve(host) catch |err| {
                    std.debug.print("DNS resolve failed: {}\n", .{err});
                    return self.findRuleTarget(.final, "");
                };
                defer self.allocator.free(addresses);

                for (addresses) |addr| {
                    const ip_str = std.fmt.allocPrint(self.allocator, "{d}.{d}.{d}.{d}", .{
                        (addr.in.sa.addr >> 0) & 0xFF,
                        (addr.in.sa.addr >> 8) & 0xFF,
                        (addr.in.sa.addr >> 16) & 0xFF,
                        (addr.in.sa.addr >> 24) & 0xFF,
                    }) catch continue;
                    defer self.allocator.free(ip_str);

                    // Check IP-CIDR rules
                    for (self.ip_cidrs.items) |cidr| {
                        if (cidr.contains(addr.in.sa.addr)) {
                            return self.findRuleTarget(.ip_cidr, cidr.original);
                        }
                    }
                }
            }
        } else {
            // IP-based rules
            const addr = std.net.Address.parseIp4(host, 0) catch {
                return self.findRuleTarget(.final, "");
            };
            const ip = addr.in.sa.addr;

            for (self.ip_cidrs.items) |cidr| {
                if (cidr.contains(ip)) {
                    return self.findRuleTarget(.ip_cidr, cidr.original);
                }
            }
        }

        // Final rule (MATCH)
        return self.findRuleTarget(.final, "");
    }

    fn findRuleTarget(self: *const Engine, rule_type: RuleType, payload: []const u8) ?[]const u8 {
        for (self.rules.items) |rule| {
            if (rule.rule_type == rule_type and std.mem.eql(u8, rule.payload, payload)) {
                return rule.target;
            }
        }
        // For final rule, find the first one
        if (rule_type == .final) {
            for (self.rules.items) |rule| {
                if (rule.rule_type == .final) {
                    return rule.target;
                }
            }
        }
        return null;
    }

    fn addDomainSuffix(self: *Engine, suffix: []const u8) !void {
        // Insert reversed suffix into trie
        var node = &self.domain_suffix_trie;
        var i: usize = suffix.len;
        while (i > 0) {
            i -= 1;
            const c = suffix[i];
            const entry = try node.children.getOrPut(c);
            if (!entry.found_existing) {
                const new_node = try self.allocator.create(TrieNode);
                new_node.* = TrieNode{
                    .children = std.AutoHashMap(u8, *TrieNode).init(self.allocator),
                    .is_end = false,
                };
                entry.value_ptr.* = new_node;
            }
            node = entry.value_ptr.*;
        }
        node.is_end = true;
    }

    fn matchDomainSuffix(self: *const Engine, domain: []const u8) bool {
        var node: ?*const TrieNode = &self.domain_suffix_trie;
        var i: usize = domain.len;
        while (i > 0) {
            i -= 1;
            const c = domain[i];
            node = node.?.children.get(c) orelse return false;
            if (node.?.is_end) return true;
        }
        return false;
    }

    fn findMatchingSuffix(self: *const Engine, domain: []const u8) ?[]const u8 {
        var node: ?*const TrieNode = &self.domain_suffix_trie;
        var i: usize = domain.len;
        var match_start: usize = domain.len;
        while (i > 0) {
            i -= 1;
            const c = domain[i];
            node = node.?.children.get(c) orelse break;
            if (node.?.is_end) {
                match_start = i;
            }
        }
        if (match_start < domain.len) {
            return domain[match_start..];
        }
        return null;
    }
};

const TrieNode = struct {
    children: std.AutoHashMap(u8, *TrieNode),
    is_end: bool,

    fn deinit(self: *TrieNode, allocator: std.mem.Allocator) void {
        var iter = self.children.valueIterator();
        while (iter.next()) |child| {
            child.*.deinit(allocator);
            allocator.destroy(child.*);
        }
        self.children.deinit();
    }
};

const IpCidr = struct {
    prefix: u32,
    mask: u32,
    original: []const u8,

    fn contains(self: IpCidr, ip: u32) bool {
        return (ip & self.mask) == self.prefix;
    }
};

fn parseCidr(s: []const u8) !IpCidr {
    const slash_pos = std.mem.indexOf(u8, s, "/");
    if (slash_pos == null) return error.InvalidCidr;

    const ip_str = s[0..slash_pos.?];
    const prefix_len = try std.fmt.parseInt(u8, s[slash_pos.? + 1 ..], 10);

    const addr = try std.net.Address.parseIp4(ip_str, 0);
    const ip = addr.in.sa.addr;

    if (prefix_len > 32) return error.InvalidPrefix;

    const mask: u32 = if (prefix_len == 0) 0 else ~(@as(u32, 0) >> @intCast(prefix_len));

    return IpCidr{
        .prefix = ip & mask,
        .mask = mask,
        .original = s,
    };
}
