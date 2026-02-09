const std = @import("std");
const config = @import("config.zig");
const validator = @import("config_validator.zig");
const http_proxy = @import("proxy/http.zig");
const socks5_proxy = @import("proxy/socks5.zig");
const mixed_proxy = @import("proxy/mixed.zig");
const rule_engine = @import("rule/engine.zig");
const outbound = @import("proxy/outbound/manager.zig");
const api = @import("api/server.zig");
const tui = @import("tui.zig");
const daemon = @import("daemon.zig");
const proxy_cli = @import("proxy_cli.zig");
const test_cli = @import("test_cli.zig");

// 全局配置路径，用于重载
var g_config_path: ?[]const u8 = null;
var gpa_holder: ?*std.heap.GeneralPurposeAllocator(.{}) = null;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    gpa_holder = &gpa;
    defer {
        if (g_config_path) |path| {
            gpa.allocator().free(path);
        }
        _ = gpa.deinit();
    }
    const allocator = gpa.allocator();

    // Parse command line args
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // 检查是否有子命令
    if (args.len < 2) {
        // 无参数，显示帮助
        try printHelp();
        return;
    }

    const cmd = args[1];

    // 处理 daemon 运行模式（内部使用）
    if (std.mem.eql(u8, cmd, "--daemon-run")) {
        var config_path: ?[]const u8 = null;
        var i: usize = 2;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "-c")) {
                if (i + 1 < args.len) {
                    config_path = args[i + 1];
                    i += 1;
                }
            }
        }
        // 在 daemon 模式下运行代理（无 TUI）
        try runProxy(allocator, config_path, false);
        return;
    }

    // 处理 help
    if (std.mem.eql(u8, cmd, "-h") or std.mem.eql(u8, cmd, "--help") or std.mem.eql(u8, cmd, "help")) {
        try printHelp();
        return;
    }

    // 处理 tui 命令
    if (std.mem.eql(u8, cmd, "tui")) {
        try runProxy(allocator, null, true);
        return;
    }

    // 处理 start 命令
    if (std.mem.eql(u8, cmd, "start")) {
        var config_path: ?[]const u8 = null;
        var i: usize = 2;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "-c")) {
                if (i + 1 < args.len) {
                    config_path = args[i + 1];
                    i += 1;
                }
            }
        }
        // 后台启动
        try daemon.startDaemon(allocator, config_path);
        return;
    }

    // 处理 stop 命令
    if (std.mem.eql(u8, cmd, "stop")) {
        try daemon.stopDaemon(allocator);
        return;
    }

    // 处理 restart 命令
    if (std.mem.eql(u8, cmd, "restart")) {
        var config_path: ?[]const u8 = null;
        var i: usize = 2;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "-c")) {
                if (i + 1 < args.len) {
                    config_path = args[i + 1];
                    i += 1;
                }
            }
        }
        // 先停止
        daemon.stopDaemon(allocator) catch {};
        // 再启动
        try daemon.startDaemon(allocator, config_path);
        return;
    }

    // 处理 status 命令
    if (std.mem.eql(u8, cmd, "status")) {
        try daemon.getStatus(allocator);
        return;
    }

    // 处理 log 命令
    if (std.mem.eql(u8, cmd, "log")) {
        var lines: ?usize = null;
        var follow = true; // 默认持续刷新
        var i: usize = 2;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "-n")) {
                if (i + 1 < args.len) {
                    lines = std.fmt.parseInt(usize, args[i + 1], 10) catch 50;
                    i += 1;
                }
            } else if (std.mem.eql(u8, args[i], "-f")) {
                follow = true;
            } else if (std.mem.eql(u8, args[i], "--no-follow")) {
                follow = false;
            }
        }
        // 如果没有指定 -n，默认显示 50 行
        if (lines == null and !follow) {
            lines = 50;
        }
        try daemon.viewLog(allocator, lines, follow);
        return;
    }

    // 处理 config 子命令
    if (std.mem.eql(u8, cmd, "config")) {
        if (args.len < 3) {
            try printConfigHelp();
            return;
        }
        
        const subcmd = args[2];
        
        if (std.mem.eql(u8, subcmd, "list") or std.mem.eql(u8, subcmd, "ls")) {
            try config.listConfigs(allocator);
            return;
        }
        
        if (std.mem.eql(u8, subcmd, "use")) {
            if (args.len < 4) {
                std.debug.print("Usage: zclash config use <configname>\n", .{});
                return;
            }
            try config.switchConfig(allocator, args[3]);
            return;
        }
        
        if (std.mem.eql(u8, subcmd, "download")) {
            if (args.len < 4) {
                std.debug.print("Usage: zclash config download <url> [-n <name>] [-d]\n", .{});
                return;
            }
            
            const url = args[3];
            var download_name: ?[]const u8 = null;
            var set_default = false;
            
            var i: usize = 4;
            while (i < args.len) : (i += 1) {
                if (std.mem.eql(u8, args[i], "-n")) {
                    if (i + 1 < args.len) {
                        download_name = args[i + 1];
                        i += 1;
                    }
                } else if (std.mem.eql(u8, args[i], "-d")) {
                    set_default = true;
                }
            }
            
            const filename = try config.downloadConfig(allocator, url, download_name);
            defer if (filename) |f| allocator.free(f);
            
            if (set_default and filename != null) {
                try config.switchConfig(allocator, filename.?);
            }
            return;
        }
        
        // 未知子命令
        std.debug.print("Unknown config subcommand: {s}\n", .{subcmd});
        try printConfigHelp();
        return;
    }

    // 处理 proxy 子命令
    if (std.mem.eql(u8, cmd, "proxy")) {
        if (args.len < 3) {
            try printProxyHelp();
            return;
        }

        const subcmd = args[2];

        if (std.mem.eql(u8, subcmd, "list") or std.mem.eql(u8, subcmd, "ls")) {
            // 解析 -c 参数
            var config_path: ?[]const u8 = null;
            var i: usize = 3;
            while (i < args.len) : (i += 1) {
                if (std.mem.eql(u8, args[i], "-c")) {
                    if (i + 1 < args.len) {
                        config_path = args[i + 1];
                        i += 1;
                    }
                }
            }

            // 加载配置
            var cfg = try loadAndValidateConfig(allocator, config_path);
            defer cfg.deinit();

            try proxy_cli.listProxies(allocator, &cfg);
            return;
        }

        if (std.mem.eql(u8, subcmd, "select")) {
            var group_name: ?[]const u8 = null;
            var proxy_name: ?[]const u8 = null;
            var config_path: ?[]const u8 = null;

            var i: usize = 3;
            while (i < args.len) : (i += 1) {
                if (std.mem.eql(u8, args[i], "-g")) {
                    if (i + 1 < args.len) {
                        group_name = args[i + 1];
                        i += 1;
                    }
                } else if (std.mem.eql(u8, args[i], "-p")) {
                    if (i + 1 < args.len) {
                        proxy_name = args[i + 1];
                        i += 1;
                    }
                } else if (std.mem.eql(u8, args[i], "-c")) {
                    if (i + 1 < args.len) {
                        config_path = args[i + 1];
                        i += 1;
                    }
                }
            }

            // 加载配置（需要可变引用）
            var cfg = try loadAndValidateConfig(allocator, config_path);
            defer cfg.deinit();

            try proxy_cli.selectProxy(allocator, &cfg, group_name, proxy_name);
            return;
        }

        // 未知子命令
        std.debug.print("Unknown proxy subcommand: {s}\n", .{subcmd});
        try printProxyHelp();
        return;
    }

    // 处理 test 命令
    if (std.mem.eql(u8, cmd, "test")) {
        var config_path: ?[]const u8 = null;
        var proxy_name: ?[]const u8 = null;

        var i: usize = 2;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "-c")) {
                if (i + 1 < args.len) {
                    config_path = args[i + 1];
                    i += 1;
                }
            } else if (std.mem.eql(u8, args[i], "-p")) {
                if (i + 1 < args.len) {
                    proxy_name = args[i + 1];
                    i += 1;
                }
            }
        }

        // 加载配置
        var cfg = try loadAndValidateConfig(allocator, config_path);
        defer cfg.deinit();

        try test_cli.testProxy(allocator, &cfg, proxy_name);
        return;
    }

    // 未知命令
    std.debug.print("Unknown command: {s}\n", .{cmd});
    try printHelp();
}

fn runProxy(allocator: std.mem.Allocator, config_path: ?[]const u8, use_tui: bool) !void {
    std.debug.print("zclash v0.1.0\n", .{});

    // 保存配置路径用于重载
    if (config_path) |path| {
        g_config_path = try allocator.dupe(u8, path);
    }

    // 加载并验证配置
    var cfg = try loadAndValidateConfig(allocator, config_path);
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
        
        while (true) {
            std.Thread.sleep(1 * std.time.ns_per_s);
        }
    }
}

fn loadAndValidateConfig(allocator: std.mem.Allocator, config_path: ?[]const u8) !config.Config {
    var cfg = if (config_path) |path|
        try config.load(allocator, path)
    else
        try config.loadDefault(allocator);

    var validation_result = try validator.validate(allocator, &cfg);
    defer validation_result.deinit();
    validator.printResult(&validation_result);
    
    if (!validation_result.isValid()) {
        cfg.deinit();
        std.process.exit(1);
    }
    
    return cfg;
}

fn proxyThreadFn(allocator: std.mem.Allocator, cfg: *const config.Config, engine: *rule_engine.Engine, manager: *outbound.OutboundManager) void {
    std.Thread.sleep(100 * std.time.ns_per_ms);

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
    
    var tui_manager = try tui.TuiManager.init(allocator, cfg);
    defer tui_manager.deinit();

    // 设置重载回调
    tui_manager.setReloadCallback(struct {
        fn reload() void {
            std.debug.print("\nConfiguration reload requested\n", .{});
        }
    }.reload);

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
    std.debug.print("\n", .{});
    std.debug.print("zclash v0.1.0 - A high-performance proxy tool in Zig\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("USAGE:\n", .{});
    std.debug.print("    zclash <command> [options]\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("COMMANDS:\n", .{});
    std.debug.print("    help                    Show this help message\n", .{});
    std.debug.print("    tui                     Start TUI dashboard\n", .{});
    std.debug.print("    start [-c <config>]     Start proxy in background\n", .{});
    std.debug.print("    stop                    Stop proxy\n", .{});
    std.debug.print("    restart [-c <config>]   Restart proxy\n", .{});
    std.debug.print("    status                  Show proxy status\n", .{});
    std.debug.print("    log [-n <lines>]        View logs\n", .{});
    std.debug.print("    config <subcmd>         Manage configurations\n", .{});
    std.debug.print("    proxy <subcmd>          Manage proxies\n", .{});
    std.debug.print("    test [-c <config>]      Test proxy connection\n", .{});
    std.debug.print("         [-p <proxy>]       Test specific proxy node\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("CONFIG COMMANDS:\n", .{});
    std.debug.print("    zclash config list                  List all available configs\n", .{});
    std.debug.print("    zclash config ls                    Alias for list\n", .{});
    std.debug.print("    zclash config download <url>        Download config from URL\n", .{});
    std.debug.print("                            -n <name>   Config filename (default: timestamp)\n", .{});
    std.debug.print("                            -d          Set as default after download\n", .{});
    std.debug.print("    zclash config use <configname>     Switch to specified config\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("PROXY COMMANDS:\n", .{});
    std.debug.print("    zclash proxy list                   List all proxy groups and nodes\n", .{});
    std.debug.print("    zclash proxy ls                     Alias for list\n", .{});
    std.debug.print("    zclash proxy select                 Show proxy selection UI\n", .{});
    std.debug.print("    zclash proxy select -g <group>      Select proxy for specific group\n", .{});
    std.debug.print("    zclash proxy select -g <group>      Select specific proxy\n", .{});
    std.debug.print("              -p <proxy>\n", .{});
    std.debug.print("EXAMPLES:\n", .{});
    std.debug.print("    # Start proxy in background\n", .{});
    std.debug.print("    zclash start\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("    # Start with specific config\n", .{});
    std.debug.print("    zclash start -c /path/to/config.yaml\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("    # Start TUI\n", .{});
    std.debug.print("    zclash tui\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("    # Check status\n", .{});
    std.debug.print("    zclash status\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("    # View logs (default: last 50 lines, auto-refresh)\n", .{});
    std.debug.print("    zclash log\n", .{});
    std.debug.print("    zclash log -n 100              # Show last 100 lines\n", .{});
    std.debug.print("    zclash log --no-follow         # Show last 50 lines without refresh\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("    # Download a config\n", .{});
    std.debug.print("    zclash config download https://example.com/config.yaml\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("    # Download and set as default\n", .{});
    std.debug.print("    zclash config download https://example.com/config.yaml -n myconfig -d\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("    # List all configs\n", .{});
    std.debug.print("    zclash config list\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("    # Switch config\n", .{});
    std.debug.print("    zclash config use myconfig.yaml\n", .{});
    std.debug.print("\n", .{});
}

fn printConfigHelp() !void {
    std.debug.print("\n", .{});
    std.debug.print("zclash config - Manage configurations\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("USAGE:\n", .{});
    std.debug.print("    zclash config list                  List all available configs\n", .{});
    std.debug.print("    zclash config ls                    Alias for list\n", .{});
    std.debug.print("    zclash config download <url>        Download config from URL\n", .{});
    std.debug.print("                            -n <name>   Config filename (default: timestamp)\n", .{});
    std.debug.print("                            -d          Set as default after download\n", .{});
    std.debug.print("    zclash config use <configname>     Switch to specified config\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("EXAMPLES:\n", .{});
    std.debug.print("    zclash config download https://example.com/config.yaml\n", .{});
    std.debug.print("    zclash config download https://example.com/config.yaml -n myconfig -d\n", .{});
    std.debug.print("    zclash config list\n", .{});
    std.debug.print("    zclash config use myconfig.yaml\n", .{});
    std.debug.print("\n", .{});
}

fn printProxyHelp() !void {
    std.debug.print("\n", .{});
    std.debug.print("zclash proxy - Manage proxies\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("USAGE:\n", .{});
    std.debug.print("    zclash proxy list                   List all proxy groups and nodes\n", .{});
    std.debug.print("    zclash proxy ls                     Alias for list\n", .{});
    std.debug.print("    zclash proxy select                 Show proxy selection UI\n", .{});
    std.debug.print("    zclash proxy select -g <group>      Select proxy for specific group\n", .{});
    std.debug.print("    zclash proxy select -g <group>      Select specific proxy\n", .{});
    std.debug.print("              -p <proxy>\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("EXAMPLES:\n", .{});
    std.debug.print("    zclash proxy list\n", .{});
    std.debug.print("    zclash proxy select                 # Show selection UI\n", .{});
    std.debug.print("    zclash proxy select -g Proxy -p HK  # Select HK in Proxy group\n", .{});
    std.debug.print("\n", .{});
}
