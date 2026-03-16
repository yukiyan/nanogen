const std = @import("std");

/// Decode standard base64-encoded data. Caller owns returned slice.
pub fn decode(allocator: std.mem.Allocator, encoded: []const u8) ![]const u8 {
    const decoder = std.base64.standard.Decoder;
    const size = try decoder.calcSizeForSlice(encoded);
    const buf = try allocator.alloc(u8, size);
    errdefer allocator.free(buf);
    try decoder.decode(buf, encoded);
    return buf;
}

test "decode valid base64" {
    const allocator = std.testing.allocator;
    const result = try decode(allocator, "SGVsbG8gV29ybGQ=");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("Hello World", result);
}

test "decode empty" {
    const allocator = std.testing.allocator;
    const result = try decode(allocator, "");
    defer allocator.free(result);
    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "decode png-like data" {
    const allocator = std.testing.allocator;
    // Base64 of bytes [0x89, 0x50, 0x4E, 0x47] = PNG header
    const result = try decode(allocator, "iVBORw==");
    defer allocator.free(result);
    try std.testing.expectEqual(@as(u8, 0x89), result[0]);
    try std.testing.expectEqual(@as(u8, 'P'), result[1]);
    try std.testing.expectEqual(@as(u8, 'N'), result[2]);
    try std.testing.expectEqual(@as(u8, 'G'), result[3]);
}

test "decode invalid base64" {
    const allocator = std.testing.allocator;
    const result = decode(allocator, "!!!invalid!!!");
    try std.testing.expect(std.meta.isError(result));
}
