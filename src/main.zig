const position = @import("position.zig");
const std = @import("std");
const search = @import("search.zig");
const tables = @import("tables.zig");
const types = @import("types.zig");

pub fn main() !void {
    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout = std.io.getStdOut().writer();

    var state: position.State = position.State{};
    var pos = position.Position.setFen(&state, position.start_fen);
    pos.debugPrint();

    // Estimated max should be (2^12*64*2) * 64 / 8 u8 = 4_194_304
    var buffer: [10_000_000]u8 = undefined;
    var alloc = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = alloc.allocator();
    tables.initAll(allocator);
    defer tables.deinitAll();

    var list = std.ArrayList(types.Move).init(std.heap.page_allocator);
    defer list.deinit();

    pos.generateLegalMoves(pos.state.turn, &list);

    std.debug.print("nb of moves: {d}\n", .{list.items.len});
    for (list.items) |item| {
        item.uciPrint(stdout);
        try stdout.print("\n", .{});
    }

    try stdout.print("Run `zig build test` to run the tests.\n", .{});
}
