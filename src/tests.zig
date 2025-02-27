//! This module provides tests for key components of the program

const position = @import("position.zig");
const std = @import("std");
const tables = @import("tables.zig");
const types = @import("types.zig");

const expect = std.testing.expect;

const allocator = std.testing.allocator;

test "Position" {
    var s: position.State = position.State{};
    var pos = position.Position.new(&s);
    try expect(pos.state.material_key == 0);
    try expect(pos.state.turn == types.Color.white);
    try expect(pos.state.game_ply == 1);
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

    const new_fen = pos.getFen(allocator) catch unreachable;
    defer new_fen.deinit();

    try expect(std.mem.eql(u8, fen[0..fen.len], new_fen.items));
}

test "Move" {
    try expect(@sizeOf(types.Move) == 2);
    try expect(@bitSizeOf(types.Move) == 16);
}

test "MoveUnmovePiece" {
    var s: position.State = position.State{};
    var pos = position.Position.setFen(&s, position.start_fen);

    var s2: position.State = position.State{};
    try pos.movePiece(types.Move{ .from = @truncate(types.Square.a2.index()), .to = @truncate(types.Square.a3.index()) }, &s2);

    var s3: position.State = position.State{};
    try pos.movePiece(types.Move{ .from = @truncate(types.Square.e7.index()), .to = @truncate(types.Square.e6.index()) }, &s3);

    try pos.unMovePiece(types.Move{ .from = @truncate(types.Square.e7.index()), .to = @truncate(types.Square.e6.index()) }, false);

    try pos.unMovePiece(types.Move{ .from = @truncate(types.Square.a2.index()), .to = @truncate(types.Square.a3.index()) }, false);

    const new_fen = pos.getFen(allocator) catch unreachable;
    defer new_fen.deinit();

    try expect(std.mem.eql(u8, position.start_fen, new_fen.items));
}
