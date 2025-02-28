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

    // pos.state.turn = pos.state.turn.invert();
    // std.debug.print("Perft 1: {}\n\n", .{try search.perft(std.heap.page_allocator, &pos, 1, false)});

    var t = try std.time.Timer.start();

    // std.debug.print("Perft 1: {}\n\n", .{try search.perft(std.heap.c_allocator, &pos, 1, true)});
    // std.debug.print("Perft 2: {}\n\n", .{try search.perft(std.heap.c_allocator, &pos, 2, true)});
    // std.debug.print("Perft 3: {}\n\n", .{try search.perft(std.heap.c_allocator, &pos, 3, true)});
    // std.debug.print("Perft 4: {}\n\n", .{try search.perft(std.heap.c_allocator, &pos, 4, true)});
    // std.debug.print("Perft 5: {}\n\n", .{try search.perft(std.heap.c_allocator, &pos, 5, false)});
    // std.debug.print("Perft 6: {}\n\n", .{try search.perft(std.heap.c_allocator, &pos, 6, false)});

    var list = std.ArrayList(types.Move).init(std.heap.page_allocator);
    defer list.deinit();
    pos.generateLegalMoves(pos.state.turn, &list);
    types.Move.displayMoves(list);

    std.debug.print("Time: {}\n", .{std.fmt.fmtDuration(t.read())});

    try stdout.print("Run `zig build test` to run the tests.\n", .{});
}
