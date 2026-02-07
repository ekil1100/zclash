const std = @import("std");
const net = std.net;
const posix = std.posix;

/// TUI 状态
pub const TuiState = struct {
    running: bool = true,
    selected_row: usize = 0,
    current_proxy: []const u8 = "DIRECT",
    upload_speed: u64 = 0,
    download_speed: u64 = 0,
    active_connections: usize = 0,
    log_messages: std.ArrayList([]const u8),
    proxy_list: std.ArrayList([]const u8),
    
    pub fn init() TuiState {
        return .{
            .log_messages = std.ArrayList([]const u8).empty,
            .proxy_list = std.ArrayList([]const u8).empty,
        };
    }
    
    pub fn deinit(self: *TuiState, allocator: std.mem.Allocator) void {
        for (self.log_messages.items) |msg| {
            allocator.free(msg);
        }
        self.log_messages.deinit(allocator);
        
        for (self.proxy_list.items) |proxy| {
            allocator.free(proxy);
        }
        self.proxy_list.deinit(allocator);
    }
};

/// TUI 管理器
pub const TuiManager = struct {
    allocator: std.mem.Allocator,
    state: TuiState,
    original_termios: posix.termios,
    
    pub fn init(allocator: std.mem.Allocator) !TuiManager {
        var manager = TuiManager{
            .allocator = allocator,
            .state = TuiState.init(),
            .original_termios = undefined,
        };
        
        // 保存原始终端设置
        manager.original_termios = try posix.tcgetattr(posix.STDIN_FILENO);
        
        // 设置终端为 raw 模式
        var raw = manager.original_termios;
        raw.lflag.ECHO = false;
        raw.lflag.ICANON = false;
        raw.lflag.ISIG = false;
        try posix.tcsetattr(posix.STDIN_FILENO, .FLUSH, raw);
        
        // 隐藏光标
        try hideCursor();
        
        // 清屏
        try clearScreen();
        
        return manager;
    }
    
    pub fn deinit(self: *TuiManager) void {
        // 恢复终端设置
        posix.tcsetattr(posix.STDIN_FILENO, .FLUSH, self.original_termios) catch {};
        
        // 显示光标
        showCursor() catch {};
        
        // 清屏
        clearScreen() catch {};
        
        self.state.deinit(self.allocator);
    }
    
    /// 运行 TUI 主循环
    pub fn run(self: *TuiManager) !void {
        var buf: [1]u8 = undefined;
        
        while (self.state.running) {
            // 绘制界面
            try self.draw();
            
            // 非阻塞读取输入
            const n = posix.read(posix.STDIN_FILENO, &buf) catch 0;
            
            if (n > 0) {
                switch (buf[0]) {
                    'q', 'Q' => self.state.running = false,
                    'j', 'J', 0x42 => { // 下箭头
                        if (self.state.selected_row + 1 < self.state.proxy_list.items.len) {
                            self.state.selected_row += 1;
                        }
                    },
                    'k', 'K', 0x41 => { // 上箭头
                        if (self.state.selected_row > 0) {
                            self.state.selected_row -= 1;
                        }
                    },
                    '\r', '\n' => { // Enter
                        if (self.state.selected_row < self.state.proxy_list.items.len) {
                            self.state.current_proxy = self.state.proxy_list.items[self.state.selected_row];
                        }
                    },
                    else => {},
                }
            }
            
            // 刷新率控制
            std.Thread.sleep(50 * std.time.ns_per_ms);
        }
    }
    
    /// 绘制界面
    fn draw(self: *TuiManager) !void {
        // 清屏
        try clearScreen();
        
        // 标题
        try setBold();
        try setColor(36); // Cyan
        try printLine("╔══════════════════════════════════════════════════════════════╗");
        try printLine("║                    zclash TUI Dashboard                      ║");
        try printLine("╚══════════════════════════════════════════════════════════════╝");
        try resetColor();
        
        // 状态栏
        try printLine("");
        try setBold();
        try print("Current Proxy: ");
        try setColor(33); // Yellow
        try printLine(self.state.current_proxy);
        try resetColor();
        
        // 统计信息
        try printLine("");
        try setColor(90); // Bright black
        try printLine("───────────────── Statistics ─────────────────");
        try resetColor();
        
        try print("Upload:   ");
        try setColor(32); // Green
        try print(self.formatSpeed(self.state.upload_speed));
        try printLine("/s");
        try resetColor();
        
        try print("Download: ");
        try setColor(32); // Green
        try print(self.formatSpeed(self.state.download_speed));
        try printLine("/s");
        try resetColor();
        
        try print("Active:   ");
        try setColor(34); // Blue
        try printInt(self.state.active_connections);
        try printLine(" connections");
        try resetColor();
        
        // 代理列表
        try printLine("");
        try setColor(90);
        try printLine("───────────────── Proxies ───────────────────");
        try resetColor();
        
        for (self.state.proxy_list.items, 0..) |proxy, i| {
            if (i == self.state.selected_row) {
                try setColor(7); // Reverse
                try setBold();
                try print("> ");
                try print(proxy);
                
                // 填充空格
                const padding = 40 - proxy.len;
                if (padding > 0) {
                    var j: usize = 0;
                    while (j < padding) : (j += 1) {
                        try print(" ");
                    }
                }
                
                try printLine(" <");
                try resetColor();
            } else {
                try print("  ");
                try printLine(proxy);
            }
        }
        
        // 日志区域
        try printLine("");
        try setColor(90);
        try printLine("───────────────── Logs ──────────────────────");
        try resetColor();
        
        const log_start = if (self.state.log_messages.items.len > 5) 
            self.state.log_messages.items.len - 5 
        else 
            0;
        
        for (self.state.log_messages.items[log_start..]) |msg| {
            // 截断长消息
            if (msg.len > 50) {
                try print(msg[0..50]);
                try printLine("...");
            } else {
                try printLine(msg);
            }
        }
        
        // 帮助信息
        try printLine("");
        try setColor(90);
        try printLine("───────────────── Help ──────────────────────");
        try resetColor();
        try printLine("j/k or ↑/↓: Navigate  Enter: Select  q: Quit");
    }
    
    fn formatSpeed(self: *TuiManager, bytes_per_sec: u64) []const u8 {
        _ = self;
        
        if (bytes_per_sec < 1024) {
            return "0 B";
        } else if (bytes_per_sec < 1024 * 1024) {
            return "1 KB";
        } else if (bytes_per_sec < 1024 * 1024 * 1024) {
            return "1 MB";
        } else {
            return "1 GB";
        }
    }
    
    /// 添加代理
    pub fn addProxy(self: *TuiManager, name: []const u8) !void {
        try self.state.proxy_list.append(self.allocator, try self.allocator.dupe(u8, name));
    }
    
    /// 添加日志
    pub fn log(self: *TuiManager, message: []const u8) !void {
        const msg = try self.allocator.dupe(u8, message);
        try self.state.log_messages.append(self.allocator, msg);
        
        // 限制日志数量
        if (self.state.log_messages.items.len > 100) {
            const old = self.state.log_messages.orderedRemove(0);
            self.allocator.free(old);
        }
    }
    
    /// 更新统计
    pub fn updateStats(self: *TuiManager, upload: u64, download: u64, connections: usize) void {
        self.state.upload_speed = upload;
        self.state.download_speed = download;
        self.state.active_connections = connections;
    }
};

// ANSI 转义序列辅助函数 - 使用 std.debug.print

fn clearScreen() !void {
    std.debug.print("\x1B[2J\x1B[H", .{});
}

fn hideCursor() !void {
    std.debug.print("\x1B[?25l", .{});
}

fn showCursor() !void {
    std.debug.print("\x1B[?25h", .{});
}

fn moveCursor(row: usize, col: usize) !void {
    std.debug.print("\x1B[{d};{d}H", .{ row, col });
}

fn setBold() !void {
    std.debug.print("\x1B[1m", .{});
}

fn setColor(code: u8) !void {
    std.debug.print("\x1B[{d}m", .{ code });
}

fn resetColor() !void {
    std.debug.print("\x1B[0m", .{});
}

fn print(str: []const u8) !void {
    std.debug.print("{s}", .{str});
}

fn printLine(str: []const u8) !void {
    std.debug.print("{s}\n", .{str});
}

fn printInt(n: usize) !void {
    std.debug.print("{d}", .{n});
}
