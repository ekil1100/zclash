const std = @import("std");

const Parser = struct {
    source: []const u8,
    pos: usize = 0,

    fn printContext(self: *Parser) void {
        const start = if (self.pos > 20) self.pos - 20 else 0;
        const end = @min(self.pos + 20, self.source.len);
        std.debug.print("Context: \"{s}\" (pos={d})\n", .{self.source[start..end], self.pos});
    }

    fn skipWhitespace(self: *Parser) void {
        while (self.pos < self.source.len) {
            if (self.source[self.pos] == ' ' or self.source[self.pos] == '\t') {
                self.pos += 1;
            } else break;
        }
    }

    fn skipLine(self: *Parser) void {
        while (self.pos < self.source.len and self.source[self.pos] != '\n') {
            self.pos += 1;
        }
        if (self.pos < self.source.len) self.pos += 1;
    }

    fn countIndent(self: *Parser) usize {
        var count: usize = 0;
        while (self.pos < self.source.len) {
            if (self.source[self.pos] == ' ') {
                count += 1;
                self.pos += 1;
            } else if (self.source[self.pos] == '\t') {
                count += 4;
                self.pos += 1;
            } else break;
        }
        return count;
    }
};

pub fn main() !void {
    const yaml = 
        \\proxies:
        \\  - name: test
    ;

    var p = Parser{ .source = yaml };
    
    // First line
    std.debug.print("Line 1:\n", .{});
    const indent1 = p.countIndent();
    std.debug.print("  indent: {d}\n", .{indent1});
    p.printContext();
    p.skipLine();
    
    // Second line
    std.debug.print("\nLine 2:\n", .{});
    const indent2 = p.countIndent();
    std.debug.print("  indent: {d}\n", .{indent2});
    p.printContext();
}
