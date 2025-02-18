const position = @import("position.zig");
const std = @import("std");
const types = @import("types.zig");

pub fn main() !void {
    var state: position.State = position.State{};
    var pos = position.Position.setFen(&state, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");
    pos.debugPrint();

    var s: position.State = position.State{};
    const move: types.Move = types.Move{ .from = 12, .to = 28 };
    pos.movePiece(move, &s) catch unreachable;
    pos.debugPrint();
    types.debugPrintBitboard(pos.bb_pieces[types.PieceType.pawn.index()]);

    pos.unMovePiece(move, false) catch unreachable;
    pos.debugPrint();

    types.debugPrintBitboard(pos.bb_pieces[types.PieceType.pawn.index()]);

    // pos = position.Position.setFen(&state, "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -");
    // pos.debugPrint();

    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush(); // don't forget to flush!
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
