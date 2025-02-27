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

    pub inline fn relativeCastle(self: CastleInfo, c: Color) CastleInfo {
        return if (c == Color.white) self else @enumFromInt(self.index() >> 2);
    }
};

pub const State = packed struct {
    turn: Color = Color.white,
    castle_info: CastleInfo = CastleInfo.none,
    repetition: i7 = 0, // Zero if no repetition, x positive if happened once x half moves ago, negative indicates repetition
    rule_fifty: u6 = 0,
    game_ply: u32 = 1,
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

    // Stores the enemy pieces that are attacking the king and pinned pieces
    checkers: Bitboard = 0,
    pinned: Bitboard = 0,

    // Rook initial positions are recorded for 960
    rook_initial: [2]Square = [_]Square{ Square.a1, Square.h1 },

    // Zobrist Hash
    zobrist: u64 = 0,

    state: *State = undefined,

    pub fn new(state: *State) Position {
        state.* = State{};
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

    pub fn movePiece(self: *Position, move: Move, state: *State) !void {
        // Reset data and set as previous
        state.turn = self.state.turn;
        state.castle_info = self.state.castle_info;
        // Increment ply counters. In particular, rule_fifty will be reset to zero later on in case of a capture or a pawn move.
        state.rule_fifty = self.state.rule_fifty + 1;
        state.game_ply = self.state.game_ply;
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

        // Remove last en_passant
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
                    if (self.state.castle_info.index() & (if (is_white) CastleInfo.K else CastleInfo.k).index() > 0) {
                        self.state.castle_info = @enumFromInt(self.state.castle_info.index() & ~(if (is_white) CastleInfo.K.index() else CastleInfo.k.index()));
                        // self.state.material_key ^= ~Zobrist.caslting[if (is_white) CastleInfo.K else CastleInfo.k) > 0];
                    }
                } else if (move.getFrom().file() == File.fa) {
                    if (self.state.castle_info.index() & (if (is_white) CastleInfo.Q else CastleInfo.q).index() > 0) {
                        self.state.castle_info = @enumFromInt(self.state.castle_info.index() & ~(if (is_white) CastleInfo.Q.index() else CastleInfo.q.index()));
                        // self.state.material_key ^= ~Zobrist.caslting[if (is_white) CastleInfo.Q else CastleInfo.q) > 0];
                    }
                }
            },
            PieceType.pawn => {
                // Updates en_passant if possible next turn
                switch (move.getFlags()) {
                    MoveFlags.double_push => {
                        self.state.en_passant = to.add(if (self.state.turn == Color.white) Direction.south else Direction.north);
                    },
                    MoveFlags.en_passant => {
                        const en_passant_sq: Square = to.add(if (self.state.turn == Color.white) Direction.south else Direction.north);
                        self.state.last_captured_piece = self.board[en_passant_sq.index()];

                        // Remove
                        self.remove(self.state.last_captured_piece, en_passant_sq);
                        // self.state.material_key ^= Zobrist.psq[self.state.last_captured_piece.pieceToPieceType()][en_passant_sq.index()];

                        self.board[en_passant_sq.index()] = Piece.none;
                    },
                    else => {},
                }
                // Reset rule 50 counter
                self.state.rule_fifty = 0;
            },
            else => {},
        }

        if (move.isEnPassant()) {
            const to_piece_en_passant: Piece = if (self.state.turn.isWhite()) types.Piece.b_pawn else types.Piece.w_pawn;
            self.state.last_captured_piece = to_piece_en_passant;

            // Remove captured
            self.remove(to_piece_en_passant, move.getTo().add(types.Direction.south.relativeDir(self.state.turn)));

            // Reset rule 50 counter
            self.state.rule_fifty = 0;
        } else if (move.isCapture()) {
            if (to_piece == Piece.none) {
                return error.CaptureNone;
            } else {
                // This should be the quickest to disable castle when rook is taken
                var castleRemove: CastleInfo = CastleInfo.none;

                if (to == self.rook_initial[0]) {
                    castleRemove = CastleInfo.K;
                } else if (to == self.rook_initial[1]) {
                    castleRemove = CastleInfo.Q;
                } else if (to == self.rook_initial[0].relativeSquare(Color.black)) {
                    castleRemove = CastleInfo.k;
                } else if (to == self.rook_initial[1].relativeSquare(Color.black)) {
                    castleRemove = CastleInfo.q;
                }

                if (CastleInfo.none != CastleInfo.none and (self.state.castle_info.index() | castleRemove.index())) {
                    self.state.castle_info &= ~castleRemove;
                    // self.state.material_key ^= ~Zobrist.caslting[castleRemove.indexLsb()];
                }

                self.state.last_captured_piece = to_piece;

                // Remove captured
                self.remove(to_piece, move.getTo());

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
                // CHESS 960 BUG
                if (self.movePiece(Move{ .flags = 0, .from = @truncate(from.index() + 3), .to = @truncate(from.index() + 3 - 2) }, &tmp)) {} else |err| {
                    return err;
                }
                // We have moved, we need to set the turn back
                self.state = state;
            },
            MoveFlags.ooo => {
                var tmp: State = State{};
                // CHESS 960 BUG
                if (self.movePiece(Move{ .flags = 0, .from = @truncate(from.index() - 4), .to = @truncate(from.index() - 4 + 3) }, &tmp)) {} else |err| {
                    return err;
                }
                // We have moved, we need to set the turn back
                self.state = state;
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
    pub fn unMovePiece(self: *Position, move: Move, silent: bool) !void {
        const from: Square = move.getFrom();
        const to: Square = move.getTo();
        const to_piece: Piece = self.board[to.index()];

        // Remove/Add
        self.removeAdd(to_piece, to, from);

        if (!silent) {
            // Was a promotion
            if (move.isPromotion()) {
                // Before delete we store the data we need
                const is_white: bool = to_piece.pieceToColor() == Color.white;
                // Remove promoted piece back into pawn (already moved back)
                self.remove(to_piece, from);
                self.add(if (is_white) Piece.w_pawn else Piece.b_pawn, from);
                // to_piece = self.board[from.index()]; // update, may not be needed if we don't need later
            }

            if (self.state.last_captured_piece != Piece.none) {
                var local_to: Square = to;
                // Case where capture was en passant
                if (move.isEnPassant())
                    local_to = if (self.state.last_captured_piece.pieceToColor() == Color.white) to.add(Direction.north) else to.add(Direction.south);

                self.add(self.state.last_captured_piece, local_to);
            }

            self.state = self.state.previous;
        }

        // If castling we move the rook as well
        if (move.getFlags() == MoveFlags.oo) {
            if (self.unMovePiece(Move{ .from = @truncate(from.index() + 3), .to = @truncate(from.index() + 3 - 2) }, true)) {} else |err| {
                return err;
            }
        } else if (move.getFlags() == MoveFlags.ooo) {
            if (self.unMovePiece(Move{ .from = @truncate(from.index() - 4), .to = @truncate(from.index() - 4 + 3) }, true)) {} else |err| {
                return err;
            }
        }
    }

    pub fn generateLegalMoves(self: *Position, color: types.Color, list: *std.ArrayList(types.Move)) void {
        const us_bb: Bitboard = self.bb_colors[color.index()];
        const them_bb: Bitboard = self.bb_colors[color.invert().index()];
        const all_bb: Bitboard = us_bb | them_bb;

        const our_king: Square = @enumFromInt(types.lsb(us_bb & self.bb_pieces[PieceType.king.index()]));

        var attacked: Bitboard = 0;
        for (std.enums.values(PieceType)) |pt| {
            if (pt == PieceType.none)
                continue;
            var from_bb: Bitboard = self.bb_pieces[pt.index()] & them_bb;
            while (from_bb != 0) {
                const from: Square = types.popLsb(&from_bb);
                attacked |= tables.getAttacks(pt, color.invert(), from, all_bb) & ~them_bb;
            }
        }

        // Compute checkers from non blockables piece types
        // All knights can attack the king the same way a knight would attack form the king's square
        self.checkers = tables.getAttacks(PieceType.knight, color.invert(), our_king, 0) & them_bb & self.bb_pieces[PieceType.knight.index()];
        // Same method for pawn, transform the king into a pawn
        self.checkers |= tables.pawn_attacks[color.index()][our_king.index()] & them_bb & self.bb_pieces[PieceType.pawn.index()];

        // Compute candidate checkers from sliders and pinned pieces, transform the king into a slider
        var candidates: types.Bitboard = tables.getAttacks(types.PieceType.bishop, Color.white, our_king, them_bb) & ((self.bb_pieces[PieceType.bishop.index()] | self.bb_pieces[PieceType.queen.index()]) & self.bb_colors[color.invert().index()]);
        candidates |= tables.getAttacks(types.PieceType.rook, Color.white, our_king, them_bb) & ((self.bb_pieces[PieceType.rook.index()] | self.bb_pieces[PieceType.queen.index()]) & self.bb_colors[color.invert().index()]);

        self.pinned = 0;
        while (candidates != 0) {
            const sq: Square = types.popLsb(&candidates);
            const bb_between: Bitboard = tables.squares_between[our_king.index()][sq.index()] & us_bb;

            if (bb_between == 0) {
                // No our piece between king and slider: check
                self.checkers ^= sq.sqToBB();
            } else if ((bb_between & (bb_between - 1)) == 0) {
                // Only one of our piece between king and slider: pinned
                self.pinned ^= bb_between;
            }
        }

        switch (types.popcount(self.checkers)) {
            // Double check, move king
            2 => {
                const to: Bitboard = tables.getAttacks(PieceType.king, color, our_king, all_bb) & ~attacked;
                Move.generateMove(MoveFlags.quiet, our_king, to & ~all_bb, list);
                Move.generateMove(MoveFlags.capture, our_king, to & them_bb, list);
            },
            // SingleCheck
            1 => {},
            // No check
            else => {
                for (std.enums.values(PieceType)) |pt| {
                    if (pt == PieceType.none)
                        continue;

                    var from_bb: Bitboard = self.bb_pieces[pt.index()] & us_bb;

                    // Deal with pinned pawns first and remove them
                    if (pt == PieceType.pawn) {
                        var pinned_pawns: Bitboard = us_bb & self.bb_pieces[PieceType.pawn.index()] & self.pinned;
                        from_bb &= ~pinned_pawns;
                        while (pinned_pawns != 0) {
                            const from: Square = types.popLsb(&pinned_pawns);
                            // If a pawn is aligned with the king, he can only be aligned in a certain direction
                            const pawn_forward: Square = from.add(Direction.north.relativeDir(color));
                            const line: Bitboard = tables.squares_line[from.index()][our_king.index()];
                            if (self.board[pawn_forward.index()] == Piece.none and (line & pawn_forward.sqToBB()) > 0) {
                                list.append(Move{ .flags = MoveFlags.quiet.index(), .from = @truncate(from.index()), .to = @truncate(from.add(Direction.north.relativeDir(color)).index()) }) catch unreachable;
                                // Double push
                                if (from.rank() == Rank.r2.relativeRank(color) and self.board[from.add(Direction.north_north.relativeDir(color)).index()] == Piece.none) {
                                    list.append(Move{ .flags = MoveFlags.double_push.index(), .from = @truncate(from.index()), .to = @truncate(from.add(Direction.north_north.relativeDir(color)).index()) }) catch unreachable;
                                }
                            } else if (line != 0) {
                                const to: Bitboard = tables.getAttacks(pt, color, from, all_bb); // Careful: us_bb not excluded
                                Move.generateMove(MoveFlags.capture, from, to & line & them_bb, list);
                            } else if (self.state.en_passant != Square.none) {
                                // todo 3k4/q7/8/1pP5/3K4/8/8/8 w - b6 0 2
                            }
                        }
                        // En passant
                        // Pawn that can take are from the north.relativeDir() of en_passant square
                        if (self.state.en_passant != Square.none) {
                            const from_en_passant: Bitboard = tables.pawn_attacks[color.invert().index()][self.state.en_passant.index()];
                            types.debugPrintBitboard(from_en_passant);
                            Move.generateMoveFrom(MoveFlags.en_passant, from_en_passant & us_bb & from_bb, self.state.en_passant, list);
                        }
                    }

                    while (from_bb != 0) {
                        const from: Square = types.popLsb(&from_bb);
                        var to: Bitboard = tables.getAttacks(pt, color, from, all_bb); // Careful: us_bb not excluded

                        // Could be optimized
                        if ((from.sqToBB() & self.pinned) > 0) {
                            to &= tables.squares_line[our_king.index()][from.index()];
                        }

                        if (pt == types.PieceType.king) {
                            to &= ~attacked;
                        }

                        // Capture
                        Move.generateMove(MoveFlags.capture, from, to & them_bb, list);

                        // Quiet
                        if (pt == PieceType.pawn) {
                            // Push
                            if (self.board[from.add(Direction.north.relativeDir(color)).index()] == Piece.none) {
                                list.append(Move{ .flags = MoveFlags.quiet.index(), .from = @truncate(from.index()), .to = @truncate(from.add(Direction.north.relativeDir(color)).index()) }) catch unreachable;
                                // Double push
                                if (from.rank() == Rank.r2.relativeRank(color) and self.board[from.add(Direction.north_north.relativeDir(color)).index()] == Piece.none) {
                                    list.append(Move{ .flags = MoveFlags.double_push.index(), .from = @truncate(from.index()), .to = @truncate(from.add(Direction.north_north.relativeDir(color)).index()) }) catch unreachable;
                                }
                            }
                        } else {
                            Move.generateMove(MoveFlags.quiet, from, to & ~all_bb, list);
                        }
                    }
                }
                // Castling
                // TODO ADD CASTLING TEST FOR 960
                // Simplified code flow since we know our_king
                // OO
                if ((self.state.castle_info.index() & CastleInfo.K.relativeCastle(color).index()) > 0) {
                    const to_king_oo: Square = Square.g1.relativeSquare(color);
                    const path_oo: Bitboard = tables.squares_between[our_king.index()][to_king_oo.index()] | to_king_oo.sqToBB();
                    if ((path_oo & (all_bb & ~self.rook_initial[1].sqToBB() & ~our_king.sqToBB()) == 0) and (path_oo & attacked) == 0) {
                        list.append(Move{ .flags = MoveFlags.oo.index(), .from = @truncate(our_king.index()), .to = @truncate(to_king_oo.index()) }) catch unreachable;
                    }
                }
                // OOO
                if ((self.state.castle_info.index() & CastleInfo.Q.relativeCastle(color).index()) > 0) {
                    const to_king_ooo: Square = Square.c1.relativeSquare(color);
                    const path_ooo: Bitboard = tables.squares_between[our_king.index()][to_king_ooo.index()] | to_king_ooo.sqToBB();
                    if ((path_ooo & (all_bb & ~self.rook_initial[0].sqToBB() & ~our_king.sqToBB()) == 0) and (path_ooo & attacked) == 0) {
                        list.append(Move{ .flags = MoveFlags.oo.index(), .from = @truncate(our_king.index()), .to = @truncate(to_king_ooo.index()) }) catch unreachable;
                    }
                }
            },
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

        var buffer: [90]u8 = undefined;
        const fen = self.getFen(&buffer);

        std.debug.print("fen: {s}\n", .{fen});

        std.debug.print("zobrist: {}\n", .{self.zobrist});
    }

    pub fn getFen(self: *const Position, fen: []u8) []u8 {
        std.debug.assert(fen.len >= 90);
        var i: i8 = Square.a8.index();
        var cnt: usize = 0;
        while (i >= 0) : (i -= 8) {
            var blank_counter: u8 = 0;
            var j: i8 = 0;
            while (j < 8) : (j += 1) {
                const p: Piece = self.board[@intCast(i + j)];
                if (p == Piece.none) {
                    blank_counter += 1;
                } else {
                    if (blank_counter != 0) {
                        fen[cnt] = '0' + blank_counter;
                        cnt += 1;
                        blank_counter = 0;
                    }
                    fen[cnt] = p.index();
                    cnt += 1;
                }
            }
            if (blank_counter != 0) {
                fen[cnt] = '0' + blank_counter;
                cnt += 1;
            }
            if (i - 8 >= 0) {
                fen[cnt] = '/';
                cnt += 1;
            }
        }
        fen[cnt] = ' ';
        cnt += 1;
        fen[cnt] = if (self.state.turn == Color.white) 'w' else 'b';
        cnt += 1;
        fen[cnt] = ' ';
        cnt += 1;
        if (self.state.castle_info == CastleInfo.none) {
            fen[cnt] = '-';
            cnt += 1;
        } else {
            if ((self.state.castle_info.index() & CastleInfo.K.index()) > 0) {
                fen[cnt] = 'K';
                cnt += 1;
            }
            if ((self.state.castle_info.index() & CastleInfo.Q.index()) > 0) {
                fen[cnt] = 'Q';
                cnt += 1;
            }
            if ((self.state.castle_info.index() & CastleInfo.k.index()) > 0) {
                fen[cnt] = 'k';
                cnt += 1;
            }
            if ((self.state.castle_info.index() & CastleInfo.q.index()) > 0) {
                fen[cnt] = 'q';
                cnt += 1;
            }
        }

        fen[cnt] = ' ';
        cnt += 1;
        if (self.state.en_passant == Square.none) {
            fen[cnt] = '-';
            cnt += 1;
        } else {
            const tmp_str = self.state.en_passant.sqToStr();
            for (tmp_str) |c| {
                fen[cnt] = c;
                cnt += 1;
            }
        }

        fen[cnt] = ' ';
        cnt += 1;
        var buffer: [4]u8 = undefined;
        var buf = buffer[0..];
        var tmp_str = std.fmt.bufPrintIntToSlice(buf, self.state.rule_fifty, 10, .lower, std.fmt.FormatOptions{});

        // std.mem.copyBackwards(u8, fen[cnt..(cnt + tmp_str.len)], tmp_str);
        @memcpy(fen[cnt..(cnt + tmp_str.len)], tmp_str);
        cnt += tmp_str.len;

        fen[cnt] = ' ';
        cnt += 1;
        buffer = undefined;
        buf = buffer[0..];
        tmp_str = std.fmt.bufPrintIntToSlice(buf, self.state.game_ply, 10, .lower, std.fmt.FormatOptions{});

        std.mem.copyForwards(u8, fen[cnt..(cnt + tmp_str.len)], tmp_str);
        @memcpy(fen[cnt..(cnt + tmp_str.len)], tmp_str);
        cnt += tmp_str.len;

        // for (tmp_str) |c| {
        //     fen[cnt] = c;
        //     cnt += 1;
        // }

        return fen[0..cnt];
    }

    // Maybe sq should be a square and use sq.add()
    pub fn setFen(state: *State, fen: []const u8) Position {
        state.* = State{};
        var pos: Position = Position.new(state);
        var sq: i32 = Square.a8.index();
        var tokens = std.mem.tokenizeScalar(u8, fen, ' ');
        const bd = tokens.next().?;
        var rook_cnt: u8 = 0;
        for (bd) |ch| {
            if (std.ascii.isDigit(ch)) {
                sq += @as(i32, ch - '0') * Direction.east.index();
            } else if (ch == '/') {
                sq += Direction.south.index() * 2;
            } else {
                const p: Piece = Piece.first_index(ch).?;
                pos.add(p, @enumFromInt(sq));
                if (ch == 'R' and rook_cnt < 2) {
                    pos.rook_initial[rook_cnt] = @enumFromInt(sq);
                    rook_cnt += 1;
                }
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
