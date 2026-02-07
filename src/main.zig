const std = @import("std");
const config = @import("config.zig");
const http_proxy = @import("proxy/http.zig");
const socks5_proxy = @import("proxy/socks5.zig");
const mixed_proxy = @import("proxy/mixed.zig");
const rule_engine = @import("rule/engine.zig");
const outbound = @import("proxy/outbound/manager.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("clash-zig v0.1.0\n", .{});

    // Parse command line args
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var config_path: ?[]const u8 = null;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "-c") or std.mem.eql(u8, args[i], "--config")) {
            if (i + 1 < args.len) {
                config_path = args[i + 1];
                i += 1;
            }
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

    std.debug.print("Configuration loaded:\n", .{});
    std.debug.print("  Port: {}\n", .{cfg.port});
    std.debug.print("  SOCKS Port: {}\n", .{cfg.socks_port});
    std.debug.print("  Mixed Port: {}\n", .{cfg.mixed_port});
    std.debug.print("  Mode: {s}\n", .{cfg.mode});
    std.debug.print("  Proxies: {}\n", .{cfg.proxies.items.len});
    std.debug.print("  Rules: {}\n", .{cfg.rules.items.len});

    // Initialize outbound manager
    var manager = try outbound.OutboundManager.init(allocator, &cfg);
    defer manager.deinit();

    // Initialize rule engine
    var engine = try rule_engine.Engine.init(allocator, &cfg.rules);
    defer engine.deinit();

    // Start proxy servers
    // Priority: mixed-port > (port + socks-port)
    if (cfg.mixed_port > 0) {
        std.debug.print("\nStarting mixed proxy (HTTP+SOCKS5) on port {}\n", .{cfg.mixed_port});
        try mixed_proxy.start(allocator, cfg.mixed_port, &engine, &manager);
    } else {
        if (cfg.port > 0) {
            std.debug.print("\nStarting HTTP proxy on port {}\n", .{cfg.port});
            try http_proxy.start(allocator, cfg.port, &engine, &manager);
        }

        if (cfg.socks_port > 0) {
            std.debug.print("\nStarting SOCKS5 proxy on port {}\n", .{cfg.socks_port});
            try socks5_proxy.start(allocator, cfg.socks_port, &engine, &manager);
        }
    }

    // Keep running
    std.debug.print("\nProxy server running. Press Ctrl+C to stop.\n", .{});
    while (true) {
        std.Thread.sleep(1 * std.time.ns_per_s);
    }
}

fn printHelp() !void {
    std.debug.print("Usage: clash-zig [options]\n\n", .{});
    std.debug.print("Options:\n", .{});
    std.debug.print("  -c, --config <path>    Configuration file path\n", .{});
    std.debug.print("  -h, --help             Show this help message\n\n", .{});
}
