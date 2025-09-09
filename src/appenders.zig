const std = @import("std");
const root = @import("root.zig");
const format = @import("format.zig");

const Context = root.Context;

/// Configuration options that apply to `Appender`s.
pub const Options = struct {
    /// The format to use when writting log lines.
    format: format.Format = .text,
};

/// A generic writer based appender.
/// Writes logs to the provided `Writer` type.
/// Uses a mutex internally to provide thread-safety when performing writes.
pub fn Writer(
    comptime level: std.log.Level,
    comptime opts: Options,
) type {
    return struct {
        const Self = @This();

        writer: *std.Io.Writer,
        mutex: std.Thread.Mutex = .{},

        pub fn init(writer: *std.Io.Writer) Self {
            return .{ .writer = writer };
        }

        pub fn log(
            self: *Self,
            context: *const Context,
        ) !void {
            self.mutex.lock();
            defer self.mutex.unlock();
            try opts.format.write(self.writer, context);
            try self.writer.flush();
        }

        pub fn enabled(comptime log_level: std.log.Level) bool {
            return @intFromEnum(log_level) <= @intFromEnum(level);
        }
    };
}

/// Console appender writes logs to stderr.
/// Uses the `std.debug` stderr mutex so Console appender
/// is compitable with std.Progress.
pub fn Console(
    comptime level: std.log.Level,
    comptime opts: Options,
) type {
    return struct {
        const Self = @This();
        var buffer: [4096]u8 = undefined;

        pub const init: Self = .{};

        pub fn log(
            _: *Self,
            context: *const Context,
        ) !void {
            var writer = std.fs.File.stderr().writer(&buffer);
            var stderr = &writer.interface;

            // we use this lock to be compitable with std.Progress
            // because of this we can't use `Writer` appender as it has its own mutex
            // and the std.Progress mutex isn't pub
            std.debug.lockStdErr();
            defer std.debug.unlockStdErr();
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
        const Inner = Writer(level, opts);

        // If buffer is a global we get a "General protection exception" error.
        // Not sure why this is the case, probably doesnt matter.
        buffer: [4096]u8 = undefined,
        file: std.fs.File,
        inner: Inner,

        /// Create a File appender that writes to the supplied file path.
        /// The file will be appended to if it already exists.
        pub fn init(filepath: []const u8) !Self {
            const flags: std.fs.File.CreateFlags = .{ .truncate = false };
            const file = try if (std.fs.path.isAbsolute(filepath))
                std.fs.createFileAbsolute(filepath, flags)
            else
                std.fs.cwd().createFile(filepath, flags);

            return .initFromFile(file);
        }

        /// Creates the file appender using the provided File.
        /// The file will be appended to if it already contains content.
        pub fn initFromFile(file: std.fs.File) !Self {
            try file.seekTo(try file.getEndPos());

            var self: Self = .{
                .file = file,
                .inner = undefined,
            };
            var writer = file.writer(&self.buffer);
            self.inner = Inner.init(&writer.interface);

            return self;
        }

        pub inline fn log(
            self: *Self,
            context: *const Context,
        ) !void {
            return self.inner.log(context);
        }

        pub fn enabled(comptime log_level: std.log.Level) bool {
            return Inner.enabled(log_level);
        }
    };
}
