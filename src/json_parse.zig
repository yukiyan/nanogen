const std = @import("std");

const InlineData = struct {
    data: []const u8 = "",
    mimeType: []const u8 = "",
};

const Part = struct {
    text: ?[]const u8 = null,
    inlineData: ?InlineData = null,
};

const Content = struct {
    parts: []const Part = &.{},
};

const Candidate = struct {
    content: ?Content = null,
};

const GenerateResponse = struct {
    candidates: []const Candidate = &.{},
};

pub const ParseResult = struct {
    image_base64: []const u8,
    text: ?[]const u8,
};

/// Extract image base64 data and optional text from Gemini generateContent response.
pub fn extractImageData(allocator: std.mem.Allocator, body: []const u8) !ParseResult {
    const parsed = try std.json.parseFromSlice(GenerateResponse, allocator, body, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_if_needed,
    });
    defer parsed.deinit();

    var image_data: ?[]const u8 = null;
    var text_data: ?[]const u8 = null;

    for (parsed.value.candidates) |candidate| {
        const content = candidate.content orelse continue;
        for (content.parts) |part| {
            if (part.inlineData) |inline_data| {
                if (inline_data.data.len > 0 and image_data == null) {
                    image_data = inline_data.data;
                }
            }
            if (part.text) |t| {
                if (t.len > 0 and text_data == null) {
                    text_data = t;
                }
            }
        }
    }

    const img = image_data orelse return error.NoImageData;
    return ParseResult{
        .image_base64 = try allocator.dupe(u8, img),
        .text = if (text_data) |t| try allocator.dupe(u8, t) else null,
    };
}

// Tests

test "extractImageData valid response" {
    const allocator = std.testing.allocator;
    const body =
        \\{"candidates":[{"content":{"parts":[{"text":"description"},{"inlineData":{"data":"iVBORw==","mimeType":"image/png"}}]}}]}
    ;
    const result = try extractImageData(allocator, body);
    defer allocator.free(result.image_base64);
    defer if (result.text) |t| allocator.free(t);
    try std.testing.expectEqualStrings("iVBORw==", result.image_base64);
    try std.testing.expectEqualStrings("description", result.text.?);
}

test "extractImageData no text" {
    const allocator = std.testing.allocator;
    const body =
        \\{"candidates":[{"content":{"parts":[{"inlineData":{"data":"AAAA","mimeType":"image/png"}}]}}]}
    ;
    const result = try extractImageData(allocator, body);
    defer allocator.free(result.image_base64);
    try std.testing.expectEqualStrings("AAAA", result.image_base64);
    try std.testing.expectEqual(@as(?[]const u8, null), result.text);
}

test "extractImageData no image" {
    const allocator = std.testing.allocator;
    const body =
        \\{"candidates":[{"content":{"parts":[{"text":"only text"}]}}]}
    ;
    const result = extractImageData(allocator, body);
    try std.testing.expectError(error.NoImageData, result);
}

test "extractImageData empty candidates" {
    const allocator = std.testing.allocator;
    const body =
        \\{"candidates":[]}
    ;
    const result = extractImageData(allocator, body);
    try std.testing.expectError(error.NoImageData, result);
}

test "extractImageData missing candidates" {
    const allocator = std.testing.allocator;
    const body =
        \\{}
    ;
    const result = extractImageData(allocator, body);
    try std.testing.expectError(error.NoImageData, result);
}

test "extractImageData ignores unknown fields" {
    const allocator = std.testing.allocator;
    const body =
        \\{"candidates":[{"content":{"parts":[{"inlineData":{"data":"AAAA","mimeType":"image/png"}}],"role":"model"},"finishReason":"STOP","extra":123}],"usageMetadata":{"promptTokenCount":10}}
    ;
    const result = try extractImageData(allocator, body);
    defer allocator.free(result.image_base64);
    try std.testing.expectEqualStrings("AAAA", result.image_base64);
}

test "extractImageData multiple parts picks first image" {
    const allocator = std.testing.allocator;
    const body =
        \\{"candidates":[{"content":{"parts":[{"inlineData":{"data":"FIRST","mimeType":"image/png"}},{"inlineData":{"data":"SECOND","mimeType":"image/png"}}]}}]}
    ;
    const result = try extractImageData(allocator, body);
    defer allocator.free(result.image_base64);
    try std.testing.expectEqualStrings("FIRST", result.image_base64);
}
