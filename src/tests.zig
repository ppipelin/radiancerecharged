//! This module provides tests for key components of the program

const position = @import("position.zig");
const std = @import("std");
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
    try expect(pos.bb_pieces[types.Piece.w_knight.index()] == 0);
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
