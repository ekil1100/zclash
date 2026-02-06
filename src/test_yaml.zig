const std = @import("std");

const YamlValue = union(enum) {
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

            std.debug.print("[parseMap] line={d}, indent={d}, base={d}, first={}\n", .{line_start, indent, base, first});

            if (first) {
                if (indent != base) {
                    std.debug.print("[parseMap] first item indent != base, break\n", .{});
                    self.pos = line_start;
                    break;
                }
            } else {
                if (indent < base) {
                    std.debug.print("[parseMap] indent < base, break\n", .{});
                    self.pos = line_start;
                    break;
                }
                const content_pos = line_start + indent;
                if (content_pos < self.source.len and self.source[content_pos] == '-') {
                    std.debug.print("[parseMap] new array item, break\n", .{});
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
            std.debug.print("[parseMap] key='{s}', pos after key={d}\n", .{key, self.pos});
            
            if (key.len == 0) break;

            while (self.pos < self.source.len and
                   (self.source[self.pos] == ' ' or self.source[self.pos] == '\t')) self.pos += 1;

            if (self.pos >= self.source.len or self.source[self.pos] != ':') {
                std.debug.print("[parseMap] no colon, break\n", .{});
                self.allocator.free(key);
                break;
            }
            self.pos += 1;

            while (self.pos < self.source.len and
                   (self.source[self.pos] == ' ' or self.source[self.pos] == '\t')) self.pos += 1;

            var val: YamlValue = .null;
            if (self.pos >= self.source.len or self.source[self.pos] == '\n' or self.source[self.pos] == '#') {
                std.debug.print("[parseMap] multi-line value\n", .{});
                if (self.pos < self.source.len) self.skipLine();

                if (self.pos < self.source.len) {
                    const next_line_start = self.pos;
                    const next_indent = self.getIndentAt(next_line_start);
                    std.debug.print("[parseMap] next_indent={d}\n", .{next_indent});

                    if (next_indent > indent) {
                        val = try self.parseValue(next_indent);
                    }
                }
            } else {
                val = try self.parseScalar();
                std.debug.print("[parseMap] scalar value type={s}\n", .{@tagName(val)});
                self.skipLine();
            }
            try m.put(key, val);
            std.debug.print("[parseMap] added key='{s}'\n", .{key});
            first = false;
        }
        std.debug.print("[parseMap] done, count={d}\n", .{m.count()});
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

            // Check for dash at content position
            const content_pos = line_start + indent;
            if (content_pos >= self.source.len or self.source[content_pos] != '-') {
                self.pos = line_start;
                break;
            }

            // Move past dash and check what follows
            self.pos = content_pos + 1;
            while (self.pos < self.source.len and
                   (self.source[self.pos] == ' ' or self.source[self.pos] == '\t')) self.pos += 1;

            // Parse item - restore position for parseMap if needed
            const item = if (self.peekKey()) blk: {
                // Skip the dash for parseMap - it expects key: value format
                // But we need to tell it the correct base indent
                // The dash is at content_pos, key starts after dash+space
                self.pos = content_pos;  // Back to dash position for correct line detection
                const m = try self.parseMap(indent);
                break :blk m;
            } else try self.parseScalar();

            try arr.append(self.allocator, item);
            self.skipLine();
        }

        return YamlValue{ .array = arr };
    }

    fn parseValue(self: *Parser, base: usize) anyerror!YamlValue {
        while (self.pos < self.source.len) {
            const line_start = self.pos;
            const indent = self.getIndentAt(line_start);
            const content_start = line_start + indent;

            if (content_start >= self.source.len) return .null;
            if (self.source[content_start] == '\n') {
                self.pos = content_start + 1;
                continue;
            }
            if (self.source[content_start] == '#') {
                self.pos = content_start;
                self.skipLine();
                continue;
            }

            if (indent < base) {
                self.pos = line_start;
                return .null;
            }

            self.pos = line_start;

            if (self.source[content_start] == '-') return self.parseArray(base);

            self.pos = content_start;
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

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const a = gpa.allocator();

    const yaml = 
        \\port: 7890
        \\proxies:
        \\  - name: test
        \\    type: ss
        \\    server: 1.2.3.4
        \\rules:
        \\  - DOMAIN,google.com,PROXY
    ;

    std.debug.print("Input:\n{s}\n\n", .{yaml});

    var root = try parse(a, yaml);
    defer root.deinit(a);

    std.debug.print("=== Result ===\n", .{});

    if (root.map.get("port")) |p| {
        std.debug.print("port = {d}\n", .{p.integer});
    }

    if (root.map.get("proxies")) |p| {
        std.debug.print("proxies: {d} items\n", .{p.array.items.len});
        for (p.array.items, 0..) |*it, i| {
            std.debug.print("  [{d}] {s}:\n", .{i, @tagName(it.*)});
            if (it.* == .map) {
                std.debug.print("      (map has {d} keys)\n", .{it.map.count()});
                var iter = it.map.iterator();
                while (iter.next()) |e| {
                    std.debug.print("      {s} = {s}\n", .{e.key_ptr.*, @tagName(e.value_ptr.*)});
                }
            }
        }
    }

    if (root.map.get("rules")) |r| {
        std.debug.print("rules: {d} items\n", .{r.array.items.len});
    }
}
