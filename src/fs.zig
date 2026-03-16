const std = @import("std");

/// Get XDG_CONFIG_HOME or fallback to ~/.config
pub fn getConfigHome(allocator: std.mem.Allocator) ![]const u8 {
    if (std.posix.getenv("XDG_CONFIG_HOME")) |v| {
        return try allocator.dupe(u8, v);
    }
    const home = std.posix.getenv("HOME") orelse return error.NoHomeDir;
    return try std.fs.path.join(allocator, &.{ home, ".config" });
}

/// Get XDG_DATA_HOME or fallback to ~/.local/share
pub fn getDataHome(allocator: std.mem.Allocator) ![]const u8 {
    if (std.posix.getenv("XDG_DATA_HOME")) |v| {
        return try allocator.dupe(u8, v);
    }
    const home = std.posix.getenv("HOME") orelse return error.NoHomeDir;
    return try std.fs.path.join(allocator, &.{ home, ".local", "share" });
}

/// Ensure directory exists (creates recursively).
pub fn ensureDir(path: []const u8) !void {
    std.fs.cwd().makePath(path) catch |e| switch (e) {
        error.PathAlreadyExists => {},
        else => return e,
    };
}

/// Write data to file, creating parent directories as needed.
pub fn writeFile(path: []const u8, data: []const u8) !void {
    if (std.fs.path.dirname(path)) |dir| {
        try ensureDir(dir);
    }
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    try file.writeAll(data);
}

/// Read entire file into allocated buffer. Max 1MB.
pub fn readFileAlloc(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    return try file.readToEndAlloc(allocator, 1024 * 1024);
}

// Tests

test "ensureDir creates nested dirs" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = tmp.dir.realpathAlloc(std.testing.allocator, ".") catch unreachable;
    defer std.testing.allocator.free(base);

    const nested = std.fmt.allocPrint(std.testing.allocator, "{s}/a/b/c", .{base}) catch unreachable;
    defer std.testing.allocator.free(nested);

    try ensureDir(nested);
    // Should not error on second call
    try ensureDir(nested);

    var dir = try std.fs.cwd().openDir(nested, .{});
    dir.close();
}

test "writeFile and readFileAlloc" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = tmp.dir.realpathAlloc(std.testing.allocator, ".") catch unreachable;
    defer std.testing.allocator.free(base);

    const path = std.fmt.allocPrint(std.testing.allocator, "{s}/sub/test.txt", .{base}) catch unreachable;
    defer std.testing.allocator.free(path);

    try writeFile(path, "hello nanogen");

    const data = try readFileAlloc(std.testing.allocator, path);
    defer std.testing.allocator.free(data);
    try std.testing.expectEqualStrings("hello nanogen", data);
}

test "readFileAlloc nonexistent" {
    const result = readFileAlloc(std.testing.allocator, "/tmp/nonexistent_nanogen_test_file_xyz");
    try std.testing.expectError(error.FileNotFound, result);
}

test "getConfigHome with env" {
    // Can't easily set env in tests, but verify fallback logic
    const allocator = std.testing.allocator;
    // This should succeed if HOME is set (typical in CI/dev)
    if (getConfigHome(allocator)) |p| {
        defer allocator.free(p);
        try std.testing.expect(p.len > 0);
    } else |_| {
        // HOME not set, expected in some environments
    }
}
