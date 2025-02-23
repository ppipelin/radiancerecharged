const position = @import("position.zig");
const std = @import("std");
const tables = @import("tables.zig");
const types = @import("types.zig");

pub fn main() !void {
    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var state: position.State = position.State{};
    var pos = position.Position.setFen(&state, position.start_fen);
    pos.debugPrint();

    pos = position.Position.setFen(&state, "2k5/8/5Q2/8/8/4B2R/8/3K4 w - - 0 1");

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

    // for (0..64) |i| {
    //     types.debugPrintBitboard(tables.moves_bishop_mask[i]);
    //     types.debugPrintBitboard(tables.moves_rook_mask[i]);
    // }

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush(); // don't forget to flush!
}
