const std = @import("std");
const types = @import("types.zig");

const Color = types.Color;
const Bitboard = types.Bitboard;

pub var moves_bishop_mask: [types.board_size2]Bitboard = std.mem.zeroes([types.board_size2]Bitboard);
pub var moves_rook_mask: [types.board_size2]Bitboard = std.mem.zeroes([types.board_size2]Bitboard);
pub var moves_rook: [types.board_size2]std.AutoHashMap(Bitboard, Bitboard) = undefined;
pub var moves_bishop: [types.board_size2]std.AutoHashMap(Bitboard, Bitboard) = undefined;
pub var pseudo_legal_attacks: [types.PieceType.nb()][types.board_size2]Bitboard = std.mem.zeroes([types.PieceType.nb()][types.board_size2]Bitboard);
pub var pawn_attacks: [types.Color.nb()][types.board_size2]Bitboard = std.mem.zeroes([types.Color.nb()][types.board_size2]Bitboard);

pub inline fn filterMovesBishop(sq: types.Square) Bitboard {
    var b: Bitboard = 0;
    const sq_bb: Bitboard = sq.sqToBB();
    // Surely not the fastest: finds the diagonals that collides with tile
    for (0..types.board_size - 1) |i| {
        // Shifts is bounded by overflow
        // Diagonals go up
        const computed_clockwise_up: Bitboard = types.diagonal_clockwise << @intCast(i * types.board_size);
        if (computed_clockwise_up & sq_bb > 0)
            b |= computed_clockwise_up;

        const computed_counter_clockwise_up: Bitboard = types.diagonal_counter_clockwise << @intCast(i * types.board_size);
        if (computed_counter_clockwise_up & sq_bb > 0)
            b |= computed_counter_clockwise_up;

        // Diagonals go down
        const computedClockwiseDown: Bitboard = types.diagonal_clockwise >> @intCast(i * types.board_size);
        if (computedClockwiseDown & sq_bb > 0)
            b |= computedClockwiseDown;

        const computedCounterClockwiseDown: Bitboard = types.diagonal_counter_clockwise >> @intCast(i * types.board_size);
        if (computedCounterClockwiseDown & sq_bb > 0)
            b |= computedCounterClockwiseDown;
    }

    b &= ~sq_bb;

    // Remove bordered square as they can be treated as blockers

    b &= ~types.file;
    b &= ~(types.file << (types.board_size - 1));
    b &= ~types.rank;
    b &= ~(types.rank << (types.board_size - 1) * types.board_size);
    return b;
}

pub inline fn filterMovesRook(sq: types.Square) Bitboard {
    var b: Bitboard = 0;
    const current_file: u6 = sq.file().index();
    const current_rank: u6 = sq.rank().index();

    b |= types.file << current_file;
    b |= types.rank << (current_rank * types.board_size);
    b &= ~sq.sqToBB();

    // Remove bordered square as they can be treated as blockers
    b &= ~types.Square.intToBB(0 + current_file); // Bottom
    b &= ~types.Square.intToBB(types.board_size2 - types.board_size + current_file); // Top
    b &= ~types.Square.intToBB(types.board_size - 1 + (current_rank * types.board_size)); // Right
    b &= ~types.Square.intToBB(current_rank * types.board_size); // Left

    return b;
}

pub fn computeBlockers(mask_: Bitboard, v: *std.ArrayList(Bitboard)) void {
    const bit_indices_size: u4 = @truncate(@popCount(mask_)); // Max is (types.board_size)*2-3
    for (1..std.math.pow(u64, 2, bit_indices_size)) |blocker_configuration| {
        var mask: Bitboard = mask_;
        var currentBlockerBB: Bitboard = 0;
        var cnt: u6 = 0;
        while (mask != 0) : (cnt += 1) {
            const bit_idx: u6 = @truncate(types.popLsb(&mask).index());

            const current_bit: Bitboard = (@as(u64, blocker_configuration) >> cnt) & 1; // Is the shifted bit in blocker_configuration activated
            currentBlockerBB |= current_bit << bit_idx; // Shift it back to its position
        }
        v.append(currentBlockerBB) catch unreachable;
    }
}

// Hyperbola Quintessence Algorithm
// https://www.chessprogramming.org/Hyperbola_Quintessence
// https://chess.stackexchange.com/questions/37309/move-generation-for-sliding-pieces-and-hyperbola-quintessence
fn slidingBB(sq: types.Square, blockers: types.Bitboard, mask: types.Bitboard) Bitboard {
    return (((mask & blockers) -% sq.sqToBB() *% 2) ^
        reverseBitboard(reverseBitboard(mask & blockers) -% reverseBitboard(sq.sqToBB()) *% 2)) & mask;
}

inline fn reverseBitboard(b_: Bitboard) Bitboard {
    var b = b_;
    b = (b & 0x5555555555555555) << 1 | ((b >> 1) & 0x5555555555555555);
    b = (b & 0x3333333333333333) << 2 | ((b >> 2) & 0x3333333333333333);
    b = (b & 0x0f0f0f0f0f0f0f0f) << 4 | ((b >> 4) & 0x0f0f0f0f0f0f0f0f);
    b = (b & 0x00ff00ff00ff00ff) << 8 | ((b >> 8) & 0x00ff00ff00ff00ff);

    return (b << 48) | ((b & 0xffff0000) << 16) |
        ((b >> 16) & 0xffff0000) | (b >> 48);
}

inline fn getBishopAttacks(sq: types.Square, blockers: types.Bitboard) types.Bitboard {
    return slidingBB(sq, blockers, types.mask_diagonal[@intCast(sq.diagonal())]) | slidingBB(sq, blockers, types.mask_anti_diagonal[@intCast(sq.antiDiagonal())]);
}

inline fn getRookAttacks(sq: types.Square, blockers: types.Bitboard) types.Bitboard {
    return slidingBB(sq, blockers, types.mask_file[sq.file().index()]) | slidingBB(sq, blockers, types.mask_rank[sq.rank().index()]);
}

pub fn initSlidersAttacks(alloc: std.mem.Allocator) void {
    // Compute moveable squares
    var sq: types.Square = types.Square.a1;
    while (sq != types.Square.none) : (sq = sq.inc().*) {
        moves_bishop_mask[sq.index()] = filterMovesBishop(sq);
        moves_rook_mask[sq.index()] = filterMovesRook(sq);
    }

    // Compute blockers
    sq = types.Square.a1;
    while (sq != types.Square.none) : (sq = sq.inc().*) {
        // Bishop
        moves_bishop[sq.index()] = std.AutoHashMap(Bitboard, Bitboard).init(alloc);
        var moves_bishop_blockers = std.ArrayList(Bitboard).init(alloc);
        defer moves_bishop_blockers.deinit();

        moves_bishop_blockers.append(0) catch unreachable;
        computeBlockers(moves_bishop_mask[sq.index()], &moves_bishop_blockers);

        for (moves_bishop_blockers.items) |blockers| {
            moves_bishop[sq.index()].put(blockers, getBishopAttacks(sq, blockers)) catch unreachable;
        }

        // Rook
        moves_rook[sq.index()] = std.AutoHashMap(Bitboard, Bitboard).init(alloc);
        var moves_rook_blockers = std.ArrayList(Bitboard).init(alloc);
        defer moves_rook_blockers.deinit();

        moves_rook_blockers.append(0) catch unreachable;
        computeBlockers(moves_rook_mask[sq.index()], &moves_rook_blockers);

        for (moves_rook_blockers.items) |blockers| {
            moves_rook[sq.index()].put(blockers, getRookAttacks(sq, blockers)) catch unreachable;
        }
    }
}

pub fn initNonBlockable() void {
    std.mem.copyForwards(Bitboard, pawn_attacks[Color.black.index()][0..types.board_size2], black_pawn_attacks[0..types.board_size2]);
    std.mem.copyForwards(Bitboard, pawn_attacks[Color.white.index()][0..types.board_size2], white_pawn_attacks[0..types.board_size2]);
    std.mem.copyForwards(Bitboard, pseudo_legal_attacks[types.PieceType.knight.index()][0..types.board_size2], knight_attacks[0..types.board_size2]);
    std.mem.copyForwards(Bitboard, pseudo_legal_attacks[types.PieceType.king.index()][0..types.board_size2], king_attacks[0..types.board_size2]);
    // var sq: usize = types.Square.a1.index();

    // while (sq <= types.Square.h8.index()) : (sq += 1) {
    //     // pseudo_legal_attacks[types.PieceType.bishop.index()][sq] = getBishopAttacks(@enumFromInt(types.Square, sq), 0);
    //     // pseudo_legal_attacks[types.PieceType.rook.index()][sq] = getRookAttacks(@enumFromInt(types.Square, sq), 0);
    //     pseudo_legal_attacks[types.PieceType.queen.index()][sq] = pseudo_legal_attacks[types.PieceType.bishop.index()][sq] | pseudo_legal_attacks[types.PieceType.rook.index()][sq];
    // }
}

pub fn initAll(alloc: std.mem.Allocator) void {
    initSlidersAttacks(alloc);
    initNonBlockable();
}

pub fn deinitAll() void {
    var sq: u8 = types.Square.a1.index();
    while (sq <= types.Square.h8.index()) : (sq += 1) {
        moves_bishop[sq].deinit();
        moves_rook[sq].deinit();
    }
}

pub inline fn getAttacks(pt: types.PieceType, color: types.Color, sq: types.Square, blockers: Bitboard) Bitboard {
    return switch (pt) {
        types.PieceType.pawn => pawn_attacks[color.index()][sq.index()],
        types.PieceType.rook => moves_rook[sq.index()].get(moves_rook_mask[sq.index()] & blockers) orelse unreachable,
        types.PieceType.bishop => moves_bishop[sq.index()].get(moves_bishop_mask[sq.index()] & blockers) orelse unreachable,
        types.PieceType.queen => (moves_rook[sq.index()].get(moves_rook_mask[sq.index()] & blockers) orelse unreachable) | (moves_bishop[sq.index()].get(moves_bishop_mask[sq.index()] & blockers) orelse unreachable),
        else => pseudo_legal_attacks[pt.index()][sq.index()],
    };
}

// zig fmt: off
pub const king_attacks = [64]Bitboard{
    0x302,              0x705,              0xe0a,               0x1c14,              0x3828,              0x7050,              0xe0a0,              0xc040,
    0x30203,            0x70507,            0xe0a0e,             0x1c141c,            0x382838,            0x705070,            0xe0a0e0,            0xc040c0,
    0x3020300,          0x7050700,          0xe0a0e00,           0x1c141c00,          0x38283800,          0x70507000,          0xe0a0e000,          0xc040c000,
    0x302030000,        0x705070000,        0xe0a0e0000,         0x1c141c0000,        0x3828380000,        0x7050700000,        0xe0a0e00000,        0xc040c00000,
    0x30203000000,      0x70507000000,      0xe0a0e000000,       0x1c141c000000,      0x382838000000,      0x705070000000,      0xe0a0e0000000,      0xc040c0000000,
    0x3020300000000,    0x7050700000000,    0xe0a0e00000000,     0x1c141c00000000,    0x38283800000000,    0x70507000000000,    0xe0a0e000000000,    0xc040c000000000,
    0x302030000000000,  0x705070000000000,  0xe0a0e0000000000,   0x1c141c0000000000,  0x3828380000000000,  0x7050700000000000,  0xe0a0e00000000000,  0xc040c00000000000,
    0x203000000000000,  0x507000000000000,  0xa0e000000000000,   0x141c000000000000,  0x2838000000000000,  0x5070000000000000,  0xa0e0000000000000,  0x40c0000000000000,
};

pub const knight_attacks = [64]Bitboard{
    0x20400,            0x50800,            0xa1100,             0x142200,            0x284400,            0x508800,            0xa01000,            0x402000,
    0x2040004,          0x5080008,          0xa110011,           0x14220022,          0x28440044,          0x50880088,          0xa0100010,          0x40200020,
    0x204000402,        0x508000805,        0xa1100110a,         0x1422002214,        0x2844004428,        0x5088008850,        0xa0100010a0,        0x4020002040,
    0x20400040200,      0x50800080500,      0xa1100110a00,       0x142200221400,      0x284400442800,      0x508800885000,      0xa0100010a000,      0x402000204000,
    0x2040004020000,    0x5080008050000,    0xa1100110a0000,     0x14220022140000,    0x28440044280000,    0x50880088500000,    0xa0100010a00000,    0x40200020400000,
    0x204000402000000,  0x508000805000000,  0xa1100110a000000,   0x1422002214000000,  0x2844004428000000,  0x5088008850000000,  0xa0100010a0000000,  0x4020002040000000,
    0x400040200000000,  0x800080500000000,  0x1100110a00000000,  0x2200221400000000,  0x4400442800000000,  0x8800885000000000,  0x100010a000000000,  0x2000204000000000,
    0x4020000000000,    0x8050000000000,    0x110a0000000000,    0x22140000000000,    0x44280000000000,    0x0088500000000000,  0x0010a00000000000,  0x20400000000000,
};

pub const white_pawn_attacks = [64]Bitboard{
    0x200,              0x500,              0xa00,              0x1400,              0x2800,               0x5000,              0xa000,              0x4000,
    0x20000,            0x50000,            0xa0000,            0x140000,            0x280000,             0x500000,            0xa00000,            0x400000,
    0x2000000,          0x5000000,          0xa000000,          0x14000000,          0x28000000,           0x50000000,          0xa0000000,          0x40000000,
    0x200000000,        0x500000000,        0xa00000000,        0x1400000000,        0x2800000000,         0x5000000000,        0xa000000000,        0x4000000000,
    0x20000000000,      0x50000000000,      0xa0000000000,      0x140000000000,      0x280000000000,       0x500000000000,      0xa00000000000,      0x400000000000,
    0x2000000000000,    0x5000000000000,    0xa000000000000,    0x14000000000000,    0x28000000000000,     0x50000000000000,    0xa0000000000000,    0x40000000000000,
    0x200000000000000,  0x500000000000000,  0xa00000000000000,  0x1400000000000000,  0x2800000000000000,   0x5000000000000000,  0xa000000000000000,  0x4000000000000000,
    0x0,                0x0,                0x0,                0x0,                 0x0,                  0x0,                 0x0,                 0x0,
};

pub const black_pawn_attacks = [64]Bitboard{
    0x0,                0x0,                0x0,                0x0,                 0x0,                  0x0,                 0x0,                 0x0,
    0x2,                0x5,                0xa,                0x14,                0x28,                 0x50,                0xa0,                0x40,
    0x200,              0x500,              0xa00,              0x1400,              0x2800,               0x5000,              0xa000,              0x4000,
    0x20000,            0x50000,            0xa0000,            0x140000,            0x280000,             0x500000,            0xa00000,            0x400000,
    0x2000000,          0x5000000,          0xa000000,          0x14000000,          0x28000000,           0x50000000,          0xa0000000,          0x40000000,
    0x200000000,        0x500000000,        0xa00000000,        0x1400000000,        0x2800000000,         0x5000000000,        0xa000000000,        0x4000000000,
    0x20000000000,      0x50000000000,      0xa0000000000,      0x140000000000,      0x280000000000,       0x500000000000,      0xa00000000000,      0x400000000000,
    0x2000000000000,    0x5000000000000,    0xa000000000000,    0x14000000000000,    0x28000000000000,     0x50000000000000,    0xa0000000000000,    0x40000000000000,
};
// zig fmt: on
