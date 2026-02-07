const std = @import("std");
const testing = std.testing;
const dns = @import("protocol.zig");
const Message = dns.Message;
const QueryType = dns.QueryType;

test "DNS Message init" {
    const allocator = testing.allocator;

    var msg = Message.init(allocator);
    defer msg.deinit();

    try testing.expectEqual(@as(u16, 0), msg.id);
    try testing.expectEqual(@as(u16, 0), msg.flags);
    try testing.expectEqual(@as(usize, 0), msg.questions.items.len);
}

test "DNS createAQuery" {
    const allocator = testing.allocator;

    var msg = try dns.createAQuery(allocator, "example.com");
    defer msg.deinit();

    try testing.expectEqual(@as(usize, 1), msg.questions.items.len);
    try testing.expectEqualStrings("example.com", msg.questions.items[0].name);
    try testing.expectEqual(QueryType.a, msg.questions.items[0].qtype);
}

test "DNS encodeName" {
    const allocator = testing.allocator;

    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(allocator);

    try dns.encodeName(allocator, &buf, "example.com");

    // Should be: [7] 'e' 'x' 'a' 'm' 'p' 'l' 'e' [3] 'c' 'o' 'm' [0]
    try testing.expectEqual(@as(u8, 7), buf.items[0]);
    try testing.expectEqual(@as(u8, 'e'), buf.items[1]);
    try testing.expectEqual(@as(u8, 3), buf.items[8]);
    try testing.expectEqual(@as(u8, 'c'), buf.items[9]);
    try testing.expectEqual(@as(u8, 0), buf.items[12]);
}

test "DNS encodeName root" {
    const allocator = testing.allocator;

    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(allocator);

    try dns.encodeName(allocator, &buf, ".");
    try testing.expectEqual(@as(u8, 0), buf.items[0]);
}

test "DNS decodeName simple" {
    const allocator = testing.allocator;

    // Create encoded name: [7]example[3]com[0]
    var data = [_]u8{ 7, 'e', 'x', 'a', 'm', 'p', 'l', 'e', 3, 'c', 'o', 'm', 0 };
    var pos: usize = 0;

    const name = try dns.decodeName(allocator, &data, &pos);
    defer allocator.free(name);

    try testing.expectEqualStrings("example.com", name);
    try testing.expectEqual(@as(usize, 13), pos);
}

test "DNS getResponseCode" {
    const allocator = testing.allocator;

    var msg = Message.init(allocator);
    defer msg.deinit();

    // Response code is in lower 4 bits of flags
    msg.flags = 0x0000;
    try testing.expectEqual(dns.ResponseCode.no_error, msg.getResponseCode());

    msg.flags = 0x0003;
    try testing.expectEqual(dns.ResponseCode.name_error, msg.getResponseCode());
}

test "DNS isResponse" {
    const allocator = testing.allocator;

    var msg = Message.init(allocator);
    defer msg.deinit();

    // QR bit (bit 15) indicates response
    msg.flags = 0x0000;
    try testing.expect(!msg.isResponse());

    msg.flags = 0x8000;
    try testing.expect(msg.isResponse());
}
