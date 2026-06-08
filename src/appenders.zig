const std = @import("std");
const root = @import("root.zig");
const format = @import("format.zig");

const Context = root.Context;

/// Configuration options that apply to `Appender`s.
pub const Options = struct {
    /// The format to use when writting log lines.
    format: format.Format = .text,
    buffer_size: usize = 4096,
};

/// Console appender writes logs to stderr.
/// Uses the `std.debug` stderr mutex so Console appender
/// is compitable with std.Progress.
pub fn Console(
    comptime level: std.log.Level,
    comptime opts: Options,
) type {
    return struct {
        const Self = @This();
        var buffer: [opts.buffer_size]u8 = undefined;

        pub const init: Self = .{};

        pub fn log(
            _: *Self,
            io: std.Io,
            context: *const Context,
        ) !void {
            const prev_cancel = io.swapCancelProtection(.blocked);
            defer _ = io.swapCancelProtection(prev_cancel);

            const locked = std.debug.lockStderr(&buffer);
            defer std.debug.unlockStderr();
            const stderr = locked.terminal().writer;
            nosuspend {
                try opts.format.write(stderr, context);
                try stderr.flush();
            }
        }

        pub fn enabled(comptime log_level: std.log.Level) bool {
            return @intFromEnum(log_level) <= @intFromEnum(level);
        }
    };
}

/// File appender writes logs to file.
/// Uses a mutex internally for thread-safety.
pub fn File(
    comptime level: std.log.Level,
    comptime opts: Options,
) type {
    return struct {
        const Self = @This();

        file: std.Io.File,
        mutex: std.Io.Mutex = .init,
        buffer: [opts.buffer_size]u8 = undefined,
        pos: u64,

        /// Create a File appender that writes to the supplied file path.
        /// The file will be appended to if it already exists.
        pub fn init(io: std.Io, filepath: []const u8) !Self {
            // We require read flags so we can get the file length and adjust the write cursor
            // position to the end of the file (we append by default).
            const flags: std.Io.File.CreateFlags = .{ .truncate = false, .read = true };
            const file = try if (std.fs.path.isAbsolute(filepath))
                std.Io.Dir.createFileAbsolute(io, filepath, flags)
            else
                std.Io.Dir.cwd().createFile(io, filepath, flags);

            return .initFromFile(io, file);
        }

        /// Creates the file appender using the provided File.
        /// The file will be appended to if it already contains content.
        pub fn initFromFile(io: std.Io, file: std.Io.File) !Self {
            return .{ .file = file, .pos = try file.length(io) };
        }

        pub fn log(
            self: *Self,
            io: std.Io,
            context: *const Context,
        ) !void {
            const prev_cancel = io.swapCancelProtection(.blocked);
            defer _ = io.swapCancelProtection(prev_cancel);

            self.mutex.lockUncancelable(io);
            defer self.mutex.unlock(io);

            var writer = self.file.writer(io, &self.buffer);
            writer.pos = self.pos;
            defer self.pos = writer.pos;

            const interface = &writer.interface;
            try opts.format.write(interface, context);
            try interface.flush();
        }

        pub fn enabled(comptime log_level: std.log.Level) bool {
            return @intFromEnum(log_level) <= @intFromEnum(level);
        }
    };
}
