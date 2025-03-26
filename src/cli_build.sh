#!/bin/bash
# build_cli.sh - Build Fairy-Stockfish for command line

# Exit on error
set -e

# Clean any previous builds
rm -f *.o stockfish

# Create a list of source files (same as before)
SOURCE_FILES=(benchmark.cpp bitbase.cpp bitboard.cpp endgame.cpp evaluate.cpp \
    fairy_stockfish_api.cpp main.cpp material.cpp misc.cpp movegen.cpp movepick.cpp \
    parser.cpp partner.cpp pawns.cpp piece.cpp position.cpp psqt.cpp search.cpp \
    thread.cpp timeman.cpp tt.cpp tune.cpp uci.cpp ucioption.cpp variant.cpp \
    xboard.cpp syzygy/tbprobe.cpp nnue/evaluate_nnue.cpp \
    nnue/features/half_ka_v2.cpp nnue/features/half_ka_v2_variants.cpp)

# Compiler flags for command line build
COMMON_FLAGS="-Wall -Wcast-qual -fno-exceptions -std=c++17 \
  -O3 -DNDEBUG -DIS_64BIT -DUSE_PTHREADS \
  -DLARGEBOARDS -DPRECOMPUTED_MAGICS -DNNUE_EMBEDDING_OFF"

# Compile each source file
OBJECT_FILES=()
for SRC in "${SOURCE_FILES[@]}"; do
    if [ -f "$SRC" ]; then
        echo "Compiling $SRC..."
        BASENAME=$(basename "$SRC" .cpp)
        OBJECT_FILE="${BASENAME}.o"
        clang++ $COMMON_FLAGS -I. -Isyzygy -Innue -Innue/features -c "$SRC" -o "$OBJECT_FILE"
        OBJECT_FILES+=("$OBJECT_FILE")
    else
        echo "Warning: Source file $SRC not found, skipping"
    fi
done

# Link into executable
echo "Creating executable..."
clang++ "${OBJECT_FILES[@]}" -o stockfish -pthread

echo "Build complete! Run with ./stockfish"