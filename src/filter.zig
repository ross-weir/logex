pub const Filter = @import("./filter/Filter.zig");
pub const EnvFilter = @import("./filter/env.zig").EnvFilter;

test "filter" {
    _ = @import("./filter/env.zig");
}
