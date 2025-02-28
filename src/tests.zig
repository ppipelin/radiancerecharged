//! This module provides tests for key components of the program

const position = @import("position.zig");
const std = @import("std");
const tables = @import("tables.zig");
const types = @import("types.zig");

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;

const allocator = std.testing.allocator;

test "Position" {
    var s: position.State = position.State{};
    var pos = position.Position.new(&s);
    try expectEqual(0, pos.state.material_key);
    try expectEqual(types.Color.white, pos.state.turn);
    try expectEqual(1, pos.state.game_ply);
    try expectEqual(types.Piece.none, pos.board[0]);

    pos.add(types.Piece.w_knight, types.Square.f3);
    try expectEqual(types.Piece.w_knight, pos.board[types.Square.f3.index()]);
    try expectEqual(0x200000, pos.bb_pieces[types.PieceType.knight.index()]);

    pos.remove(types.Piece.w_knight, types.Square.f3);
    try expectEqual(types.Piece.none, pos.board[types.Square.f3.index()]);
    try expectEqual(0, pos.bb_pieces[types.PieceType.knight.index()]);
}

test "Fen" {
    var s: position.State = position.State{};
    const fen = position.start_fen;
    var pos = position.Position.setFen(&s, fen);

    var buffer: [90]u8 = undefined;
    const new_fen = pos.getFen(&buffer);

    try std.testing.expectEqualSlices(u8, fen, new_fen);
}

test "Move" {
    try expectEqual(2, @sizeOf(types.Move));
    try expectEqual(16, @bitSizeOf(types.Move));
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

    var buffer: [90]u8 = undefined;
    const new_fen = pos.getFen(&buffer);

    try std.testing.expectEqualSlices(u8, position.start_fen, new_fen);
}
