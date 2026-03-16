const std = @import("std");
const fs = @import("fs.zig");

pub const Logger = struct {
    verbose: bool,
    file: ?std.fs.File = null,

    pub fn init(verbose: bool, log_path: ?[]const u8) Logger {
        var file: ?std.fs.File = null;
        if (log_path) |p| {
            // Ensure parent dir
            if (std.fs.path.dirname(p)) |dir| {
                fs.ensureDir(dir) catch {};
            }
            file = std.fs.cwd().createFile(p, .{}) catch null;
        }
        return .{ .verbose = verbose, .file = file };
    }

    pub fn deinit(self: *Logger) void {
        if (self.file) |f| f.close();
        self.file = null;
    }

    pub fn info(self: Logger, comptime fmt: []const u8, args: anytype) void {
        self.write("[INFO] ", fmt, args);
    }

    pub fn debug(self: Logger, comptime fmt: []const u8, args: anytype) void {
        if (!self.verbose) return;
        self.write("[DEBUG] ", fmt, args);
    }

    pub fn err(self: Logger, comptime fmt: []const u8, args: anytype) void {
        self.write("[ERROR] ", fmt, args);
    }

    fn write(self: Logger, prefix: []const u8, comptime fmt: []const u8, args: anytype) void {
        const stderr = std.fs.File.stderr().deprecatedWriter();
        stderr.writeAll(prefix) catch {};
        stderr.print(fmt, args) catch {};
        stderr.writeAll("\n") catch {};

        if (self.file) |f| {
            const w = f.deprecatedWriter();
            w.writeAll(prefix) catch {};
            w.print(fmt, args) catch {};
            w.writeAll("\n") catch {};
        }
    }
};

test "logger basic" {
    var logger = Logger.init(false, null);
    defer logger.deinit();
    // Should not panic
    logger.info("test {s}", .{"msg"});
    logger.err("error {d}", .{42});
    // Debug should be suppressed
    logger.debug("should not appear", .{});
}

test "logger verbose" {
    var logger = Logger.init(true, null);
    defer logger.deinit();
    logger.debug("debug visible", .{});
}

test "logger with file" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = tmp.dir.realpathAlloc(std.testing.allocator, ".") catch unreachable;
    defer std.testing.allocator.free(path);
    const full = std.fmt.allocPrint(std.testing.allocator, "{s}/test.log", .{path}) catch unreachable;
    defer std.testing.allocator.free(full);

    var logger = Logger.init(true, full);
    logger.info("hello", .{});
    logger.deinit();

    // Verify file was written
    const data = tmp.dir.readFileAlloc(std.testing.allocator, "test.log", 4096) catch unreachable;
    defer std.testing.allocator.free(data);
    try std.testing.expect(std.mem.indexOf(u8, data, "hello") != null);
}
