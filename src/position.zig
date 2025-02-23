const std = @import("std");
const tables = @import("tables.zig");
const types = @import("types.zig");

const Bitboard = types.Bitboard;
const Color = types.Color;
const Direction = types.Direction;
const File = types.File;
const Move = types.Move;
const MoveFlags = types.MoveFlags;
const Piece = types.Piece;
const PieceType = types.PieceType;
const Rank = types.Rank;
const Square = types.Square;

pub const start_fen: []const u8 = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
pub const kiwipete: []const u8 = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -";

const CastleInfo = enum(u4) {
    none,
    q,
    k,
    kq,
    Q,
    Qq,
    Qk,
    Qkq,
    K,
    Kq,
    Kk,
    Kkq,
    KQ,
    KQq,
    KQk,
    KQkq,

    pub inline fn index(self: CastleInfo) u4 {
        return @intFromEnum(self);
    }

    pub inline fn indexLsb(self: CastleInfo) u4 {
        return types.lsb(@intFromEnum(self));
    }
};

pub const State = packed struct {
    turn: Color = Color.white,
    castle_info: CastleInfo = CastleInfo.KQkq,
    repetition: i7 = 0, // Zero if no repetition, x positive if happened once x half moves ago, negative indicates repetition
    rule_fifty: u6 = 0,
    game_ply: u32 = 0,
    en_passant: Square = Square.none,
    last_captured_piece: Piece = Piece.none,
    material_key: u64 = 0,
    previous: *State = undefined,
};

pub const Position = struct {
    // Board
    board: [types.board_size2]Piece = undefined,

    // Bitboards
    bb_pieces: [PieceType.nb()]Bitboard = undefined,
    bb_colors: [Color.nb()]Bitboard = undefined,

    // Zobrist Hash
    zobrist: u64 = 0,

    state: *State = undefined,

    pub fn new(state: *State) Position {
        var pos = Position{};

        @memset(pos.board[0..types.board_size2], Piece.none);
        pos.state = state;

        return pos;
    }

    /// Remove from board and bitboards
    pub inline fn remove(self: *Position, p: Piece, sq: Square) void {
        self.board[sq.index()] = types.Piece.none;
        const removeFilter: Bitboard = ~sq.sqToBB();
        self.bb_pieces[p.pieceToPieceType().index()] &= removeFilter;
        self.bb_colors[p.pieceToColor().index()] &= removeFilter;
        // update zobrist
    }

    /// Add to board and bitboards
    pub inline fn add(self: *Position, p: Piece, sq: Square) void {
        self.board[sq.index()] = p;
        const addFilter: Bitboard = sq.sqToBB();
        self.bb_pieces[p.pieceToPieceType().index()] |= addFilter;
        self.bb_colors[p.pieceToColor().index()] |= addFilter;
        // update zobrist
    }

    inline fn removeAdd(self: *Position, p: Piece, removeSq: Square, addSq: Square) void {
        self.board[removeSq.index()] = Piece.none;
        self.board[addSq.index()] = p;
        const removeFilter: Bitboard = removeSq.sqToBB() | addSq.sqToBB();
        self.bb_pieces[p.pieceToPieceType().index()] ^= removeFilter;
        self.bb_colors[p.pieceToColor().index()] ^= removeFilter;
        // update zobrist
    }

    pub inline fn movePiece(self: *Position, move: Move, state: *State) !void {
        // Reset data and set as previous
        state.castle_info = self.state.castle_info;
        // Increment ply counters. In particular, rule_fifty will be reset to zero later on in case of a capture or a pawn move.
        state.rule_fifty = self.state.rule_fifty + 1;
        state.game_ply = self.state.game_ply + 1;
        state.en_passant = Square.none;
        state.last_captured_piece = Piece.none;
        state.material_key = self.state.material_key;
        state.previous = self.state;
        self.state = state;

        const from: Square = move.getFrom();
        const to: Square = move.getTo();
        const from_piece: Piece = self.board[from.index()];
        const to_piece: Piece = self.board[to.index()];

        if (from_piece == Piece.none) {
            return error.MoveNone;
        }

        // Remove last enPassant
        if (self.state.previous.en_passant != Square.none) {
            // self.state.material_key ^= Zobrist::enPassant[Board::column(m_board->enPassant())];
        }

        switch (from_piece.pieceToPieceType()) {
            // Disable castle if king/rook is moved
            PieceType.king => {
                if (from_piece.pieceToColor() == Color.white) {
                    if (self.state.previous.castle_info.index() & CastleInfo.K.index() > 0) {
                        // self.state.material_key ^= ~Zobrist.caslting[0];
                    }
                    if (self.state.previous.castle_info.index() & CastleInfo.Q.index() > 0) {
                        // self.state.material_key ^= ~Zobrist.caslting[1];
                    }
                    self.state.castle_info = @enumFromInt(self.state.castle_info.index() & ~CastleInfo.KQ.index());
                } else {
                    if (self.state.previous.castle_info.index() & CastleInfo.k.index() > 0) {
                        // self.state.material_key ^= ~Zobrist.caslting[2];
                    }
                    if (self.state.previous.castle_info.index() & CastleInfo.q.index() > 0) {
                        // self.state.material_key ^= ~Zobrist.caslting[3];
                    }
                    self.state.castle_info = @enumFromInt(self.state.castle_info.index() & ~CastleInfo.kq.index());
                }
            },
            PieceType.rook => {
                const is_white = from_piece.pieceToColor() == Color.white;
                if (move.getFrom().file() == File.fh) {
                    if (self.state.castle_info.index() & (if (is_white) CastleInfo.K else CastleInfo.k) > 0) {
                        self.state.castle_info &= ~(if (is_white) CastleInfo.K.index() else CastleInfo.k.index());
                        // self.state.material_key ^= ~Zobrist.caslting[if (is_white) CastleInfo.K else CastleInfo.k) > 0];
                    }
                } else if (move.getFrom().file() == File.fa) {
                    if (self.state.castle_info.index() & (if (is_white) CastleInfo.Q else CastleInfo.q) > 0) {
                        self.state.castle_info &= ~(if (is_white) CastleInfo.Q.index() else CastleInfo.q.index());
                        // self.state.material_key ^= ~Zobrist.caslting[if (is_white) CastleInfo.Q else CastleInfo.q) > 0];
                    }
                }
            },
            PieceType.pawn => {
                // Updates enPassant if possible next turn
                switch (move.getFlags()) {
                    MoveFlags.double_push => {
                        self.state.en_passant = to.add(if (self.state.turn == Color.white) Direction.south else Direction.north);
                    },
                    MoveFlags.en_passant => {
                        const en_passant_sq = to.add(if (self.state.turn == Color.white) Direction.south else Direction.north);
                        self.state.last_captured_piece = self.board[en_passant_sq];

                        // Remove
                        self.remove(self.state.last_captured_piece, en_passant_sq);
                        // self.state.material_key ^= Zobrist.psq[self.state.last_captured_piece.pieceToPieceType()][en_passant_sq];

                        self.board[en_passant_sq] = Piece.none;
                    },
                    else => {},
                }
                // Reset rule 50 counter
                self.state.rule_fifty = 0;
            },
            else => {},
        }

        if (move.isCapture()) {
            if (to_piece == PieceType.none) {
                return error.CaptureNone;
            } else {
                // This should be the quickest to disable castle when rook is taken
                const castleRemove: CastleInfo = switch (to) {
                    0 => CastleInfo.K,
                    types.board_size - 1 => CastleInfo.Q,
                    types.board_size2 - types.board_size => CastleInfo.k,
                    types.board_size2 - 1 => CastleInfo.q,
                    else => CastleInfo.none,
                };

                if (CastleInfo.none != CastleInfo.none and (self.state.castle_info.index() | castleRemove.index())) {
                    self.state.castle_info &= ~castleRemove;
                    // self.state.material_key ^= ~Zobrist.caslting[castleRemove.indexLsb()];
                }

                self.state.last_captured_piece = to_piece;

                // Remove captured
                self.remove(to_piece, move.to);

                // Reset rule 50 counter
                self.state.rule_fifty = 0;
            }
        }

        // Add
        self.removeAdd(from_piece, from, to);

        self.state.game_ply += 1;
        self.state.turn = self.state.turn.invert();
        // self.state.material_key ^= Zobrist.side;

        // If castling we move the rook as well
        switch (move.getFlags()) {
            MoveFlags.oo => {
                var tmp: State = State{};
                state = self.state;
                self.movePiece(Move{ .flags = 0, .from = from + 3, .to = from + 3 - 2 }, &tmp); // CHESS 960 BUG
                // We have moved, we need to set the turn back
                self.state = &state;
            },
            MoveFlags.ooo => {
                var tmp: State = State{};
                state = self.state;
                self.movePiece(Move{ .flags = 0, .from = from - 4, .to = from - 4 + 3 }, &tmp); // CHESS 960 BUG
                // We have moved, we need to set the turn back
                self.state = &state;
            },
            else => {},
        }

        self.state.repetition = 0;
        if (self.state.rule_fifty >= 0) {
            var s2: *State = self.state.previous.previous; // BUG when loading from fen with rule_fifty
            var i: i7 = 4;
            while (i <= self.state.rule_fifty) : (i += 2) {
                s2 = s2.previous.previous;
                if (s2.material_key == self.state.material_key) {
                    self.state.repetition = if (s2.repetition != 0) -i else i;
                    break;
                }
            }
        }
    }

    /// silent will not change self.state
    pub inline fn unMovePiece(self: *Position, move: Move, silent: bool) !void {
        const from: Square = move.getFrom();
        const to: Square = move.getTo();
        const to_piece: Piece = self.board[to.index()];

        // Remove/Add
        self.removeAdd(to_piece, to, from);

        if (!silent) {
            // Was a promotion
            if (move.isPromotion()) {
                // Before delete we store the data we need
                const is_white: Color = to_piece.pieceToColor();
                // Remove promoted piece back into pawn (already moved back)
                self.remove(to_piece, from);
                self.add(if (is_white) Piece.w_pawn else Piece.b_pawn, from);
                to_piece = self.board[from]; // update, may not be needed if we don't need later
            }

            if (self.state.last_captured_piece != Piece.none) {
                const local_to: Square = to;
                // Case where capture was en passant
                if (move.isEnPassant())
                    local_to = if (self.state.last_captured_piece.pieceToColor() == Color.white) to + 8 else to - 8;

                self.add(self.state.last_captured_piece, local_to);
            }

            self.state = self.state.previous;
        }

        // If castling we move the rook as well
        if (move.getFlags() == MoveFlags.oo) {
            unMovePiece(Move{ .from = from + 3, .to = from + 3 - 2 }, true);
        } else if (move.getFlags() == MoveFlags.ooo) {
            unMovePiece(Move{ .from = from - 4, .to = from - 4 + 3 }, true);
        }
    }

    pub fn generateLegalMoves(self: *Position, color: types.Color, list: *std.ArrayList(types.Move)) void {
        const us_bb = self.bb_colors[color.index()];
        const them_bb = self.bb_colors[color.invert().index()];
        const all_bb = us_bb | them_bb;

        // We first have to compute if is in check or double check
        // We then have to compute check blockers

        for (std.enums.values(PieceType)) |pt| {
            if (pt == PieceType.none)
                continue;

            var from_bb: Bitboard = self.bb_pieces[pt.index()] & us_bb;
            while (from_bb != 0) {
                const from: Square = types.popLsb(&from_bb);
                const to: Bitboard = tables.getAttacks(pt, from, all_bb);
                std.debug.print("{}\n", .{from});
                types.debugPrintBitboard(to);

                // Capture
                Move.generateMove(MoveFlags.capture, from, to & them_bb, list);

                // Quiet
                if (pt == PieceType.pawn) {
                    // Double push
                    if (self.board[from.add(Direction.north.relative_dir(color)).index()] == Piece.none) {
                        list.append(Move{ .flags = MoveFlags.quiet.index(), .from = @truncate(from.index()), .to = @truncate(from.add(Direction.north.relative_dir(color)).index()) }) catch unreachable;
                        if (from.rank() == Rank.r2.relative_rank(color) and self.board[from.add(Direction.north_north.relative_dir(color)).index()] == Piece.none) {
                            list.append(Move{ .flags = MoveFlags.double_push.index(), .from = @truncate(from.index()), .to = @truncate(from.add(Direction.north_north.relative_dir(color)).index()) }) catch unreachable;
                        }
                    }
                } else {
                    Move.generateMove(MoveFlags.quiet, from, to & ~all_bb, list);
                }
            }
        }
    }

    pub fn debugPrint(self: Position) void {
        const line = " +---+---+---+---+---+---+---+---+\n";
        const letters = "   A   B   C   D   E   F   G   H\n";
        var i: i32 = 56;
        while (i >= 0) : (i -= 8) {
            std.debug.print("{s} ", .{line});
            var j: i32 = 0;
            while (j < 8) : (j += 1) {
                std.debug.print("| {c} ", .{@intFromEnum(self.board[@intCast(i + j)])});
            }
            std.debug.print("| {}\n", .{@divTrunc(i, 8) + 1});
        }
        std.debug.print("{s}", .{line});
        std.debug.print("{s}\n", .{letters});

        std.debug.print("{s} to move\n", .{if (self.state.turn == Color.white) "White" else "Black"});

        // Size of buffer could be 90 but std.fmt.allocPrint and ArenaAllocator requires more
        var buffer: [300]u8 = undefined;
        var alloc = std.heap.FixedBufferAllocator.init(&buffer);
        var arena = std.heap.ArenaAllocator.init(alloc.allocator());
        defer arena.deinit();
        const allocator = arena.allocator();

        if (self.getFen(allocator)) |fen| {
            std.debug.print("fen: {s}\n", .{fen});
        } else |err| {
            std.debug.print("Error {s} reading fen\n", .{@errorName(err)});
        }
        std.debug.print("zobrist: {}\n", .{self.zobrist});
    }

    pub fn getFen(self: *const Position, allocator: std.mem.Allocator) ![]const u8 {
        var fen = std.ArrayList(u8).init(allocator);
        var i: i8 = Square.a8.index();
        while (i >= 0) : (i -= 8) {
            var blank_counter: u8 = 0;
            var j: i8 = 0;
            while (j < 8) : (j += 1) {
                const p: Piece = self.board[@intCast(i + j)];
                if (p == Piece.none) {
                    blank_counter += 1;
                } else {
                    if (blank_counter != 0) {
                        try fen.append('0' + blank_counter);
                        blank_counter = 0;
                    }
                    try fen.append(p.index());
                }
            }
            if (blank_counter != 0) {
                try fen.append('0' + blank_counter);
            }
            if (i - 8 >= 0) {
                try fen.append('/');
            }
        }
        try fen.append(' ');
        try fen.append(if (self.state.turn == Color.white) 'w' else 'b');
        try fen.append(' ');
        if ((self.state.castle_info.index() | CastleInfo.K.index()) > 0)
            try fen.append('K');
        if ((self.state.castle_info.index() | CastleInfo.Q.index()) > 0)
            try fen.append('Q');
        if ((self.state.castle_info.index() | CastleInfo.k.index()) > 0)
            try fen.append('k');
        if ((self.state.castle_info.index() | CastleInfo.q.index()) > 0)
            try fen.append('q');

        try fen.append(' ');
        if (self.state.en_passant == Square.none) {
            try fen.append('-');
        } else {
            try fen.appendSlice(self.state.en_passant.sqToStr());
        }

        try fen.append(' ');
        var buffer: [4]u8 = undefined;
        const buf = buffer[0..];
        try fen.appendSlice(std.fmt.bufPrintIntToSlice(buf, self.state.rule_fifty, 10, .lower, std.fmt.FormatOptions{}));

        return fen.items;
    }

    pub fn setFen(state: *State, fen: []const u8) Position {
        var pos: Position = Position.new(state);
        var sq: i32 = Square.a8.index();
        var tokens = std.mem.tokenizeScalar(u8, fen, ' ');
        const bd = tokens.next().?;
        for (bd) |ch| {
            if (std.ascii.isDigit(ch)) {
                sq += @as(i32, ch - '0') * Direction.east.index();
            } else if (ch == '/') {
                sq += Direction.south.index() * 2;
            } else {
                pos.add(Piece.first_index(ch).?, @enumFromInt(sq));
                sq += 1;
            }
        }

        const turn = tokens.next().?;
        if (std.mem.eql(u8, turn, "w")) {
            pos.state.turn = Color.white;
        } else {
            pos.state.turn = Color.black;
            // pos.hash ^= zobrist.TurnHash;
        }

        // pos.history[pos.game_ply].entry = types.AllCastlingMask;
        const castle = tokens.next().?;
        for (castle) |ch| {
            switch (ch) {
                'K' => {
                    pos.state.castle_info = @enumFromInt(@intFromEnum(pos.state.castle_info) | @intFromEnum(CastleInfo.K));
                },
                'Q' => {
                    pos.state.castle_info = @enumFromInt(@intFromEnum(pos.state.castle_info) | @intFromEnum(CastleInfo.Q));
                },
                'k' => {
                    pos.state.castle_info = @enumFromInt(@intFromEnum(pos.state.castle_info) | @intFromEnum(CastleInfo.k));
                },
                'q' => {
                    pos.state.castle_info = @enumFromInt(@intFromEnum(pos.state.castle_info) | @intFromEnum(CastleInfo.q));
                },
                else => {},
            }
        }

        const ep = tokens.next().?;
        if (ep.len == 2) {
            for (types.square_to_str, 0..) |sq_str, i| {
                if (std.mem.eql(u8, ep, sq_str)) {
                    pos.state.en_passant = @enumFromInt(i);
                    // self.hash ^= zobrist.EnPassantHash[types.file_plain(i)];
                    break;
                }
            }
        }
        return pos;
    }
};
