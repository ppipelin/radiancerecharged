const position = @import("position.zig");
const search = @import("search.zig");
const std = @import("std");
const tables = @import("tables.zig");
const types = @import("types.zig");

pub fn main() !void {
    tables.initAll(std.heap.c_allocator);
    defer tables.deinitAll(std.heap.c_allocator);

    const stdout = std.io.getStdOut().writer();

    try stdout.print("Radiance {s} by Paul-Elie Pipelin (ppipelin)\n", .{computeVersion(types.major, types.minor, types.patch)});
}

fn computeVersion(comptime major: u8, comptime minor: u8, comptime patch: u8) []const u8 {
    if (minor == 0 and patch == 0) {
        return std.fmt.comptimePrint("{d}", .{major});
    } else if (patch == 0) {
        return std.fmt.comptimePrint("{d}.{d}", .{ major, minor });
    } else {
        return std.fmt.comptimePrint("{d}.{d}.{d}", .{ major, minor, patch });
    }
}
