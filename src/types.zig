//! This module provides functions types for pieces, colors and bitboards related components

const std = @import("std");

////// Chess //////

pub const board_size = 8;
pub const board_size2 = board_size * board_size;

// zig fmt: off
pub const square_to_string = [_][]const u8{
    "a1", "b1", "c1", "d1", "e1", "f1", "g1", "h1",
    "a2", "b2", "c2", "d2", "e2", "f2", "g2", "h2",
    "a3", "b3", "c3", "d3", "e3", "f3", "g3", "h3",
    "a4", "b4", "c4", "d4", "e4", "f4", "g4", "h4",
    "a5", "b5", "c5", "d5", "e5", "f5", "g5", "h5",
    "a6", "b6", "c6", "d6", "e6", "f6", "g6", "h6",
    "a7", "b7", "c7", "d7", "e7", "f7", "g7", "h7",
    "a8", "b8", "c8", "d8", "e8", "f8", "g8", "h8",
    "none"
};
// zig fmt: on

pub const Square = enum(u8) {
    // zig fmt: off
    a1, b1, c1, d1, e1, f1, g1, h1,
    a2, b2, c2, d2, e2, f2, g2, h2,
    a3, b3, c3, d3, e3, f3, g3, h3,
    a4, b4, c4, d4, e4, f4, g4, h4,
    a5, b5, c5, d5, e5, f5, g5, h5,
    a6, b6, c6, d6, e6, f6, g6, h6,
    a7, b7, c7, d7, e7, f7, g7, h7,
    a8, b8, c8, d8, e8, f8, g8, h8,
    none,
    // zig fmt: on

    pub inline fn inc(self: *Square) *Square {
        self.* = @enumFromInt(@intFromEnum(self.*) + 1);
        return self;
    }

    pub inline fn add(self: Square, d: Direction) Square {
        return @enumFromInt(@intFromEnum(self) + @intFromEnum(d));
    }

    pub inline fn sub(self: Square, d: Direction) Square {
        return @enumFromInt(@intFromEnum(self) - @intFromEnum(d));
    }

    pub inline fn rank(self: Square) Rank {
        return @enumFromInt(@intFromEnum(self) >> 3);
    }

    pub inline fn file(self: Square) File {
        return @enumFromInt(@intFromEnum(self) & 0b111);
    }

    pub inline fn diagonal(self: Square) i32 {
        return 7 + @intFromEnum(self.rank()) - @intFromEnum(self.file());
    }

    pub inline fn antiDiagonal(self: Square) i32 {
        return @intFromEnum(self.rank()) + @intFromEnum(self.file());
    }

    pub inline fn new(f: File, r: Rank) Square {
        return @enumFromInt(@intFromEnum(f) | (@intFromEnum(r) << 3));
    }

    pub inline fn index(self: Square) u8 {
        return @intFromEnum(self);
    }

    pub inline fn sqToBB(self: Square) Bitboard {
        const sq: u6 = @truncate(@intFromEnum(self));
        return @shlExact(@as(Bitboard, 1), sq);
    }
};

pub const Direction = enum(i32) {
    north = board_size,
    south = -board_size,
    // south = -@intFromEnum(Direction.north),
    east = 1,
    west = -1,
    // west = -@intFromEnum(Direction.east),

    north_east = 9,
    south_east = -7,
    north_west = 7,
    south_west = -9,

    // north_east = @intFromEnum(Direction.north) + @intFromEnum(Direction.east),
    // south_east = @intFromEnum(Direction.south) + @intFromEnum(Direction.east),
    // north_west = @intFromEnum(Direction.north) + @intFromEnum(Direction.west),
    // south_west = @intFromEnum(Direction.south) + @intFromEnum(Direction.west),

    // double push
    north_north = 16,
    south_south = -16,
    // north_north = @intFromEnum(Direction.north) * 2,
    // south_south = @intFromEnum(Direction.south) * 2,
};

pub const File = enum(u8) {
    fa,
    fb,
    fc,
    fd,
    fe,
    ff,
    fg,
    fh,

    pub inline fn index(self: File) u8 {
        return @intFromEnum(self);
    }
};

pub const Rank = enum(u8) {
    r1,
    r2,
    r3,
    r4,
    r5,
    r6,
    r7,
    r8,

    pub inline fn index(self: Rank) u8 {
        return @intFromEnum(self);
    }

    // pub inline fn relative_rank(self: Rank, comptime c: Color) Rank {
    //     return if (c == Color.White) self else @enumFromInt(@intFromEnum(Rank.RANK8) - @intFromEnum(self));
    // }
};

pub const PieceType = enum(u3) {
    none,
    pawn,
    knight,
    bishop,
    rook,
    queen,
    king,
    nb,

    pub inline fn index(self: PieceType) u3 {
        return @intFromEnum(self);
    }
};

pub const PieceNotation: []const u8 = " PNBRQKpnbrqk";

pub const Piece = enum(u4) {
    none,
    w_pawn,
    w_knight,
    w_bishop,
    w_rook,
    w_queen,
    w_king,
    b_pawn,
    b_knight,
    b_bishop,
    b_rook,
    b_queen,
    b_king,
    // nb = 16,

    pub inline fn index(self: Piece) u8 {
        return @intFromEnum(self);
    }

    pub inline fn pieceToPieceType(self: Piece) PieceType {
        return @enumFromInt(@intFromEnum(self) % 6);
    }

    pub inline fn pieceToColor(self: Piece) Color {
        return @enumFromInt(@intFromBool(self.index() > 6));
    }
};

pub const Color = enum(u1) {
    black,
    white,

    pub inline fn index(self: Color) u1 {
        return @intFromEnum(self);
    }

    pub inline fn invert(self: Color) Color {
        return @enumFromInt(@intFromEnum(self) ^ 1);
    }
};

/// Chess move described like in https://www.chessprogramming.org/Encoding_Moves
// Packed Struct makes it fit into a 16-bit integer.
pub const Move = packed struct {
    flags: u4 = 0,
    from: u6,
    to: u6,

    pub inline fn getFlags(self: Move) MoveFlags {
        return @enumFromInt(self.flags);
    }

    pub inline fn getFrom(self: Move) Square {
        return @enumFromInt(self.from);
    }

    pub inline fn getTo(self: Move) Square {
        return @enumFromInt(self.to);
    }

    pub inline fn isCastle(self: Move) bool {
        return self.flags ^ 0x2 <= 1;
    }

    pub inline fn isCapture(self: Move) bool {
        return (self.flags == 8) or (self.flags == 10) or (self.flags >= 12 and self.flags <= 15);
    }

    pub inline fn isEnPassant(self: Move) bool {
        return self.flags == 5;
    }

    pub inline fn isPromotion(self: Move) bool {
        return (self.flags >> 3) > 0;
    }

    pub inline fn equalsTo(self: Move, other: Move) bool {
        return self.from == other.from and self.to == other.to;
    }

    pub fn uciPrint(self: Move, writer: anytype) void {
        writer.print("{s}{s}", .{
            square_to_string[self.from],
            square_to_string[self.to],
        }) catch {};
        if (self.is_promotion()) {
            writer.print("{c}", .{
                prom_move_type_string[self.flags][0],
            }) catch {};
        }
    }
};

pub const prom_move_type_string = [_][]const u8{ "", "", "", " ", "", "", "", "", "n", "b", "r", "q", "n", "b", "r", "q" };

pub const MoveFlags = enum(u4) {
    quiet = 0b0000,
    double_push = 0b0001,
    oo = 0b0010,
    ooo = 0b0011,
    capture = 0b0100,
    en_passant = 0b0101,
    pr_knight = 0b1000,
    pr_bishop = 0b1001,
    pr_rook = 0b1010,
    pr_queen = 0b1011,
    prc_knight = 0b1100,
    prc_bishop = 0b1101,
    prc_rook = 0b1110,
    prc_queen = 0b1111,

    pub inline fn promote_type(self: MoveFlags) PieceType {
        return switch (@intFromEnum(self) & @intFromEnum(0b1000)) {
            MoveFlags.pr_knight => PieceType.Knight,
            MoveFlags.pr_bishop => PieceType.Bishop,
            MoveFlags.pr_rook => PieceType.Rook,
            MoveFlags.pr_queen => PieceType.Queen,
            else => unreachable,
        };
    }

    pub inline fn index(self: MoveFlags) u4 {
        return @intFromEnum(self);
    }
};

pub const Value = i16;

pub const max_moves = 218;

pub const value_zero: Value = 0;
pub const value_draw: Value = 0;

pub const value_mate: Value = 32000;
pub const value_infinite: Value = value_mate + 1;
pub const value_none: Value = value_mate + 2;

////// Bitboard //////

pub const Bitboard = u64;

pub const column: Bitboard = 0x0101010101010101; // A file
pub const row: Bitboard = 0xFF; // First rank
pub const diagonal_clockwise: Bitboard = 0b1000000001000000001000000001000000001000000001000000001000000001;
pub const diagonal_counter_clockwise: Bitboard = 0b0000000100000010000001000000100000010000001000000100000010000000;

pub const mask_file = [_]Bitboard{ column, column << 1, column << 2, column << 3, column << 4, column << 5, column << 6, column << 7 };
pub const mask_rank = [_]Bitboard{ row, row << board_size * 1, row << board_size * 2, row << board_size * 3, row << board_size * 4, row << board_size * 5, row << board_size * 7, row << board_size * 5 };

// pub const mask_diagonal = [_]Bitboard{
//     diagonal_clockwise >> 7,  diagonal_clockwise >> 6,  diagonal_clockwise >> 5,  diagonal_clockwise >> 4,  diagonal_clockwise >> 3,  diagonal_clockwise >> 2,  diagonal_clockwise >> 1,
//     diagonal_clockwise,       diagonal_clockwise <<| 1, diagonal_clockwise <<| 2, diagonal_clockwise <<| 3, diagonal_clockwise <<| 4, diagonal_clockwise <<| 5, diagonal_clockwise <<| 6,
//     diagonal_clockwise <<| 7,
// };

// pub const mask_anti_diagonal = [_]Bitboard{
//     mask_anti_diagonal >> 7,  mask_anti_diagonal >> 6,  mask_anti_diagonal >> 5,  mask_anti_diagonal >> 4,  mask_anti_diagonal >> 3,  mask_anti_diagonal >> 2,  mask_anti_diagonal >> 1,
//     mask_anti_diagonal,       mask_anti_diagonal <<| 1, mask_anti_diagonal <<| 2, mask_anti_diagonal <<| 3, mask_anti_diagonal <<| 4, mask_anti_diagonal <<| 5, mask_anti_diagonal <<| 6,
//     mask_anti_diagonal <<| 7,
// };

pub const mask_diagonal = [_]Bitboard{
    0x80,               0x8040,             0x804020,
    0x80402010,         0x8040201008,       0x804020100804,
    0x80402010080402,   0x8040201008040201, 0x4020100804020100,
    0x2010080402010000, 0x1008040201000000, 0x804020100000000,
    0x402010000000000,  0x201000000000000,  0x100000000000000,
};

pub const mask_anti_diagonal = [_]Bitboard{
    0x1,                0x102,              0x10204,
    0x1020408,          0x102040810,        0x10204081020,
    0x1020408102040,    0x102040810204080,  0x204081020408000,
    0x408102040800000,  0x810204080000000,  0x1020408000000000,
    0x2040800000000000, 0x4080000000000000, 0x8000000000000000,
};

// zig fmt: off
pub const square_index_bb = [_]Bitboard{
    0x1, 0x2, 0x4, 0x8,
    0x10, 0x20, 0x40, 0x80,
    0x100, 0x200, 0x400, 0x800,
    0x1000, 0x2000, 0x4000, 0x8000,
    0x10000, 0x20000, 0x40000, 0x80000,
    0x100000, 0x200000, 0x400000, 0x800000,
    0x1000000, 0x2000000, 0x4000000, 0x8000000,
    0x10000000, 0x20000000, 0x40000000, 0x80000000,
    0x100000000, 0x200000000, 0x400000000, 0x800000000,
    0x1000000000, 0x2000000000, 0x4000000000, 0x8000000000,
    0x10000000000, 0x20000000000, 0x40000000000, 0x80000000000,
    0x100000000000, 0x200000000000, 0x400000000000, 0x800000000000,
    0x1000000000000, 0x2000000000000, 0x4000000000000, 0x8000000000000,
    0x10000000000000, 0x20000000000000, 0x40000000000000, 0x80000000000000,
    0x100000000000000, 0x200000000000000, 0x400000000000000, 0x800000000000000,
    0x1000000000000000, 0x2000000000000000, 0x4000000000000000, 0x8000000000000000,
    0x0
};
// zig fmt: on

pub fn debugPrintBitboard(b: Bitboard) void {
    var i: i32 = 56;
    while (i >= 0) : (i -= 8) {
        var j: i32 = 0;
        while (j < 8) : (j += 1) {
            if ((b >> @intCast(i + j)) & 1 != 0) {
                std.debug.print("1 ", .{});
            } else {
                std.debug.print("0 ", .{});
            }
        }
        std.debug.print("\n", .{});
    }
    std.debug.print("\n", .{});
}

pub inline fn popcount(x: Bitboard) i32 {
    return @intCast(@popCount(x));
}

pub inline fn popcountUsize(x: Bitboard) usize {
    return @intCast(@popCount(x));
}

pub inline fn lsb(x: Bitboard) i32 {
    return @intCast(@ctz(x));
}

pub inline fn popLsb(x: *Bitboard) Square {
    const l = lsb(x.*);
    x.* &= x.* - 1;
    return @enumFromInt(l);
}
