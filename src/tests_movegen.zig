//! This module provides tests for move generation of the program

const position = @import("position.zig");
const std = @import("std");
const tables = @import("tables.zig");
const types = @import("types.zig");

const expect = std.testing.expect;

test "MovegenEnPassant" {
    var s: position.State = position.State{};
    var pos = position.Position.setFen(&s, "4k3/8/8/3pPp2/8/8/8/4K3 w - d6 0 3");
    var alloc = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = alloc.allocator();
    tables.initAll(allocator);
    defer tables.deinitAll();

    var list = std.ArrayList(types.Move).init(allocator);
    defer list.deinit();

    pos.generateLegalMoves(pos.state.turn, &list);

    try expect(list.items.len == 7);
}

test "MovegenBishop" {
    var s: position.State = position.State{};
    var pos = position.Position.setFen(&s, "3k4/8/8/B5BB/8/1B4B1/5B2/2BKB3 w - - 0 1");
    var alloc = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = alloc.allocator();
    tables.initAll(allocator);
    defer tables.deinitAll();

    var list = std.ArrayList(types.Move).init(allocator);
    defer list.deinit();

    pos.generateLegalMoves(pos.state.turn, &list);

    try expect(list.items.len == 52);
}

test "MovegenRook" {
    var s: position.State = position.State{};
    var pos = position.Position.setFen(&s, "3k4/8/8/R5RR/8/1R4R1/5R2/2RKR3 w - - 0 1");
    var alloc = std.heap.DebugAllocator(.{}){};
    const allocator = alloc.allocator();
    tables.initAll(allocator);
    defer tables.deinitAll();

    var list = std.ArrayList(types.Move).init(allocator);
    defer list.deinit();

    pos.generateLegalMoves(pos.state.turn, &list);

    try expect(list.items.len == 84);
}

test "MovegenSliders" {
    var s: position.State = position.State{};
    var pos = position.Position.setFen(&s, "3k4/4R3/3B4/1Q6/8/5R2/2Q1B3/1Q1K1R2 w - - 0 1");
    var alloc = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = alloc.allocator();
    tables.initAll(allocator);
    defer tables.deinitAll();

    var list = std.ArrayList(types.Move).init(allocator);
    defer list.deinit();

    pos.generateLegalMoves(pos.state.turn, &list);

    try expect(list.items.len == 86);
}

test "MovegenKing" {
    var s: position.State = position.State{};
    var pos: position.Position = position.Position.setFen(&s, "3qkr2/8/8/8/8/8/8/4K3 w - - 0 1");
    var alloc = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = alloc.allocator();
    tables.initAll(allocator);
    defer tables.deinitAll();

    var list = std.ArrayList(types.Move).init(allocator);
    defer list.deinit();

    pos.generateLegalMoves(pos.state.turn, &list);

    try expect(list.items.len == 1);

    list.clearAndFree();

    pos = position.Position.setFen(&s, "3qk3/8/8/8/8/8/8/R3K2R w KQ - 0 1");
    pos.generateLegalMoves(pos.state.turn, &list);

    try expect(list.items.len == 23);
}
