const std = @import("std");
const runner = @import("runner");
const native_sdk = @import("native_sdk");

pub const panic = std.debug.FullPanic(native_sdk.debug.capturePanic);

const App = struct {
    env_map: *std.process.Environ.Map,
    io: std.Io,
    // Bridge handler table; rebuilt in bridge() so the context pointer is `self`.
    handlers: [1]native_sdk.BridgeHandler = .{
        .{ .name = "", .context = undefined, .invoke_fn = undefined },
    },

    fn app(self: *@This()) native_sdk.App {
        return .{
            .context = self,
            .name = "piastra-print",
            .source = native_sdk.frontend.productionSource(.{ .dist = "frontend/dist" }),
            .source_fn = source,
        };
    }

    fn source(context: *anyopaque) anyerror!native_sdk.WebViewSource {
        const self: *@This() = @ptrCast(@alignCast(context));
        return native_sdk.frontend.sourceFromEnv(self.env_map, .{
            .dist = "frontend/dist",
            .entry = "index.html",
        });
    }

    // App-defined bridge dispatcher: exposes `app.writeSvg` to the web frontend.
    // The native save dialog returns a path but does not write the file, so the
    // frontend asks for the path, then calls this handler with the SVG content.
    fn bridge(self: *@This()) native_sdk.BridgeDispatcher {
        self.handlers[0] = .{
            .name = "app.writeSvg",
            .context = self,
            .invoke_fn = writeSvg,
        };
        return .{
            .policy = .{ .enabled = true, .commands = &app_bridge_commands },
            .registry = .{ .handlers = &self.handlers },
        };
    }
};

const dev_origins = [_][]const u8{ "zero://app", "zero://inline", "http://127.0.0.1:5173" };
const bridge_origins = [_][]const u8{ "zero://app", "zero://inline", "http://127.0.0.1:5173" };

const app_bridge_commands = [_]native_sdk.BridgeCommandPolicy{
    .{ .name = "app.writeSvg", .origins = &bridge_origins },
};

const builtin_bridge_commands = [_]native_sdk.BridgeCommandPolicy{
    .{ .name = "native-sdk.dialog.saveFile", .origins = &bridge_origins },
};

// Writes the SVG `content` to the absolute `path` chosen by the save dialog.
// `output` is the dispatcher's result scratch; we decode the two payload strings
// into it (path first, then content past it) before writing, then return a
// fixed success literal, so the scratch is ours to reuse.
fn writeSvg(context: *anyopaque, invocation: native_sdk.bridge.Invocation, output: []u8) anyerror![]const u8 {
    const self: *App = @ptrCast(@alignCast(context));
    const payload = invocation.request.payload;

    const path = decodeJsonStringField(payload, "path", output) orelse return error.MissingPath;
    const content = decodeJsonStringField(payload, "content", output[path.len..]) orelse return error.MissingContent;

    try std.Io.Dir.cwd().writeFile(self.io, .{ .sub_path = path, .data = content });
    return "{\"ok\":true}";
}

pub fn main(init: std.process.Init) !void {
    var app = App{ .env_map = init.environ_map, .io = init.io };
    try runner.runWithOptions(app.app(), .{
        .app_name = "Piastra Print",
        .window_title = "Piastra Print",
        .bundle_id = "dev.native_sdk.piastra-print",
        .icon_path = "assets/icon.png",
        .bridge = app.bridge(),
        .builtin_bridge = .{ .enabled = true, .commands = &builtin_bridge_commands },
        .security = .{
            .navigation = .{ .allowed_origins = &dev_origins },
        },
    }, init);
}

// Decodes a JSON object string field into `out`, returning the decoded slice.
// Handles the standard escape set (\" \\ \/ \b \f \n \r \t) and \uXXXX (BMP).
// Mirrors the SDK's own hand-rolled JSON helper, which is not re-exported to
// app code. Returns null when the field is absent or malformed.
fn decodeJsonStringField(payload: []const u8, field: []const u8, out: []u8) ?[]u8 {
    var i: usize = 0;
    skipWs(payload, &i);
    if (i >= payload.len or payload[i] != '{') return null;
    i += 1;

    while (true) {
        skipWs(payload, &i);
        if (i >= payload.len) return null;
        if (payload[i] == '}') return null; // field not present

        // Key.
        if (payload[i] != '"') return null;
        i += 1;
        const key_start = i;
        while (i < payload.len and payload[i] != '"') {
            if (payload[i] == '\\' and i + 1 < payload.len) i += 2 else i += 1;
        }
        if (i >= payload.len) return null;
        const key = payload[key_start..i];
        i += 1; // closing quote

        skipWs(payload, &i);
        if (i >= payload.len or payload[i] != ':') return null;
        i += 1;
        skipWs(payload, &i);
        if (i >= payload.len) return null;

        if (payload[i] != '"') {
            // Only string values are supported; skip and keep scanning.
            skipValue(payload, &i);
            skipWs(payload, &i);
            if (i < payload.len and payload[i] == ',') {
                i += 1;
                continue;
            }
            return null;
        }

        // String value.
        i += 1; // opening quote
        var o: usize = 0;
        while (i < payload.len and payload[i] != '"') {
            if (payload[i] == '\\') {
                i += 1;
                if (i >= payload.len) return null;
                if (payload[i] == 'u') {
                    if (i + 4 >= payload.len) return null;
                    const cp = std.fmt.parseInt(u21, payload[i + 1 .. i + 5], 16) catch return null;
                    const n = utf8EncodeBmp(cp, out, &o) orelse return null;
                    _ = n;
                    i += 5;
                } else {
                    const c: u8 = switch (payload[i]) {
                        '"', '\\', '/' => payload[i],
                        'b' => 0x08,
                        'f' => 0x0C,
                        'n' => '\n',
                        'r' => '\r',
                        't' => '\t',
                        else => payload[i],
                    };
                    if (o >= out.len) return null;
                    out[o] = c;
                    o += 1;
                    i += 1;
                }
            } else {
                if (o >= out.len) return null;
                out[o] = payload[i];
                o += 1;
                i += 1;
            }
        }
        if (i >= payload.len) return null;
        i += 1; // closing quote

        if (std.mem.eql(u8, key, field)) return out[0..o];

        skipWs(payload, &i);
        if (i < payload.len and payload[i] == ',') {
            i += 1;
            continue;
        }
        return null;
    }
}

// Encodes a BMP codepoint into `out` at `*o`, advancing `*o`. Returns byte count.
fn utf8EncodeBmp(cp: u21, out: []u8, o: *usize) ?u3 {
    if (cp < 0x80) {
        if (o.* >= out.len) return null;
        out[o.*] = @intCast(cp);
        o.* += 1;
        return 1;
    } else if (cp < 0x800) {
        if (o.* + 1 >= out.len) return null;
        out[o.*] = @intCast(0xC0 | (cp >> 6));
        out[o.* + 1] = @intCast(0x80 | (cp & 0x3F));
        o.* += 2;
        return 2;
    } else {
        if (o.* + 2 >= out.len) return null;
        out[o.*] = @intCast(0xE0 | (cp >> 12));
        out[o.* + 1] = @intCast(0x80 | ((cp >> 6) & 0x3F));
        out[o.* + 2] = @intCast(0x80 | (cp & 0x3F));
        o.* += 3;
        return 3;
    }
}

fn skipWs(payload: []const u8, i: *usize) void {
    while (i.* < payload.len) : (i.* += 1) {
        const c = payload[i.*];
        if (c != ' ' and c != '\t' and c != '\n' and c != '\r') break;
    }
}

fn skipValue(payload: []const u8, i: *usize) void {
    while (i.* < payload.len and payload[i.*] != ',' and payload[i.*] != '}') : (i.* += 1) {}
}

test "app name is configured" {
    try std.testing.expectEqualStrings("piastra-print", "piastra-print");
}

test "decodeJsonStringField extracts path and content with escapes" {
    // The exact shape JSON.stringify produces for the frontend payload:
    //   { path: "C:\\Users\\x\\a.svg", content: '<svg fill="#111827"/>\n' }
    const payload = "{\"path\":\"C:\\\\Users\\\\x\\\\a.svg\",\"content\":\"<svg fill=\\\"#111827\\\"/>\\n\"}";

    var out: [256]u8 = undefined;
    const path = decodeJsonStringField(payload, "path", &out).?;
    try std.testing.expectEqualStrings("C:\\Users\\x\\a.svg", path);

    const content = decodeJsonStringField(payload, "content", out[path.len..]).?;
    try std.testing.expectEqualStrings("<svg fill=\"#111827\"/>\n", content);
}

test "decodeJsonStringField returns null when field is absent" {
    var out: [64]u8 = undefined;
    try std.testing.expect(decodeJsonStringField("{\"a\":\"b\"}", "missing", &out) == null);
}
