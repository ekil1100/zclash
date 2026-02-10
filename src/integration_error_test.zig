const std = @import("std");

fn runCli(allocator: std.mem.Allocator, args: []const []const u8) ![]u8 {
    var argv = std.ArrayList([]const u8).empty;
    defer argv.deinit(allocator);

    try argv.append(allocator, "zig");
    try argv.append(allocator, "run");
    try argv.append(allocator, "src/main.zig");
    try argv.append(allocator, "--");
    for (args) |a| try argv.append(allocator, a);

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv.items,
    });

    if (result.stdout.len > 0 and result.stderr.len == 0) {
        allocator.free(result.stderr);
        return result.stdout;
    }

    if (result.stderr.len > 0 and result.stdout.len == 0) {
        allocator.free(result.stdout);
        return result.stderr;
    }

    const merged = try std.mem.concat(allocator, u8, &.{ result.stdout, result.stderr });
    allocator.free(result.stdout);
    allocator.free(result.stderr);
    return merged;
}

fn expectErrorEnvelope(output: []const u8, code: []const u8) !void {
    try std.testing.expect(std.mem.indexOf(u8, output, "\"ok\":false") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"error\":{") != null);

    const code_pattern = try std.fmt.allocPrint(std.testing.allocator, "\"code\":\"{s}\"", .{code});
    defer std.testing.allocator.free(code_pattern);
    try std.testing.expect(std.mem.indexOf(u8, output, code_pattern) != null);

    try std.testing.expect(std.mem.indexOf(u8, output, "\"message\":") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"hint\":") != null);
}

test "integration: profile path returns structured error" {
    const allocator = std.testing.allocator;
    const out = try runCli(allocator, &.{ "profile", "use", "not-exist.yaml", "--json" });
    defer allocator.free(out);

    try expectErrorEnvelope(out, "PROFILE_NOT_FOUND");
}

test "integration: proxy path returns structured error" {
    const allocator = std.testing.allocator;
    const out = try runCli(allocator, &.{ "proxy", "nope", "--json" });
    defer allocator.free(out);

    try expectErrorEnvelope(out, "PROXY_SUBCOMMAND_UNKNOWN");
}

test "integration: diag path returns structured error" {
    const allocator = std.testing.allocator;
    const out = try runCli(allocator, &.{ "diag", "nope", "--json" });
    defer allocator.free(out);

    try expectErrorEnvelope(out, "DIAG_SUBCOMMAND_UNKNOWN");
}
