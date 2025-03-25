#!/bin/bash
# ios_build.sh - Enhanced for Chess App

# Exit on error
set -e

# Set up environment
export SDK_PATH=$(xcrun -sdk iphoneos --show-sdk-path)
export MIN_IOS_VERSION="12.0"

echo "Building Fairy-Stockfish for iOS"
echo "SDK Path: $SDK_PATH"
echo "Minimum iOS Version: $MIN_IOS_VERSION"

# Clean any previous builds
rm -f *.o *.a *.dylib

# Create a list of all source files to compile
# SOURCE_FILES=(
#   position.cpp movegen.cpp bitboard.cpp misc.cpp material.cpp 
#   tt.cpp uci.cpp search.cpp evaluate.cpp timeman.cpp 
#   thread.cpp ucioption.cpp pawns.cpp endgame.cpp psqt.cpp 
#   variant.cpp piece.cpp parser.cpp xboard.cpp partner.cpp 
#   movepick.cpp benchmark.cpp syzygy/tbprobe.cpp
#   nnue/evaluate_nnue.cpp nnue/features/half_ka_v2.cpp nnue/features/half_ka_v2_variants.cpp
#   bitbase.cpp
# )
SOURCE_FILES=(benchmark.cpp bitbase.cpp bitboard.cpp endgame.cpp evaluate.cpp fairy_stockfish_api.cpp main.cpp material.cpp misc.cpp movegen.cpp movepick.cpp parser.cpp partner.cpp pawns.cpp piece.cpp position.cpp psqt.cpp search.cpp thread.cpp timeman.cpp tt.cpp tune.cpp uci.cpp ucioption.cpp variant.cpp xboard.cpp syzygy/tbprobe.cpp   nnue/evaluate_nnue.cpp nnue/features/half_ka_v2.cpp nnue/features/half_ka_v2_variants.cpp)

COMMON_FLAGS="-Wall -Wcast-qual -fno-exceptions -std=c++17 \
  -fPIC -DNO_FILESYSTEM_OPERATIONS -O3 -DNDEBUG \
  -DIS_64BIT -DUSE_PTHREADS -DUSE_POPCNT -DUSE_NEON \
  -DLARGEBOARDS -DPRECOMPUTED_MAGICS -DNNUE_EMBEDDING_OFF \
  -fvisibility=default -fvisibility-inlines-hidden"

# Compile each source file
OBJECT_FILES=()
for SRC in "${SOURCE_FILES[@]}"; do
  if [ -f "$SRC" ]; then
    echo "Compiling $SRC..."
    BASENAME=$(basename "$SRC" .cpp)
    OBJECT_FILE="${BASENAME}.o"
    xcrun -sdk iphoneos clang++ \
      $COMMON_FLAGS \
      -arch arm64 -isysroot $SDK_PATH -mios-version-min=$MIN_IOS_VERSION \
      -I. -Isyzygy -Innue -Innue/features \
      -c "$SRC" -o "$OBJECT_FILE"
    OBJECT_FILES+=("$OBJECT_FILE")
  else
    echo "Warning: Source file $SRC not found, skipping"
  fi
done

# Compile fairy_stockfish_api.cpp with same flags
echo "Compiling fairy_stockfish_api.cpp..."
xcrun -sdk iphoneos clang++ \
  $COMMON_FLAGS \
  -arch arm64 -isysroot $SDK_PATH -mios-version-min=$MIN_IOS_VERSION \
  -I. -Isyzygy -Innue -Innue/features \
  -c fairy_stockfish_api.cpp -o fairy_stockfish_api.o


OBJECT_FILES+=("fairy_stockfish_api.o")

# Create static library with explicit list of object files
echo "Creating static library..."
xcrun -sdk iphoneos libtool -static \
  -arch_only arm64 \
  "${OBJECT_FILES[@]}" -o libfairystockfish.a

# Check for resource directory and create if not exists
RESOURCE_DIR="src/chessapp/resources"
mkdir -p "$RESOURCE_DIR"

# Copy to resources directory
cp libfairystockfish.a "$RESOURCE_DIR/"
echo "Library copied to $RESOURCE_DIR/"

echo "Build complete! The library is ready for use in your iOS app."