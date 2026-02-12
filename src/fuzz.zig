const std = @import("std");

// Fuzz target for config parsing
// Run with: zig build --fuzz

export fn zig_fuzz_init() void {
    // Initialize any resources needed for fuzzing
}

export fn zig_fuzz_test(buf: [*]u8, len: isize) void {
    if (len <= 0) return;
    
    const input = buf[0..@intCast(len)];
    
    // Try to parse as YAML config
    // This will exercise the config parser with random inputs
    _ = input;
    
    // TODO: Add actual config parsing fuzz target
    // const allocator = std.heap.page_allocator;
    // _ = config.parse(allocator, input) catch {};
}

// Standard test for fuzz infrastructure
test "fuzz target compiles" {
    zig_fuzz_init();
    var buf = [_]u8{ 1, 2, 3, 4, 5 };
    zig_fuzz_test(&buf, 5);
}
