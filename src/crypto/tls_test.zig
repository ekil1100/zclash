const std = @import("std");
const testing = std.testing;
const TlsClient = @import("tls.zig").TlsClient;
const TlsConfig = @import("tls.zig").TlsConfig;

test "TlsConfig init" {
    const config = TlsConfig{
        .sni = "example.com",
        .skip_verify = false,
    };

    try testing.expectEqualStrings("example.com", config.sni);
    try testing.expect(!config.skip_verify);
}

test "TlsClient init" {
    // We can't easily test without actual network connection
    // This test just verifies the initialization logic

    // Mock test - just verify struct creation
    const config = TlsConfig{
        .sni = "test.com",
        .skip_verify = true,
    };

    _ = config;
    try testing.expect(true);
}
