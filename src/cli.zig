const std = @import("std");

pub const Args = struct {
    prompt: ?[]const u8 = null,
    file: ?[]const u8 = null,
    model: ?[]const u8 = null,
    aspect_ratio: ?[]const u8 = null,
    image_size: ?[]const u8 = null,
    output: ?[]const u8 = null,
    completions: ?[]const u8 = null,
    no_open: bool = false,
    verbose: bool = false,
    version: bool = false,
    help: bool = false,
};

pub const ParseError = error{
    UnknownFlag,
    MissingValue,
};

const ShortMap = struct {
    short: u8,
    long: []const u8,
};

const short_aliases = [_]ShortMap{
    .{ .short = 'p', .long = "prompt" },
    .{ .short = 'f', .long = "file" },
    .{ .short = 'o', .long = "output" },
    .{ .short = 'v', .long = "verbose" },
    .{ .short = 'h', .long = "help" },
};

fn resolveShort(c: u8) ?[]const u8 {
    for (short_aliases) |m| {
        if (m.short == c) return m.long;
    }
    return null;
}

/// Parse CLI arguments. Returns Args or error.
/// Caller does not own the returned slices; they point into argv memory.
pub fn parse(argv: []const [:0]const u8) ParseError!Args {
    var args = Args{};
    var i: usize = 0;
    while (i < argv.len) : (i += 1) {
        const arg: []const u8 = argv[i];
        if (arg.len == 0) continue;

        if (arg.len == 2 and arg[0] == '-' and arg[1] != '-') {
            // Short flag
            const long = resolveShort(arg[1]) orelse return ParseError.UnknownFlag;
            if (setFlag(&args, long)) {
                // bool flag, done
            } else {
                // needs value
                i += 1;
                if (i >= argv.len) return ParseError.MissingValue;
                const val: []const u8 = argv[i];
                setString(&args, long, val);
            }
        } else if (arg.len > 2 and arg[0] == '-' and arg[1] == '-') {
            const name = arg[2..];
            if (setFlag(&args, name)) {
                // bool flag, done
            } else if (isStringFlag(name)) {
                // needs value
                i += 1;
                if (i >= argv.len) return ParseError.MissingValue;
                const val: []const u8 = argv[i];
                setString(&args, name, val);
            } else {
                return ParseError.UnknownFlag;
            }
        } else {
            return ParseError.UnknownFlag;
        }
    }
    return args;
}

fn setFlag(args: *Args, name: []const u8) bool {
    if (std.mem.eql(u8, name, "no-open")) {
        args.no_open = true;
        return true;
    } else if (std.mem.eql(u8, name, "verbose")) {
        args.verbose = true;
        return true;
    } else if (std.mem.eql(u8, name, "version")) {
        args.version = true;
        return true;
    } else if (std.mem.eql(u8, name, "help")) {
        args.help = true;
        return true;
    }
    return false;
}

fn isStringFlag(name: []const u8) bool {
    const known = [_][]const u8{ "prompt", "file", "model", "aspect-ratio", "image-size", "output", "completions" };
    for (known) |k| {
        if (std.mem.eql(u8, name, k)) return true;
    }
    return false;
}

fn setString(args: *Args, name: []const u8, val: []const u8) void {
    if (std.mem.eql(u8, name, "prompt")) {
        args.prompt = val;
    } else if (std.mem.eql(u8, name, "file")) {
        args.file = val;
    } else if (std.mem.eql(u8, name, "model")) {
        args.model = val;
    } else if (std.mem.eql(u8, name, "aspect-ratio")) {
        args.aspect_ratio = val;
    } else if (std.mem.eql(u8, name, "image-size")) {
        args.image_size = val;
    } else if (std.mem.eql(u8, name, "output")) {
        args.output = val;
    } else if (std.mem.eql(u8, name, "completions")) {
        args.completions = val;
    }
}

pub fn printUsage(writer: anytype) !void {
    try writer.writeAll(
        \\Usage: nanogen [OPTIONS]
        \\
        \\Nanobanana image generation CLI
        \\
        \\Options:
        \\  -p, --prompt <TEXT>         Generation prompt
        \\  -f, --file <PATH>           Read prompt from file
        \\      --model <NAME>          Model name (default: gemini-3-pro-image-preview)
        \\      --aspect-ratio <RATIO>  Aspect ratio: 16:9, 4:3, 1:1, 9:16 (default: 16:9)
        \\      --image-size <SIZE>     Image size: 2K, 4K (default: 2K)
        \\  -o, --output <DIR>          Output directory
        \\      --completions <SHELL>    Generate shell completion (bash, zsh, fish)
        \\      --no-open               Don't auto-open generated image
        \\  -v, --verbose               Enable debug logging
        \\      --version               Show version
        \\  -h, --help                  Show this help
        \\
    );
}

// Tests

test "parse empty" {
    const argv = [_][:0]const u8{};
    const args = try parse(&argv);
    try std.testing.expectEqual(@as(?[]const u8, null), args.prompt);
    try std.testing.expect(!args.verbose);
    try std.testing.expect(!args.help);
}

test "parse prompt short" {
    const argv = [_][:0]const u8{ "-p", "hello world" };
    const args = try parse(&argv);
    try std.testing.expectEqualStrings("hello world", args.prompt.?);
}

test "parse prompt long" {
    const argv = [_][:0]const u8{ "--prompt", "test prompt" };
    const args = try parse(&argv);
    try std.testing.expectEqualStrings("test prompt", args.prompt.?);
}

test "parse bool flags" {
    const argv = [_][:0]const u8{ "--verbose", "--no-open", "--version" };
    const args = try parse(&argv);
    try std.testing.expect(args.verbose);
    try std.testing.expect(args.no_open);
    try std.testing.expect(args.version);
}

test "parse short aliases" {
    const argv = [_][:0]const u8{ "-v", "-h" };
    const args = try parse(&argv);
    try std.testing.expect(args.verbose);
    try std.testing.expect(args.help);
}

test "parse all options" {
    const argv = [_][:0]const u8{
        "-p",            "my prompt",
        "-f",            "input.txt",
        "--model",       "gemini-3-pro",
        "--aspect-ratio", "4:3",
        "--image-size",  "4K",
        "-o",            "/tmp/out",
        "--no-open",
        "-v",
    };
    const args = try parse(&argv);
    try std.testing.expectEqualStrings("my prompt", args.prompt.?);
    try std.testing.expectEqualStrings("input.txt", args.file.?);
    try std.testing.expectEqualStrings("gemini-3-pro", args.model.?);
    try std.testing.expectEqualStrings("4:3", args.aspect_ratio.?);
    try std.testing.expectEqualStrings("4K", args.image_size.?);
    try std.testing.expectEqualStrings("/tmp/out", args.output.?);
    try std.testing.expect(args.no_open);
    try std.testing.expect(args.verbose);
}

test "parse unknown flag" {
    const argv = [_][:0]const u8{"--unknown"};
    const result = parse(&argv);
    try std.testing.expectError(ParseError.UnknownFlag, result);
}

test "parse missing value" {
    const argv = [_][:0]const u8{"--prompt"};
    const result = parse(&argv);
    try std.testing.expectError(ParseError.MissingValue, result);
}

test "parse completions" {
    const argv = [_][:0]const u8{ "--completions", "fish" };
    const args = try parse(&argv);
    try std.testing.expectEqualStrings("fish", args.completions.?);
}

test "defaults" {
    const argv = [_][:0]const u8{};
    const args = try parse(&argv);
    try std.testing.expectEqual(@as(?[]const u8, null), args.model);
    try std.testing.expectEqual(@as(?[]const u8, null), args.aspect_ratio);
    try std.testing.expectEqual(@as(?[]const u8, null), args.image_size);
    try std.testing.expect(!args.no_open);
}
