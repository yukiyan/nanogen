const std = @import("std");
const fs = @import("fs.zig");
const cli = @import("cli.zig");

pub const Config = struct {
    api_key: []const u8,
    model: []const u8,
    aspect_ratio: []const u8,
    image_size: []const u8,
    output_dir: []const u8,
    auto_open: bool,
    verbose: bool,
};

/// Load configuration with priority: CLI > env > config file > defaults.
/// All returned strings are owned by the arena allocator.
pub fn load(allocator: std.mem.Allocator, args: cli.Args) !Config {
    // Defaults
    var cfg = Config{
        .api_key = "",
        .model = "gemini-3-pro-image-preview",
        .aspect_ratio = "16:9",
        .image_size = "2K",
        .output_dir = "",
        .auto_open = true,
        .verbose = false,
    };

    // Try config file (best-effort)
    loadConfigFile(allocator, &cfg) catch {};

    // Environment variables
    if (env("NANOGEN_API_KEY")) |v| cfg.api_key = v;
    if (env("NANOGEN_MODEL")) |v| cfg.model = v;
    if (env("NANOGEN_ASPECT_RATIO")) |v| cfg.aspect_ratio = v;
    if (env("NANOGEN_IMAGE_SIZE")) |v| cfg.image_size = v;
    if (env("NANOGEN_OUTPUT_DIR")) |v| cfg.output_dir = v;
    if (env("NANOGEN_AUTO_OPEN")) |v| {
        cfg.auto_open = !std.mem.eql(u8, v, "false") and !std.mem.eql(u8, v, "0");
    }

    // CLI overrides
    if (args.model) |v| cfg.model = v;
    if (args.aspect_ratio) |v| cfg.aspect_ratio = v;
    if (args.image_size) |v| cfg.image_size = v;
    if (args.output) |o| cfg.output_dir = o;
    if (args.verbose) cfg.verbose = true;
    if (args.no_open) cfg.auto_open = false;

    // Default output dir if not set
    if (cfg.output_dir.len == 0) {
        const data_home = try fs.getDataHome(allocator);
        cfg.output_dir = try std.fs.path.join(allocator, &.{ data_home, "nanogen" });
    }

    return cfg;
}

fn env(name: []const u8) ?[]const u8 {
    return std.posix.getenv(name);
}

fn loadConfigFile(allocator: std.mem.Allocator, cfg: *Config) !void {
    const config_home = try fs.getConfigHome(allocator);
    const config_path = try std.fs.path.join(allocator, &.{ config_home, "nanogen", "config.json" });
    const data = try fs.readFileAlloc(allocator, config_path);

    const parsed = try std.json.parseFromSlice(ConfigFile, allocator, data, .{ .ignore_unknown_fields = true });
    const cf = parsed.value;

    if (cf.api_key) |v| cfg.api_key = v;
    if (cf.model) |v| cfg.model = v;
    if (cf.aspect_ratio) |v| cfg.aspect_ratio = v;
    if (cf.image_size) |v| cfg.image_size = v;
    if (cf.output_dir) |v| cfg.output_dir = v;
    if (cf.auto_open) |v| cfg.auto_open = v;
}

const ConfigFile = struct {
    api_key: ?[]const u8 = null,
    model: ?[]const u8 = null,
    aspect_ratio: ?[]const u8 = null,
    image_size: ?[]const u8 = null,
    output_dir: ?[]const u8 = null,
    auto_open: ?bool = null,
};

/// Get images subdirectory path.
pub fn imagesDir(allocator: std.mem.Allocator, output_dir: []const u8) ![]const u8 {
    return try std.fs.path.join(allocator, &.{ output_dir, "images" });
}

/// Get responses subdirectory path.
pub fn responsesDir(allocator: std.mem.Allocator, output_dir: []const u8) ![]const u8 {
    return try std.fs.path.join(allocator, &.{ output_dir, "responses" });
}

/// Get logs subdirectory path.
pub fn logsDir(allocator: std.mem.Allocator, output_dir: []const u8) ![]const u8 {
    return try std.fs.path.join(allocator, &.{ output_dir, "logs" });
}

// Tests

test "load defaults" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const args = cli.Args{};
    const cfg = try load(allocator, args);
    try std.testing.expectEqualStrings("16:9", cfg.aspect_ratio);
    try std.testing.expectEqualStrings("2K", cfg.image_size);
    try std.testing.expect(cfg.output_dir.len > 0);
}

test "cli overrides" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var args = cli.Args{};
    args.aspect_ratio = "4:3";
    args.image_size = "4K";
    args.verbose = true;
    args.no_open = true;
    args.output = "/tmp/test-nanogen";

    const cfg = try load(allocator, args);
    try std.testing.expectEqualStrings("4:3", cfg.aspect_ratio);
    try std.testing.expectEqualStrings("4K", cfg.image_size);
    try std.testing.expect(cfg.verbose);
    try std.testing.expect(!cfg.auto_open);
    try std.testing.expectEqualStrings("/tmp/test-nanogen", cfg.output_dir);
}

test "imagesDir" {
    const allocator = std.testing.allocator;
    const dir = try imagesDir(allocator, "/tmp/nanogen");
    defer allocator.free(dir);
    try std.testing.expectEqualStrings("/tmp/nanogen/images", dir);
}

test "responsesDir" {
    const allocator = std.testing.allocator;
    const dir = try responsesDir(allocator, "/tmp/nanogen");
    defer allocator.free(dir);
    try std.testing.expectEqualStrings("/tmp/nanogen/responses", dir);
}
