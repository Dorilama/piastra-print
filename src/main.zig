const std = @import("std");
const runner = @import("runner");
const native_sdk = @import("native_sdk");

pub const panic = std.debug.FullPanic(native_sdk.debug.capturePanic);

/// Reverse-DNS bundle id, reused for the writable overlay directory name.
const bundle_id = "dev.native_sdk.piastra-print";

const App = struct {
    env_map: *std.process.Environ.Map,
    io: std.Io,
    // Bridge handler table; rebuilt in bridge() so the context pointer is `self`.
    handlers: [5]native_sdk.BridgeHandler = undefined,
    // Writable overlay/staging paths under %LOCALAPPDATA%\<bundle_id>\. Absolute,
    // resolved once in main(); empty when LOCALAPPDATA is unset (update disabled).
    overlay_dir_buf: [300]u8 = undefined,
    overlay_dir: []const u8 = &.{},
    staging_dir_buf: [300]u8 = undefined,
    staging_dir: []const u8 = &.{},
    overlay_bak_buf: [300]u8 = undefined,
    overlay_bak: []const u8 = &.{},
    /// True when source() is serving the writable overlay rather than the
    /// bundled assets. A commit while this is false (first update on a fresh
    /// install, before any overlay exists) cannot be picked up by a reload and
    /// needs a restart — the frontend surfaces that.
    overlay_active: bool = false,
    /// Process-lifetime arena (no per-call free) for tiny update reads.
    arena: std.mem.Allocator = undefined,
    // Directory of the running exe, for an optional piastra-print.conf
    // update-URL file shipped next to the binary (env vars don't reach a
    // double-clicked GUI app).
    exe_dir_buf: [std.Io.Dir.max_path_bytes]u8 = undefined,
    exe_dir: []const u8 = &.{},

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
        // Dev server wins (managed by `native dev` / `zig build dev`).
        if (self.env_map.get("NATIVE_SDK_FRONTEND_URL")) |url| {
            if (url.len > 0) {
                self.overlay_active = false;
                return native_sdk.WebViewSource.url(url);
            }
        }
        // Production: prefer the update overlay once it has an entry.
        if (self.overlay_dir.len > 0) {
            var idx_buf: [320]u8 = undefined;
            const idx = std.fmt.bufPrint(&idx_buf, "{s}\\index.html", .{self.overlay_dir}) catch &.{};
            if (std.Io.Dir.cwd().statFile(self.io, idx, .{})) |_| {
                self.overlay_active = true;
                return native_sdk.WebViewSource.assets(.{
                    .root_path = self.overlay_dir,
                    .entry = "index.html",
                    .origin = "zero://app",
                    .spa_fallback = true,
                });
            } else |_| {}
        }
        self.overlay_active = false;
        return native_sdk.frontend.productionSource(.{ .dist = "frontend/dist" });
    }

    // App-defined bridge dispatcher: exposes `app.writeSvg` plus the
    // `app.update*` self-update commands to the web frontend.
    fn bridge(self: *@This()) native_sdk.BridgeDispatcher {
        self.handlers[0] = .{ .name = "app.writeSvg", .context = self, .invoke_fn = writeSvg };
        self.handlers[1] = .{ .name = "app.getUpdateInfo", .context = self, .invoke_fn = getUpdateInfo };
        self.handlers[2] = .{ .name = "app.updateBegin", .context = self, .invoke_fn = updateBegin };
        self.handlers[3] = .{ .name = "app.updateWrite", .context = self, .invoke_fn = updateWrite };
        self.handlers[4] = .{ .name = "app.updateCommit", .context = self, .invoke_fn = updateCommit };
        return .{
            .policy = .{ .enabled = true, .commands = &app_bridge_commands },
            .registry = .{ .handlers = &self.handlers },
        };
    }
};

const dev_origins = [_][]const u8{ "zero://app", "zero://inline", "http://127.0.0.1:5173" };
const bridge_origins = [_][]const u8{ "zero://app", "zero://inline" };

const app_bridge_commands = [_]native_sdk.BridgeCommandPolicy{
    .{ .name = "app.writeSvg", .origins = &bridge_origins },
    .{ .name = "app.getUpdateInfo", .origins = &bridge_origins },
    .{ .name = "app.updateBegin", .origins = &bridge_origins },
    .{ .name = "app.updateWrite", .origins = &bridge_origins },
    .{ .name = "app.updateCommit", .origins = &bridge_origins },
};

const builtin_bridge_commands = [_]native_sdk.BridgeCommandPolicy{
    .{ .name = "native-sdk.dialog.saveFile", .origins = &bridge_origins },
};

pub fn main(init: std.process.Init) !void {
    var app = App{ .env_map = init.environ_map, .io = init.io };
    // Resolve the writable overlay/staging paths under %LOCALAPPDATA%. Empty
    // (update disabled) when LOCALAPPDATA is absent.
    if (init.environ_map.get("LOCALAPPDATA")) |la| {
        app.overlay_dir = std.fmt.bufPrint(&app.overlay_dir_buf, "{s}\\{s}\\web", .{ la, bundle_id }) catch &.{};
        app.staging_dir = std.fmt.bufPrint(&app.staging_dir_buf, "{s}\\{s}\\web.staging", .{ la, bundle_id }) catch &.{};
        app.overlay_bak = std.fmt.bufPrint(&app.overlay_bak_buf, "{s}\\{s}\\web.bak", .{ la, bundle_id }) catch &.{};
    }
    // Allocator for tiny, process-lifetime update reads; the exe dir backs the
    // optional piastra-print.conf update-URL file for packaged builds.
    app.arena = init.arena.allocator();
    const exe_len = std.process.executablePath(init.io, &app.exe_dir_buf) catch 0;
    if (exe_len > 0) {
        if (std.fs.path.dirname(app.exe_dir_buf[0..exe_len])) |d| app.exe_dir = d;
    }
    try runner.runWithOptions(app.app(), .{
        .app_name = "Piastra Print",
        .window_title = "Piastra Print",
        .bundle_id = bundle_id,
        .icon_path = "assets/icon.png",
        .bridge = app.bridge(),
        .builtin_bridge = .{ .enabled = true, .commands = &builtin_bridge_commands },
        .security = .{
            .navigation = .{ .allowed_origins = &dev_origins },
        },
    }, init);
}

// ---------------------------------------------------------------------------
// SVG save (native file write for the path chosen by the save dialog).
// ---------------------------------------------------------------------------

// Writes the SVG `content` to the absolute `path` chosen by the save dialog.
fn writeSvg(context: *anyopaque, invocation: native_sdk.bridge.Invocation, output: []u8) anyerror![]const u8 {
    const self: *App = @ptrCast(@alignCast(context));
    const payload = invocation.request.payload;

    const path = decodeJsonStringField(payload, "path", output) orelse return error.MissingPath;
    const content = decodeJsonStringField(payload, "content", output[path.len..]) orelse return error.MissingContent;

    try std.Io.Dir.cwd().writeFile(self.io, .{ .sub_path = path, .data = content });
    return "{\"ok\":true}";
}

// Resolve the update-server base URL: PIASTRA_UPDATE_URL env var first, else
// the first non-empty line of <exe_dir>/piastra-print.conf, else "" (disabled).
fn resolveUpdateUrl(self: *App) []const u8 {
    if (self.env_map.get("PIASTRA_UPDATE_URL")) |u| {
        if (u.len > 0) return u;
    }
    if (self.exe_dir.len == 0) return "";
    var path_buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const conf_path = std.fmt.bufPrint(&path_buf, "{s}/piastra-print.conf", .{self.exe_dir}) catch return "";
    // Arena-backed read (process-lifetime, no free); the returned slice is stable.
    const content = std.Io.Dir.cwd().readFileAlloc(self.io, conf_path, self.arena, .limited(400)) catch return "";
    var line = content;
    if (std.mem.indexOfScalar(u8, line, '\n')) |i| line = line[0..i];
    if (std.mem.indexOfScalar(u8, line, '\r')) |i| line = line[0..i];
    return std.mem.trim(u8, line, " \t");
}

// ---------------------------------------------------------------------------
// Self-update: the frontend fetches a manifest + assets from a Cloudflare
// Pages URL (CORS-open), then streams each whole file through the bridge (the
// dispatcher accepts up to 1 MiB per call, so the bundled JS/CSS fit in one
// call each). Native only owns the writable overlay + an atomic swap.
// ---------------------------------------------------------------------------

// `{ baseUrl, serving }`. baseUrl is the PIASTRA_UPDATE_URL env var, else the
// first line of a piastra-print.conf shipped next to the executable (env vars
// don't reach a GUI app launched by double-click). Empty = no update server.
fn getUpdateInfo(context: *anyopaque, invocation: native_sdk.bridge.Invocation, output: []u8) anyerror![]const u8 {
    _ = invocation;
    const self: *App = @ptrCast(@alignCast(context));
    const base = resolveUpdateUrl(self);
    const serving: []const u8 = if (self.overlay_active) "overlay" else "bundled";

    var esc: [1024]u8 = undefined;
    var n: usize = 0;
    for (base) |c| {
        if (n + 2 > esc.len) return error.UpdateInfoTooLong;
        switch (c) {
            '"', '\\' => {
                esc[n] = '\\';
                n += 1;
                esc[n] = c;
                n += 1;
            },
            '\n' => {
                esc[n] = '\\';
                n += 1;
                esc[n] = 'n';
                n += 1;
            },
            '\r' => {
                esc[n] = '\\';
                n += 1;
                esc[n] = 'r';
                n += 1;
            },
            '\t' => {
                esc[n] = '\\';
                n += 1;
                esc[n] = 't';
                n += 1;
            },
            else => {
                esc[n] = c;
                n += 1;
            },
        }
    }
    return std.fmt.bufPrint(output, "{{\"baseUrl\":\"{s}\",\"serving\":\"{s}\"}}", .{ esc[0..n], serving });
}

// Reset the staging directory for a fresh set of update files.
fn updateBegin(context: *anyopaque, invocation: native_sdk.bridge.Invocation, output: []u8) anyerror![]const u8 {
    _ = invocation;
    _ = output;
    const self: *App = @ptrCast(@alignCast(context));
    if (self.staging_dir.len == 0) return error.UpdateNotConfigured;
    std.Io.Dir.cwd().deleteTree(self.io, self.staging_dir) catch {};
    try std.Io.Dir.cwd().createDirPath(self.io, self.staging_dir);
    return "{\"ok\":true}";
}

// Write one update file (raw text payload) into staging. `path` is relative to
// the dist root and validated against traversal.
fn updateWrite(context: *anyopaque, invocation: native_sdk.bridge.Invocation, output: []u8) anyerror![]const u8 {
    const self: *App = @ptrCast(@alignCast(context));
    const payload = invocation.request.payload;

    const rel_path = decodeJsonStringField(payload, "path", output) orelse return error.MissingPath;
    const data = decodeJsonStringField(payload, "data", output[rel_path.len..]) orelse return error.MissingData;
    if (self.staging_dir.len == 0) return error.UpdateNotConfigured;
    if (!isSafeRelativePath(rel_path)) return error.UnsafePath;

    var full_buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const full = std.fmt.bufPrint(&full_buf, "{s}/{s}", .{ self.staging_dir, rel_path }) catch return error.PathTooLong;
    if (std.fs.path.dirname(full)) |parent| {
        std.Io.Dir.cwd().createDirPath(self.io, parent) catch {};
    }
    try std.Io.Dir.cwd().writeFile(self.io, .{ .sub_path = full, .data = data });
    return "{\"ok\":true}";
}

// Atomically promote staging to the overlay, returning whether a reload can
// pick it up (`overlay`) or a restart is required (`bundled`).
fn updateCommit(context: *anyopaque, invocation: native_sdk.bridge.Invocation, output: []u8) anyerror![]const u8 {
    _ = invocation;
    const self: *App = @ptrCast(@alignCast(context));
    if (self.overlay_dir.len == 0) return error.UpdateNotConfigured;

    try promoteStaging(self.io, self.overlay_dir, self.staging_dir, self.overlay_bak);

    const serving: []const u8 = if (self.overlay_active) "overlay" else "bundled";
    return std.fmt.bufPrint(output, "{{\"serving\":\"{s}\"}}", .{serving});
}

// Move staging to `overlay` via a `bak` side-step so the live overlay is never
// half-written: aside the current overlay, promote staging, then drop the
// aside copy. A missing overlay (first update) is fine — its rename is ignored.
fn promoteStaging(io: std.Io, overlay: []const u8, staging: []const u8, bak: []const u8) !void {
    const cwd = std.Io.Dir.cwd();
    cwd.deleteTree(io, bak) catch {};
    cwd.rename(overlay, cwd, bak, io) catch {};
    cwd.rename(staging, cwd, overlay, io) catch |err| {
        // Staging failed to land: restore the overlay we moved aside, if any.
        cwd.rename(bak, cwd, overlay, io) catch {};
        return err;
    };
    cwd.deleteTree(io, bak) catch {};
}

// A path is safe to write under staging iff it is relative, has no `.`/`..`
// components, and carries no drive letter or colon.
fn isSafeRelativePath(p: []const u8) bool {
    if (p.len == 0) return false;
    if (p[0] == '/' or p[0] == '\\') return false;
    var start: usize = 0;
    var i: usize = 0;
    while (i <= p.len) : (i += 1) {
        if (i == p.len or p[i] == '/' or p[i] == '\\') {
            const comp = p[start..i];
            if (comp.len > 0) {
                if (std.mem.eql(u8, comp, "..")) return false;
                if (std.mem.eql(u8, comp, ".")) return false;
                for (comp) |c| if (c == ':') return false;
            }
            start = i + 1;
        }
    }
    return true;
}

// ---------------------------------------------------------------------------
// Minimal JSON string-field decoder (mirrors the SDK's own hand-rolled helper,
// which is not re-exported to app code). Handles \" \\ \/ \b \f \n \r \t and
// \uXXXX (BMP). Returns null when the field is absent or malformed.
// ---------------------------------------------------------------------------

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
                    const enc = utf8EncodeBmp(cp, out, &o) orelse return null;
                    _ = enc;
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "app name is configured" {
    try std.testing.expectEqualStrings("piastra-print", "piastra-print");
}

test "isSafeRelativePath accepts normal asset paths" {
    try std.testing.expect(isSafeRelativePath("index.html"));
    try std.testing.expect(isSafeRelativePath("assets/index-Ab3.js"));
    try std.testing.expect(isSafeRelativePath("assets\\index-Cd4.css"));
    try std.testing.expect(isSafeRelativePath("assets/sub/deep.png"));
}

test "isSafeRelativePath rejects traversal and absolute paths" {
    try std.testing.expect(!isSafeRelativePath(""));
    try std.testing.expect(!isSafeRelativePath("/etc/passwd"));
    try std.testing.expect(!isSafeRelativePath("\\windows\\sys"));
    try std.testing.expect(!isSafeRelativePath("../escape"));
    try std.testing.expect(!isSafeRelativePath("a/../../b"));
    try std.testing.expect(!isSafeRelativePath("a/./b"));
    try std.testing.expect(!isSafeRelativePath("C:\\Users\\x"));
    try std.testing.expect(!isSafeRelativePath("assets/a:b"));
}

test "promoteStaging swaps overlay and cleans the aside copy" {
    const io = std.testing.io;
    const cwd = std.Io.Dir.cwd();
    const root = "piastra-update-test";

    defer cwd.deleteTree(io, root) catch {};

    const staging = "piastra-update-test/staging";
    const overlay = "piastra-update-test/overlay";
    const bak = "piastra-update-test/bak";
    const idx = "piastra-update-test/overlay/index.html";

    // Existing overlay (the "current" assets).
    try cwd.createDirPath(io, overlay);
    try cwd.writeFile(io, .{ .sub_path = "piastra-update-test/overlay/index.html", .data = "OLD" });

    // Staging holds the new assets.
    try cwd.createDirPath(io, staging);
    try cwd.writeFile(io, .{ .sub_path = "piastra-update-test/staging/index.html", .data = "NEW" });

    try promoteStaging(io, overlay, staging, bak);

    const got = try cwd.readFileAlloc(io, idx, std.testing.allocator, .limited(1024));
    defer std.testing.allocator.free(got);
    try std.testing.expectEqualStrings("NEW", got);

    // Staging was consumed and the aside copy is gone.
    try std.testing.expectError(error.FileNotFound, cwd.statFile(io, staging, .{}));
    try std.testing.expectError(error.FileNotFound, cwd.statFile(io, bak, .{}));
}

test "promoteStaging promotes when no overlay exists yet" {
    const io = std.testing.io;
    const cwd = std.Io.Dir.cwd();
    const root = "piastra-update-test-fresh";
    defer cwd.deleteTree(io, root) catch {};

    try cwd.createDirPath(io, "piastra-update-test-fresh/staging");
    try cwd.writeFile(io, .{ .sub_path = "piastra-update-test-fresh/staging/index.html", .data = "FIRST" });

    try promoteStaging(
        io,
        "piastra-update-test-fresh/overlay",
        "piastra-update-test-fresh/staging",
        "piastra-update-test-fresh/bak",
    );

    const got = try cwd.readFileAlloc(io, "piastra-update-test-fresh/overlay/index.html", std.testing.allocator, .limited(1024));
    defer std.testing.allocator.free(got);
    try std.testing.expectEqualStrings("FIRST", got);
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
