const position = @import("position.zig");
const types = @import("types.zig");

fn evaluateShannonColor(pos: position.Position, col: types.Color) types.Value {
    const us_bb: types.Bitboard = pos.bb_colors[col.index()];
    return @as(types.Value, @popCount(pos.bb_pieces[types.PieceType.king.index()] & us_bb)) * 20_000 +
        @as(types.Value, @popCount(pos.bb_pieces[types.PieceType.queen.index()] & us_bb)) * 900 +
        @as(types.Value, @popCount(pos.bb_pieces[types.PieceType.rook.index()] & us_bb)) * 500 +
        @as(types.Value, @popCount(pos.bb_pieces[types.PieceType.bishop.index()] & us_bb)) * 300 +
        @as(types.Value, @popCount(pos.bb_pieces[types.PieceType.knight.index()] & us_bb)) * 300 +
        @as(types.Value, @popCount(pos.bb_pieces[types.PieceType.pawn.index()] & us_bb)) * 100;
}

pub fn evaluateShannon(pos: position.Position) types.Value {
    return evaluateShannonColor(pos, pos.state.turn) - evaluateShannonColor(pos, pos.state.turn.invert());
}

pub fn evaluateTableTunedBitboard(pos: position.Position) types.Value {
    _ = pos;
    return 0;
}
