const std = @import("std");
const testing = std.testing;

// HTTP proxy tests
test "HTTP CONNECT request format" {
    const host = "www.example.com";
    const port: u16 = 443;
    
    var request: [256]u8 = undefined;
    const written = try std.fmt.bufPrint(&request,
        "CONNECT {s}:{d} HTTP/1.1\r\nHost: {s}:{d}\r\n\r\n",
        .{ host, port, host, port }
    );
    
    try testing.expect(std.mem.startsWith(u8, written, "CONNECT"));
    try testing.expect(std.mem.indexOf(u8, written, "www.example.com:443") != null);
}

test "HTTP GET request format" {
    const host = "www.example.com";
    const path = "/test";
    
    var request: [256]u8 = undefined;
    const written = try std.fmt.bufPrint(&request,
        "GET {s} HTTP/1.1\r\nHost: {s}\r\n\r\n",
        .{ path, host }
    );
    
    try testing.expect(std.mem.startsWith(u8, written, "GET /test"));
    try testing.expect(std.mem.indexOf(u8, written, "Host: www.example.com") != null);
}

test "HTTP method parsing" {
    const methods = [_][]const u8{ "GET", "POST", "PUT", "DELETE", "CONNECT", "HEAD", "OPTIONS", "PATCH" };
    
    for (methods) |method| {
        try testing.expect(method.len > 0);
        try testing.expect(method.len < 10);
    }
}

test "HTTP header Host extraction" {
    const request = "GET / HTTP/1.1\r\nHost: www.example.com\r\nUser-Agent: test\r\n\r\n";
    
    const host_prefix = "Host: ";
    const host_start = std.mem.indexOf(u8, request, host_prefix).? + host_prefix.len;
    const host_end = std.mem.indexOf(u8, request[host_start..], "\r\n").?;
    const host = request[host_start..host_start + host_end];
    
    try testing.expectEqualStrings("www.example.com", host);
}

test "HTTP URI parsing" {
    const uri = "/path/to/resource?query=value";
    
    const path_end = std.mem.indexOf(u8, uri, "?") orelse uri.len;
    const path = uri[0..path_end];
    
    try testing.expectEqualStrings("/path/to/resource", path);
}
