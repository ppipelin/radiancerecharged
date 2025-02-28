//! This module provides tests for move generation of the program

const position = @import("position.zig");
const search = @import("search.zig");
const std = @import("std");
const tables = @import("tables.zig");
const types = @import("types.zig");

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;

const allocator = std.testing.allocator;

test "PerftKiwipete" {
    var s: position.State = position.State{};
    var pos = position.Position.setFen(&s, position.kiwipete);

    tables.initAll(allocator);
    defer tables.deinitAll();

    var list = std.ArrayList(types.Move).init(allocator);
    defer list.deinit();

    try expectEqual(48, search.perft(std.testing.allocator, &pos, 1, false) catch unreachable);
    try expectEqual(2039, search.perft(std.testing.allocator, &pos, 2, false) catch unreachable);
    try expectEqual(97862, search.perft(std.testing.allocator, &pos, 3, false) catch unreachable);
    try expectEqual(4085603, search.perft(std.testing.allocator, &pos, 4, false) catch unreachable);
    try expectEqual(193690690, search.perft(std.testing.allocator, &pos, 5, false));
}

test "MovegenEnPassant" {
    var s: position.State = position.State{};
    var pos = position.Position.setFen(&s, "4k3/8/8/3pPp2/8/8/8/4K3 w - d6 0 3");
    tables.initAll(allocator);
    defer tables.deinitAll();

    var list = std.ArrayList(types.Move).init(allocator);
    defer list.deinit();

    pos.generateLegalMoves(pos.state.turn, &list);

    try expectEqual(7, list.items.len);
}

test "MovegenBishop" {
    var s: position.State = position.State{};
    var pos = position.Position.setFen(&s, "3k4/8/8/B5BB/8/1B4B1/5B2/2BKB3 w - - 0 1");
    tables.initAll(allocator);
    defer tables.deinitAll();

    var list = std.ArrayList(types.Move).init(allocator);
    defer list.deinit();

    pos.generateLegalMoves(pos.state.turn, &list);

    try expectEqual(52, list.items.len);
}

test "MovegenRook" {
    var s: position.State = position.State{};
    var pos = position.Position.setFen(&s, "3k4/8/8/R5RR/8/1R4R1/5R2/2RKR3 w - - 0 1");
    tables.initAll(allocator);
    defer tables.deinitAll();

    var list = std.ArrayList(types.Move).init(allocator);
    defer list.deinit();

    pos.generateLegalMoves(pos.state.turn, &list);

    try expectEqual(84, list.items.len);
}

test "MovegenSliders" {
    var s: position.State = position.State{};
    var pos = position.Position.setFen(&s, "3k4/4R3/3B4/1Q6/8/5R2/2Q1B3/1Q1K1R2 w - - 0 1");
    tables.initAll(allocator);
    defer tables.deinitAll();

    var list = std.ArrayList(types.Move).init(allocator);
    defer list.deinit();

    pos.generateLegalMoves(pos.state.turn, &list);

    try expectEqual(86, list.items.len);
}

test "MovegenKing" {
    var s: position.State = position.State{};
    var pos: position.Position = position.Position.setFen(&s, "3qkr2/8/8/8/8/8/8/4K3 w - - 0 1");
    tables.initAll(allocator);
    defer tables.deinitAll();

    var list = std.ArrayList(types.Move).init(allocator);
    defer list.deinit();

    pos.generateLegalMoves(pos.state.turn, &list);

    try expectEqual(1, list.items.len);

    list.clearAndFree();

    pos = position.Position.setFen(&s, "3qk3/8/8/8/8/8/8/R3K2R w KQ - 0 1");
    pos.generateLegalMoves(pos.state.turn, &list);

    try expectEqual(23, list.items.len);
}
