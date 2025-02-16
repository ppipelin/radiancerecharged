//! This module provides tests for key components of the program

const position = @import("position.zig");
const std = @import("std");
const tables = @import("tables.zig");
const types = @import("types.zig");

const expect = std.testing.expect;

test "Position" {
    var s: position.State = position.State{};
    var pos = position.Position.new(&s);
    try expect(pos.state.material_key == 0);
    try expect(pos.state.turn == types.Color.white);
    try expect(pos.state.game_ply == 0);
    try expect(pos.board[0] == types.Piece.none);

    pos.add(types.Piece.w_knight, types.Square.f3);
    try expect(pos.board[types.Square.f3.index()] == types.Piece.w_knight);
    try expect(pos.bb_pieces[types.PieceType.knight.index()] == 0x200000);

    pos.remove(types.Piece.w_knight, types.Square.f3);
    try expect(pos.board[types.Square.f3.index()] == types.Piece.none);
    try expect(pos.bb_pieces[types.PieceType.knight.index()] == 0);
}

test "Fen" {
    var s: position.State = position.State{};
    const fen = position.start_fen;
    var pos = position.Position.setFen(&s, fen);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    try expect(std.mem.eql(u8, fen[0 .. fen.len - 2], pos.getFen(allocator) catch unreachable));

    const move: types.Move = types.Move{ .flags = types.MoveFlags.double_push.index(), .from = 12, .to = 28 };
    var s2: position.State = position.State{};
    pos.movePiece(move, &s2) catch unreachable;
    try expect(std.mem.eql(u8, "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0", pos.getFen(allocator) catch unreachable));

    pos.unMovePiece(move, false) catch unreachable;
    try expect(std.mem.eql(u8, fen[0 .. fen.len - 2], pos.getFen(allocator) catch unreachable));
}

test "Move" {
    try expect(@sizeOf(types.Move) == 2);
    try expect(@bitSizeOf(types.Move) == 16);
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

test "PerftKiwipete" {
    var s: position.State = position.State{};
    var pos = position.Position.setFen(&s, position.kiwipete);
    var alloc = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = alloc.allocator();
    tables.initAll(allocator);
    defer tables.deinitAll();

    var list = std.ArrayList(types.Move).init(allocator);
    defer list.deinit();

    pos.generateLegalMoves(pos.state.turn, &list);

    pos.debugPrint();
    std.debug.print("{}\n", .{list.items.len});

    for (list.items) |item| {
        item.uciPrint(std.io.getStdErr().writer());
        std.debug.print("\n", .{});
    }

    try expect(list.items.len == 48);
}
