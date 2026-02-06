const std = @import("std");

pub const YamlValue = union(enum) {
    null,
    boolean: bool,
    integer: i64,
    string: []const u8,
    array: std.ArrayList(YamlValue),
    map: std.StringHashMap(YamlValue),

    pub fn deinit(self: *YamlValue, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .string => |s| allocator.free(s),
            .array => |*arr| {
                for (arr.items) |*item| item.deinit(allocator);
                arr.deinit(allocator);
            },
            .map => |*m| {
                var it = m.iterator();
                while (it.next()) |e| {
                    allocator.free(e.key_ptr.*);
                    e.value_ptr.deinit(allocator);
                }
                m.deinit();
            },
            else => {},
        }
    }
};

const Parser = struct {
    allocator: std.mem.Allocator,
    source: []const u8,
    pos: usize = 0,

    fn getIndentAt(self: *Parser, at: usize) usize {
        var i = at;
        var c: usize = 0;
        while (i < self.source.len) {
            if (self.source[i] == ' ') { c += 1; i += 1; }
            else if (self.source[i] == '\t') { c += 4; i += 1; }
            else break;
        }
        return c;
    }

    fn skipLine(self: *Parser) void {
        while (self.pos < self.source.len and self.source[self.pos] != '\n') self.pos += 1;
        if (self.pos < self.source.len) self.pos += 1;
    }

    fn peekKey(self: *Parser) bool {
        const s = self.pos;
        defer self.pos = s;
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (c == ':') return true;
            if (c == ' ' or c == '\t' or c == '\n' or c == '\r') break;
            self.pos += 1;
        }
        return false;
    }

    fn parseKey(self: *Parser) ![]const u8 {
        const s = self.pos;
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (c == ':' or c == ' ' or c == '\t' or c == '\n') break;
            self.pos += 1;
        }
        return try self.allocator.dupe(u8, std.mem.trim(u8, self.source[s..self.pos], " \t"));
    }

    fn parseScalar(self: *Parser) !YamlValue {
        const s = self.pos;
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (c == '\n' or c == '#') break;
            self.pos += 1;
        }
        const str = std.mem.trim(u8, self.source[s..self.pos], " \t");
        if (str.len == 0) return .null;
        if (std.mem.eql(u8, str, "true")) return .{ .boolean = true };
        if (std.mem.eql(u8, str, "false")) return .{ .boolean = false };
        if (std.fmt.parseInt(i64, str, 10)) |n| {
            return .{ .integer = n };
        } else |_| {}
        return .{ .string = try self.allocator.dupe(u8, str) };
    }

    fn parseMap(self: *Parser, base: usize) anyerror!YamlValue {
        var m = std.StringHashMap(YamlValue).init(self.allocator);
        var first = true;

        while (self.pos < self.source.len) {
            // Find line start
            var line_start = self.pos;
            while (line_start > 0 and self.source[line_start - 1] != '\n') {
                line_start -= 1;
            }

            const indent = self.getIndentAt(line_start);

            if (first) {
                if (indent != base) {
                    self.pos = line_start;
                    break;
                }
            } else {
                if (indent < base) {
                    self.pos = line_start;
                    break;
                }
                const content_pos = line_start + indent;
                if (content_pos < self.source.len and self.source[content_pos] == '-') {
                    self.pos = line_start;
                    break;
                }
            }

            self.pos = line_start + indent;
            if (self.pos >= self.source.len) break;
            if (self.source[self.pos] == '\n') { self.pos = line_start; self.skipLine(); continue; }
            if (self.source[self.pos] == '#') { self.pos = line_start; self.skipLine(); continue; }

            // Skip dash if present (array item marker)
            if (self.source[self.pos] == '-') {
                self.pos += 1;
                while (self.pos < self.source.len and
                       (self.source[self.pos] == ' ' or self.source[self.pos] == '\t')) self.pos += 1;
            }

            const key = try self.parseKey();
            if (key.len == 0) break;

            while (self.pos < self.source.len and
                   (self.source[self.pos] == ' ' or self.source[self.pos] == '\t')) self.pos += 1;

            if (self.pos >= self.source.len or self.source[self.pos] != ':') {
                self.allocator.free(key);
                break;
            }
            self.pos += 1;

            while (self.pos < self.source.len and
                   (self.source[self.pos] == ' ' or self.source[self.pos] == '\t')) self.pos += 1;

            var val: YamlValue = .null;
            if (self.pos >= self.source.len or self.source[self.pos] == '\n' or self.source[self.pos] == '#') {
                if (self.pos < self.source.len) self.skipLine();

                if (self.pos < self.source.len) {
                    const next_line_start = self.pos;
                    const next_indent = self.getIndentAt(next_line_start);

                    if (next_indent > indent) {
                        val = try self.parseValue(next_indent);
                    }
                }
            } else {
                val = try self.parseScalar();
                self.skipLine();
            }
            try m.put(key, val);
            first = false;
        }
        return YamlValue{ .map = m };
    }

    fn parseArray(self: *Parser, base: usize) anyerror!YamlValue {
        var arr = std.ArrayList(YamlValue).empty;

        while (self.pos < self.source.len) {
            const line_start = self.pos;
            const indent = self.getIndentAt(line_start);

            if (indent < base) {
                self.pos = line_start;
                break;
            }

            const content_pos = line_start + indent;
            if (content_pos >= self.source.len or self.source[content_pos] != '-') {
                self.pos = line_start;
                break;
            }

            self.pos = content_pos + 1;
            while (self.pos < self.source.len and
                   (self.source[self.pos] == ' ' or self.source[self.pos] == '\t')) self.pos += 1;

            // Check if this is a map item or scalar
            // A map item has "key: value" format, not just contains ':'
            const is_map = blk: {
                const saved = self.pos;
                defer self.pos = saved;
                // Try to find ': ' or ':\n' pattern
                while (self.pos < self.source.len) {
                    if (self.source[self.pos] == ':') {
                        // Check if ':' is followed by space or newline (map separator)
                        // or end of line (key with empty value)
                        const next = self.pos + 1;
                        if (next >= self.source.len or 
                            self.source[next] == ' ' or 
                            self.source[next] == '\t' or
                            self.source[next] == '\n' or
                            self.source[next] == '\r') {
                            break :blk true;
                        }
                    }
                    if (self.source[self.pos] == '\n') break;
                    self.pos += 1;
                }
                break :blk false;
            };

            const item = if (is_map)
                try self.parseMap(base)
            else
                try self.parseScalar();

            try arr.append(self.allocator, item);
            self.skipLine();
        }

        return YamlValue{ .array = arr };
    }

    fn parseValue(self: *Parser, base: usize) anyerror!YamlValue {
        while (self.pos < self.source.len) {
            const line_start = self.pos;
            const indent = self.getIndentAt(line_start);
            const content_pos = line_start + indent;

            if (content_pos >= self.source.len) return .null;
            if (self.source[content_pos] == '\n') {
                self.pos = content_pos + 1;
                continue;
            }
            if (self.source[content_pos] == '#') {
                self.pos = content_pos;
                self.skipLine();
                continue;
            }

            if (indent < base) {
                self.pos = line_start;
                return .null;
            }

            self.pos = line_start;

            if (self.source[content_pos] == '-') return self.parseArray(base);

            self.pos = content_pos;
            if (self.peekKey()) return self.parseMap(base);
            return self.parseScalar();
        }
        return .null;
    }
};

pub fn parse(allocator: std.mem.Allocator, src: []const u8) !YamlValue {
    var p = Parser{ .allocator = allocator, .source = src };
    return try p.parseValue(0);
}
