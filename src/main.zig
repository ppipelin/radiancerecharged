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

    var list = std.ArrayList(types.Move).init(std.heap.page_allocator);

    tables.initAll();
    pos.generateLegalMoves(pos.state.turn, &list);

    std.debug.print("nb of moves: {d}\n", .{list.items.len});
    for (list.items) |item| {
        item.uciPrint(stdout);
        try stdout.print("\n", .{});
    }

    // for (0..64) |i| {
    //     types.debugPrintBitboard(tables.movesBishopMask[i]);
    //     types.debugPrintBitboard(tables.movesRookMask[i]);
    // }

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush(); // don't forget to flush!
}
