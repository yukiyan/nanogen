const std = @import("std");

/// Escape a string for JSON (RFC 8259).
pub fn jsonEscape(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    var list: std.ArrayList(u8) = .empty;
    errdefer list.deinit(allocator);
    try list.ensureTotalCapacity(allocator, input.len + input.len / 8);

    for (input) |c| {
        switch (c) {
            '"' => try list.appendSlice(allocator, "\\\""),
            '\\' => try list.appendSlice(allocator, "\\\\"),
            '\n' => try list.appendSlice(allocator, "\\n"),
            '\r' => try list.appendSlice(allocator, "\\r"),
            '\t' => try list.appendSlice(allocator, "\\t"),
            0x08 => try list.appendSlice(allocator, "\\b"),
            0x0C => try list.appendSlice(allocator, "\\f"),
            else => {
                if (c < 0x20) {
                    // Control character: \u00XX
                    var buf: [6]u8 = undefined;
                    _ = std.fmt.bufPrint(&buf, "\\u{X:0>4}", .{c}) catch unreachable;
                    try list.appendSlice(allocator, &buf);
                } else {
                    try list.append(allocator, c);
                }
            },
        }
    }

    return try list.toOwnedSlice(allocator);
}

/// Sanitize prompt: remove control characters but keep printable + whitespace.
pub fn sanitizePrompt(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    var list: std.ArrayList(u8) = .empty;
    errdefer list.deinit(allocator);
    try list.ensureTotalCapacity(allocator, input.len);

    var i: usize = 0;
    while (i < input.len) {
        const byte = input[i];
        if (byte < 0x80) {
            // ASCII
            if (byte >= 0x20 or byte == '\t' or byte == '\n' or byte == '\r') {
                try list.append(allocator, byte);
            }
            // else: skip control char
            i += 1;
        } else {
            // Multi-byte UTF-8: keep as-is
            const len = std.unicode.utf8ByteSequenceLength(byte) catch {
                i += 1;
                continue;
            };
            if (i + len > input.len) break;
            try list.appendSlice(allocator, input[i .. i + len]);
            i += len;
        }
    }

    return try list.toOwnedSlice(allocator);
}

/// Build the Gemini generateContent JSON request body.
pub fn buildRequest(allocator: std.mem.Allocator, prompt: []const u8, aspect_ratio: []const u8, image_size: []const u8) ![]const u8 {
    const escaped = try jsonEscape(allocator, prompt);
    defer allocator.free(escaped);

    return try std.fmt.allocPrint(allocator,
        \\{{"contents":[{{"parts":[{{"text":"{s}"}}]}}],"tools":[{{"google_search":{{}}}}],"generationConfig":{{"responseModalities":["TEXT","IMAGE"],"imageConfig":{{"aspectRatio":"{s}","imageSize":"{s}"}}}}}}
    , .{ escaped, aspect_ratio, image_size });
}

// Tests

test "jsonEscape basic" {
    const allocator = std.testing.allocator;
    const result = try jsonEscape(allocator, "hello");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "jsonEscape special chars" {
    const allocator = std.testing.allocator;
    const result = try jsonEscape(allocator, "he said \"hi\"\nnew\\line");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("he said \\\"hi\\\"\\nnew\\\\line", result);
}

test "jsonEscape control chars" {
    const allocator = std.testing.allocator;
    const input = [_]u8{ 'a', 0x01, 'b' };
    const result = try jsonEscape(allocator, &input);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("a\\u0001b", result);
}

test "jsonEscape tab and cr" {
    const allocator = std.testing.allocator;
    const result = try jsonEscape(allocator, "a\tb\r\n");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("a\\tb\\r\\n", result);
}

test "sanitizePrompt removes control chars" {
    const allocator = std.testing.allocator;
    const input = [_]u8{ 'h', 'i', 0x00, 0x07, '!' };
    const result = try sanitizePrompt(allocator, &input);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hi!", result);
}

test "sanitizePrompt keeps whitespace" {
    const allocator = std.testing.allocator;
    const result = try sanitizePrompt(allocator, "hello\tworld\n");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello\tworld\n", result);
}

test "sanitizePrompt keeps unicode" {
    const allocator = std.testing.allocator;
    const result = try sanitizePrompt(allocator, "日本語テスト");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("日本語テスト", result);
}

test "buildRequest valid json" {
    const allocator = std.testing.allocator;
    const result = try buildRequest(allocator, "a cat", "16:9", "2K");
    defer allocator.free(result);

    // Verify it's valid JSON by parsing
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, result, .{});
    defer parsed.deinit();

    // Check structure
    const obj = parsed.value.object;
    try std.testing.expect(obj.contains("contents"));
    try std.testing.expect(obj.contains("generationConfig"));
    try std.testing.expect(obj.contains("tools"));
}

test "buildRequest escapes prompt" {
    const allocator = std.testing.allocator;
    const result = try buildRequest(allocator, "a \"quoted\" cat", "1:1", "4K");
    defer allocator.free(result);

    // Should contain escaped quotes
    try std.testing.expect(std.mem.indexOf(u8, result, "\\\"quoted\\\"") != null);

    // Should be valid JSON
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, result, .{});
    defer parsed.deinit();
}
