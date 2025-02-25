//! This module provides tests for the 960 support of the program

const position = @import("position.zig");
const std = @import("std");
const tables = @import("tables.zig");
const types = @import("types.zig");

const expect = std.testing.expect;

test "Castle" {
    var s: position.State = position.State{};
    var pos = position.Position.setFen(&s, "2k5/8/8/8/8/8/8/R2K2R1 w KQ - 0 1");
    var alloc = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = alloc.allocator();
    tables.initAll(allocator);
    defer tables.deinitAll();

    var list = std.ArrayList(types.Move).init(allocator);
    defer list.deinit();

    pos.generateLegalMoves(pos.state.turn, &list);

    try expect(list.items.len == 26);
}

test "CastleIntersect" {
    var s: position.State = position.State{};
    var pos = position.Position.setFen(&s, "1qk5/8/8/8/8/8/8/R1K1R3 w KQ - 0 1");
    var alloc = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = alloc.allocator();
    tables.initAll(allocator);
    defer tables.deinitAll();

    var list = std.ArrayList(types.Move).init(allocator);
    defer list.deinit();

    pos.generateLegalMoves(pos.state.turn, &list);

    try expect(list.items.len == 24);
}
