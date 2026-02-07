const std = @import("std");
const testing = std.testing;
const SmartGroup = @import("smart_group.zig").SmartGroup;
const SelectorType = @import("smart_group.zig").SelectorType;
const LoadBalanceStrategy = @import("smart_group.zig").LoadBalanceStrategy;

test "SmartGroup init" {
    const allocator = testing.allocator;

    const proxies = &[_][]const u8{ "Proxy1", "Proxy2", "Proxy3" };
    var group = try SmartGroup.init(allocator, "TestGroup", .select, proxies);
    defer group.deinit();

    try testing.expectEqualStrings("TestGroup", group.name);
    try testing.expectEqual(SelectorType.select, group.selector_type);
    try testing.expectEqual(@as(usize, 3), group.proxies.items.len);
}

test "SmartGroup select proxy - select type" {
    const allocator = testing.allocator;

    const proxies = &[_][]const u8{ "Proxy1", "Proxy2" };
    var group = try SmartGroup.init(allocator, "Test", .select, proxies);
    defer group.deinit();

    const proxy = try group.selectProxy();
    try testing.expectEqualStrings("Proxy1", proxy);
}

test "SmartGroup switch proxy" {
    const allocator = testing.allocator;

    const proxies = &[_][]const u8{ "Proxy1", "Proxy2" };
    var group = try SmartGroup.init(allocator, "Test", .select, proxies);
    defer group.deinit();

    try group.switchProxy("Proxy2");
    const proxy = try group.selectProxy();
    try testing.expectEqualStrings("Proxy2", proxy);
}

test "SmartGroup fallback selection" {
    const allocator = testing.allocator;

    const proxies = &[_][]const u8{ "Proxy1", "Proxy2" };
    var group = try SmartGroup.init(allocator, "Test", .fallback, proxies);
    defer group.deinit();

    // Without health check, should return first proxy
    const proxy = try group.selectProxy();
    try testing.expectEqualStrings("Proxy1", proxy);
}

test "SmartGroup load balance round robin" {
    const allocator = testing.allocator;

    const proxies = &[_][]const u8{ "Proxy1", "Proxy2", "Proxy3" };
    var group = try SmartGroup.init(allocator, "Test", .load_balance, proxies);
    defer group.deinit();

    group.strategy = .round_robin;

    // Should cycle through proxies
    const p1 = try group.selectProxy();
    const p2 = try group.selectProxy();
    const p3 = try group.selectProxy();
    const p4 = try group.selectProxy();

    try testing.expectEqualStrings("Proxy1", p1);
    try testing.expectEqualStrings("Proxy2", p2);
    try testing.expectEqualStrings("Proxy3", p3);
    try testing.expectEqualStrings("Proxy1", p4); // Cycle back
}
