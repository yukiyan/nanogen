const std = @import("std");

pub const Header = struct {
    name: []const u8,
    value: []const u8,
};

pub const Response = struct {
    status: std.http.Status,
    body: []const u8,
};

pub const HttpClient = struct {
    inner: std.http.Client,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) HttpClient {
        return .{
            .inner = .{ .allocator = allocator },
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *HttpClient) void {
        self.inner.deinit();
    }

    /// POST request. Caller owns returned body via allocator.
    pub fn post(self: *HttpClient, url_str: []const u8, headers: []const Header, body: []const u8) !Response {
        const uri = try std.Uri.parse(url_str);

        var req_headers = std.http.Client.Request.Headers{};
        var extra_buf: [16]std.http.Header = undefined;
        var extra_count: usize = 0;

        for (headers) |h| {
            if (std.mem.eql(u8, h.name, "Content-Type")) {
                req_headers.content_type = .{ .override = h.value };
            } else {
                extra_buf[extra_count] = .{ .name = h.name, .value = h.value };
                extra_count += 1;
            }
        }

        var req = try self.inner.request(.POST, uri, .{
            .headers = req_headers,
            .extra_headers = extra_buf[0..extra_count],
        });
        defer req.deinit();

        req.transfer_encoding = .{ .content_length = body.len };
        var send_buf: [4096]u8 = undefined;
        var body_writer = try req.sendBodyUnflushed(&send_buf);
        try body_writer.writer.writeAll(body);
        try body_writer.end();
        try req.connection.?.flush();

        var recv_buf: [8192]u8 = undefined;
        var response = try req.receiveHead(&recv_buf);

        const decompress_buffer: []u8 = switch (response.head.content_encoding) {
            .identity => &.{},
            .zstd => try self.allocator.alloc(u8, std.compress.zstd.default_window_len),
            .deflate, .gzip => try self.allocator.alloc(u8, std.compress.flate.max_window_len),
            .compress => return error.UnsupportedCompressionMethod,
        };
        defer self.allocator.free(decompress_buffer);

        var transfer_buf: [4096]u8 = undefined;
        var decompress: std.http.Decompress = undefined;
        var reader = response.readerDecompressing(&transfer_buf, &decompress, decompress_buffer);
        const max_size: std.Io.Limit = .limited(32 * 1024 * 1024);
        const resp_body = try reader.allocRemaining(self.allocator, max_size);

        return Response{
            .status = response.head.status,
            .body = resp_body,
        };
    }
};

test "HttpClient init/deinit" {
    var client = HttpClient.init(std.testing.allocator);
    client.deinit();
}

test "Response struct" {
    const resp = Response{
        .status = .ok,
        .body = "test",
    };
    try std.testing.expectEqual(std.http.Status.ok, resp.status);
    try std.testing.expectEqualStrings("test", resp.body);
}
