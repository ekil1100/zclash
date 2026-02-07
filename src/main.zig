const std = @import("std");
const config = @import("config.zig");
const http_proxy = @import("proxy/http.zig");
const socks5_proxy = @import("proxy/socks5.zig");
const mixed_proxy = @import("proxy/mixed.zig");
const rule_engine = @import("rule/engine.zig");
const outbound = @import("proxy/outbound/manager.zig");
const api = @import("api/server.zig");
const tui = @import("tui.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("zclash v0.1.0\n", .{});

    // Parse command line args
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var config_path: ?[]const u8 = null;
    var use_tui = false;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "-c") or std.mem.eql(u8, args[i], "--config")) {
            if (i + 1 < args.len) {
                config_path = args[i + 1];
                i += 1;
            }
        } else if (std.mem.eql(u8, args[i], "--tui")) {
            use_tui = true;
        } else if (std.mem.eql(u8, args[i], "-h") or std.mem.eql(u8, args[i], "--help")) {
            try printHelp();
            return;
        }
    }

    // Load configuration
    var cfg = if (config_path) |path|
        try config.load(allocator, path)
    else
        try config.loadDefault(allocator);
    defer cfg.deinit();

    // Initialize outbound manager
    var manager = try outbound.OutboundManager.init(allocator, &cfg);
    defer manager.deinit();

    // Initialize rule engine
    var engine = try rule_engine.Engine.init(allocator, &cfg.rules);
    defer engine.deinit();

    // Start proxy servers in background thread
    const proxy_thread = try std.Thread.spawn(.{}, proxyThreadFn, .{ allocator, &cfg, &engine, &manager });
    proxy_thread.detach();

    // Start API server if configured
    if (cfg.external_controller) |ec| {
        const colon_pos = std.mem.lastIndexOf(u8, ec, ":");
        if (colon_pos) |pos| {
            const port = std.fmt.parseInt(u16, ec[pos + 1 ..], 10) catch 9090;
            const api_thread = try std.Thread.spawn(.{}, apiThreadFn, .{ allocator, &cfg, &engine, &manager, port });
            api_thread.detach();
        }
    }

    // Run TUI or stay in background
    if (use_tui) {
        try runTui(allocator, &cfg, &engine, &manager);
    } else {
        std.debug.print("Configuration loaded:\n", .{});
        std.debug.print("  Port: {}\n", .{cfg.port});
        std.debug.print("  SOCKS Port: {}\n", .{cfg.socks_port});
        std.debug.print("  Mixed Port: {}\n", .{cfg.mixed_port});
        std.debug.print("  Mode: {s}\n", .{cfg.mode});
        std.debug.print("  Proxies: {}\n", .{cfg.proxies.items.len});
        std.debug.print("  Rules: {}\n", .{cfg.rules.items.len});
        std.debug.print("\nProxy server running. Press Ctrl+C to stop.\n", .{});
        std.debug.print("Use --tui flag to enable interactive dashboard.\n", .{});
        
        while (true) {
            std.Thread.sleep(1 * std.time.ns_per_s);
        }
    }
}

fn proxyThreadFn(allocator: std.mem.Allocator, cfg: *const config.Config, engine: *rule_engine.Engine, manager: *outbound.OutboundManager) void {
    std.Thread.sleep(100 * std.time.ns_per_ms); // Wait a bit for TUI to start

    if (cfg.mixed_port > 0) {
        std.debug.print("Starting mixed proxy on port {}\n", .{cfg.mixed_port});
        mixed_proxy.start(allocator, cfg.mixed_port, engine, manager) catch |err| {
            std.debug.print("Mixed proxy error: {}\n", .{err});
        };
    } else {
        if (cfg.port > 0) {
            std.debug.print("Starting HTTP proxy on port {}\n", .{cfg.port});
            http_proxy.start(allocator, cfg.port, engine, manager) catch |err| {
                std.debug.print("HTTP proxy error: {}\n", .{err});
            };
        }

        if (cfg.socks_port > 0) {
            std.debug.print("Starting SOCKS5 proxy on port {}\n", .{cfg.socks_port});
            socks5_proxy.start(allocator, cfg.socks_port, engine, manager) catch |err| {
                std.debug.print("SOCKS5 proxy error: {}\n", .{err});
            };
        }
    }
}

fn runTui(allocator: std.mem.Allocator, cfg: *const config.Config, engine: *rule_engine.Engine, manager: *outbound.OutboundManager) !void {
    _ = engine;
    _ = manager;
    
    var tui_manager = try tui.TuiManager.init(allocator);
    defer tui_manager.deinit();

    // Add proxies to TUI
    for (cfg.proxies.items) |proxy| {
        try tui_manager.addProxy(proxy.name);
    }

    // Add some sample logs
    try tui_manager.log("zclash started");
    try tui_manager.log("Configuration loaded");
    try tui_manager.log("Proxy servers starting...");

    // Update stats
    tui_manager.updateStats(1024, 2048, 5);

    // Run TUI
    try tui_manager.run();
}

fn apiThreadFn(allocator: std.mem.Allocator, cfg: *const config.Config, engine: *rule_engine.Engine, manager: *outbound.OutboundManager, port: u16) void {
    var api_server = api.ApiServer.init(allocator, cfg, engine, manager, port);
    api_server.start() catch |err| {
        std.debug.print("API server error: {}\n", .{err});
    };
}

fn printHelp() !void {
    std.debug.print("Usage: zclash [options]\n\n", .{});
    std.debug.print("Options:\n", .{});
    std.debug.print("  -c, --config <path>    Configuration file path\n", .{});
    std.debug.print("  --tui                  Enable TUI dashboard\n", .{});
    std.debug.print("  -h, --help             Show this help message\n\n", .{});
}
