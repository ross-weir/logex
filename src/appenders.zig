const std = @import("std");
const Options = @import("root.zig").Options;
const Record = @import("Record.zig");

/// A generic writer based appender.
/// Writes logs to the provided `Writer` type.
/// Uses a mutex internally to provide thread-safety when performing writes.
pub fn Writer(
    comptime level: std.log.Level,
    comptime opts: Options,
    comptime WriterType: type,
) type {
    return struct {
        const Self = @This();

        writer: WriterType,
        mutex: std.Thread.Mutex = .{},

        pub fn init(writer: WriterType) Self {
            return .{ .writer = writer };
        }

        pub fn log(
            self: *Self,
            comptime record: *const Record,
            message: []const u8,
        ) !void {
            if (comptime @intFromEnum(record.level) > @intFromEnum(level)) return;

            self.mutex.lock();
            defer self.mutex.unlock();
            try opts.format.write(self.writer, record, message, opts);
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

        pub const init: Self = .{};

        pub fn log(
            _: *Self,
            comptime record: *const Record,
            message: []const u8,
        ) !void {
            if (comptime @intFromEnum(record.level) > @intFromEnum(level)) return;

            const stderr = std.io.getStdErr().writer();
            var bw = std.io.bufferedWriter(stderr);
            const writer = bw.writer();

            // we use this lock to be compitable with std.Progress
            // because of this we can't use `Writer` appender as it has its own mutex
            // and the std.Progress mutex isn't pub
            std.debug.lockStdErr();
            defer std.debug.unlockStdErr();
            nosuspend {
                try opts.format.write(writer, record, message, opts);
                try bw.flush();
            }
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

        inner: Writer(level, opts, std.fs.File.Writer),

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
            return .{ .inner = .init(file.writer()) };
        }

        pub inline fn log(
            self: *Self,
            comptime record: *const Record,
            message: []const u8,
        ) !void {
            return self.inner.log(record, message);
        }
    };
}
