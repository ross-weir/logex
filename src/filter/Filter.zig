const std = @import("std");

/// Filter provides a generic interface for log filtering.
/// It allows different implementations to provide their own filtering logic
/// while maintaining a consistent interface for the logging system.
///
/// This provides functionality similar to configuring scopes/log levels via `std.options.log_scope_levels`
/// but using runtime constructs (such as environment variables).
const Filter = @This();

/// Opaque pointer to the filter implementation's context
context: *const anyopaque,
/// Function pointer that implements the actual filtering logic
enabledFn: *const fn (
    context: *const anyopaque,
    level: std.log.Level,
    scope: []const u8,
) bool,

/// Checks if a log message with the given level and scope should be enabled
/// Returns true if the message should be logged, false otherwise
pub fn enabled(
    self: Filter,
    level: std.log.Level,
    scope: []const u8,
) bool {
    return self.enabledFn(self.context, level, scope);
}
