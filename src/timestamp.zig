const std = @import("std");

/// Generate timestamp string "YYYYMMDD_HHMMSS" on the stack.
pub fn generate() [15]u8 {
    const epoch: u64 = @intCast(std.time.timestamp());
    const es = std.time.epoch.EpochSeconds{ .secs = epoch };
    const day = es.getEpochDay();
    const yd = day.calculateYearDay();
    const md = yd.calculateMonthDay();
    const ds = es.getDaySeconds();

    var buf: [15]u8 = undefined;
    _ = std.fmt.bufPrint(&buf, "{d:0>4}{d:0>2}{d:0>2}_{d:0>2}{d:0>2}{d:0>2}", .{
        yd.year,
        @as(u32, md.month.numeric()),
        @as(u32, md.day_index + 1),
        ds.getHoursIntoDay(),
        ds.getMinutesIntoHour(),
        ds.getSecondsIntoMinute(),
    }) catch unreachable;
    return buf;
}

test "timestamp format" {
    const ts = generate();
    // Length must be 15
    try std.testing.expectEqual(@as(usize, 15), ts.len);
    // Underscore at position 8
    try std.testing.expectEqual(@as(u8, '_'), ts[8]);
    // All other chars are digits
    for (ts, 0..) |c, i| {
        if (i == 8) continue;
        try std.testing.expect(c >= '0' and c <= '9');
    }
}

test "timestamp year range" {
    const ts = generate();
    const year = std.fmt.parseInt(u16, ts[0..4], 10) catch unreachable;
    try std.testing.expect(year >= 2024 and year <= 2100);
}
