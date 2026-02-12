const std = @import("std");
const config = @import("config.zig");

fn proxyTypeString(pt: config.ProxyType) []const u8 {
    return switch (pt) {
        .direct => "DIRECT",
        .reject => "REJECT",
        .http => "HTTP",
        .socks5 => "SOCKS5",
        .ss => "SS",
        .vmess => "VMess",
        .trojan => "Trojan",
        .vless => "VLESS",
    };
}

fn groupTypeString(gt: config.ProxyGroupType) []const u8 {
    return switch (gt) {
        .select => "select",
        .url_test => "url-test",
        .fallback => "fallback",
        .load_balance => "load-balance",
        .relay => "relay",
    };
}

/// 列出所有代理组和节点
pub fn listProxies(_: std.mem.Allocator, cfg: *const config.Config) !void {
    std.debug.print("Proxy Groups:\n", .{});
    std.debug.print("{s:-^60}\n", .{""});

    for (cfg.proxy_groups.items) |group| {
        const type_str = groupTypeString(group.group_type);

        std.debug.print("\n{s} ({s}) - {d} proxies\n", .{
            group.name,
            type_str,
            group.proxies.items.len,
        });

        // 显示组内的节点
        for (group.proxies.items, 0..) |proxy_name, i| {
            // 查找节点信息
            var proxy_type: ?[]const u8 = null;
            for (cfg.proxies.items) |proxy| {
                if (std.mem.eql(u8, proxy.name, proxy_name)) {
                    proxy_type = proxyTypeString(proxy.proxy_type);
                    break;
                }
            }

            if (proxy_type) |pt| {
                std.debug.print("  {d}. {s:20} [{s}]\n", .{ i + 1, proxy_name, pt });
            } else {
                std.debug.print("  {d}. {s:20} [unknown]\n", .{ i + 1, proxy_name });
            }
        }
    }

    // 如果没有代理组，显示所有节点
    if (cfg.proxy_groups.items.len == 0) {
        std.debug.print("\nAll Proxies:\n", .{});
        std.debug.print("{s:-^60}\n", .{""});

        for (cfg.proxies.items, 0..) |proxy, i| {
            const proxy_type = proxyTypeString(proxy.proxy_type);

            if (proxy.port > 0) {
                std.debug.print("{d}. {s:20} [{s}] {s}:{d}\n", .{
                    i + 1,
                    proxy.name,
                    proxy_type,
                    proxy.server,
                    proxy.port,
                });
            } else {
                std.debug.print("{d}. {s:20} [{s}]\n", .{
                    i + 1,
                    proxy.name,
                    proxy_type,
                });
            }
        }
    }

    std.debug.print("\n", .{});
}

/// 以 JSON 格式列出代理组和节点（P1-1 序列 C）
pub fn listProxiesJson(allocator: std.mem.Allocator, cfg: *const config.Config) !void {
    var out = std.ArrayList(u8).empty;
    defer out.deinit(allocator);

    const w = out.writer(allocator);
    try out.appendSlice(allocator, "{\"ok\":true,\"data\":{\"groups\":[");

    for (cfg.proxy_groups.items, 0..) |group, gi| {
        if (gi > 0) try out.appendSlice(allocator, ",");
        try out.appendSlice(allocator, "{\"name\":\"");
        try out.appendSlice(allocator, group.name);
        try out.appendSlice(allocator, "\",\"type\":\"");
        try out.appendSlice(allocator, groupTypeString(group.group_type));
        try out.appendSlice(allocator, "\",\"proxies\":[");

        for (group.proxies.items, 0..) |proxy_name, pi| {
            if (pi > 0) try out.appendSlice(allocator, ",");
            var ptype: []const u8 = "unknown";
            for (cfg.proxies.items) |proxy| {
                if (std.mem.eql(u8, proxy.name, proxy_name)) {
                    ptype = proxyTypeString(proxy.proxy_type);
                    break;
                }
            }
            try out.appendSlice(allocator, "{\"name\":\"");
            try out.appendSlice(allocator, proxy_name);
            try out.appendSlice(allocator, "\",\"type\":\"");
            try out.appendSlice(allocator, ptype);
            try out.appendSlice(allocator, "\"}");
        }

        try out.appendSlice(allocator, "]}");
    }

    try out.appendSlice(allocator, "],\"stats\":{\"group_count\":");
    try w.print("{d}", .{cfg.proxy_groups.items.len});
    try out.appendSlice(allocator, ",\"proxy_count\":");
    try w.print("{d}", .{cfg.proxies.items.len});
    try out.appendSlice(allocator, "}}}\n");

    std.debug.print("{s}", .{out.items});
}

/// 选择代理节点（用于 select 类型的组）
pub fn selectProxyJson(allocator: std.mem.Allocator, cfg: *config.Config, group_name: ?[]const u8, proxy_name: ?[]const u8) !void {
    var target_group: ?*config.ProxyGroup = null;

    if (group_name) |gn| {
        for (cfg.proxy_groups.items) |*group| {
            if (std.mem.eql(u8, group.name, gn)) {
                target_group = group;
                break;
            }
        }
        if (target_group == null) return error.GroupNotFound;
    } else {
        for (cfg.proxy_groups.items) |*group| {
            if (group.group_type == .select) {
                target_group = group;
                break;
            }
        }
        if (target_group == null) return error.NoSelectGroup;
    }

    const group = target_group.?;

    if (proxy_name) |pn| {
        var found = false;
        for (group.proxies.items) |p| {
            if (std.mem.eql(u8, p, pn)) {
                found = true;
                break;
            }
        }
        if (!found) return error.ProxyNotFound;

        std.debug.print("{{\"ok\":true,\"data\":{{\"action\":\"proxy_select\",\"group\":\"{s}\",\"proxy\":\"{s}\",\"state\":\"selected\"}}}}\n", .{ group.name, pn });
        return;
    }

    var out = std.ArrayList(u8).empty;
    defer out.deinit(allocator);
    try out.appendSlice(allocator, "{\"ok\":true,\"data\":{\"action\":\"proxy_select\",\"group\":\"");
    try out.appendSlice(allocator, group.name);
    try out.appendSlice(allocator, "\",\"choices\":[");

    for (group.proxies.items, 0..) |name, i| {
        if (i > 0) try out.appendSlice(allocator, ",");
        try out.appendSlice(allocator, "\"");
        try out.appendSlice(allocator, name);
        try out.appendSlice(allocator, "\"");
    }

    try out.appendSlice(allocator, "]}}\n");
    std.debug.print("{s}", .{out.items});
}

pub fn selectProxy(allocator: std.mem.Allocator, cfg: *config.Config, group_name: ?[]const u8, proxy_name: ?[]const u8) !void {
    _ = allocator;
    
    // 如果没有指定组名，默认使用第一个 select 类型的组
    var target_group: ?*config.ProxyGroup = null;

    if (group_name) |gn| {
        // 查找指定组
        for (cfg.proxy_groups.items) |*group| {
            if (std.mem.eql(u8, group.name, gn)) {
                target_group = group;
                break;
            }
        }

        if (target_group == null) {
            std.debug.print("Proxy group not found: {s}\n", .{gn});
            return error.GroupNotFound;
        }
    } else {
        // 查找第一个 select 类型的组
        for (cfg.proxy_groups.items) |*group| {
            if (group.group_type == .select) {
                target_group = group;
                break;
            }
        }

        if (target_group == null) {
            std.debug.print("No select-type proxy group found\n", .{});
            return error.NoSelectGroup;
        }
    }

    const group = target_group.?;

    // 如果没有指定节点名，显示选择界面
    if (proxy_name) |pn| {
        // 验证节点是否在组中
        var found = false;
        for (group.proxies.items) |p| {
            if (std.mem.eql(u8, p, pn)) {
                found = true;
                break;
            }
        }

        if (!found) {
            std.debug.print("Proxy '{s}' not found in group '{s}'\n", .{ pn, group.name });
            return error.ProxyNotFound;
        }

        std.debug.print("Selected '{s}' in group '{s}'\n", .{ pn, group.name });
        std.debug.print("Note: Use 'zc tui' for interactive selection, or edit the config file directly.\n", .{});
    } else {
        // 显示选择界面
        std.debug.print("Select proxy for group '{s}':\n", .{group.name});
        std.debug.print("{s:-^60}\n", .{""});

        for (group.proxies.items, 0..) |proxy_name_in_group, i| {
            // 查找节点类型
            var proxy_type: ?[]const u8 = null;
            for (cfg.proxies.items) |proxy| {
                if (std.mem.eql(u8, proxy.name, proxy_name_in_group)) {
                    proxy_type = proxyTypeString(proxy.proxy_type);
                    break;
                }
            }

            const marker = if (i == 0) "*" else " ";
            if (proxy_type) |pt| {
                std.debug.print("{s} {d}. {s:20} [{s}]\n", .{ marker, i + 1, proxy_name_in_group, pt });
            } else {
                std.debug.print("{s} {d}. {s:20}\n", .{ marker, i + 1, proxy_name_in_group });
            }
        }

        std.debug.print("\nUse 'zc proxy select -g {s} -p <proxy_name>' to select\n", .{group.name});
    }
}
