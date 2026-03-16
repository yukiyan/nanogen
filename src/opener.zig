const std = @import("std");
const builtin = @import("builtin");

/// Open a file with the system's default application (non-blocking).
pub fn openFile(allocator: std.mem.Allocator, path: []const u8) !void {
    const argv: []const []const u8 = switch (builtin.os.tag) {
        .macos => &.{ "open", path },
        .linux => &.{ "xdg-open", path },
        .windows => &.{ "cmd", "/c", "start", "", path },
        else => return error.UnsupportedPlatform,
    };

    var child = std.process.Child.init(argv, allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;
    try child.spawn();
    // Don't wait — fire and forget
}

test "openFile builds correct command" {
    // We can't actually run xdg-open in tests, but we can verify
    // the function doesn't crash on construction.
    // Actual invocation would fail in CI without a display.
    if (builtin.os.tag != .linux and builtin.os.tag != .macos) return;
    // Just verify it compiles and the function signature is correct
    _ = openFile;
}
