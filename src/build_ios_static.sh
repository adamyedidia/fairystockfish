#!/bin/bash
# build_ios_static.sh - Build a static library for iOS
set -e

echo "Building fairystockfish.a static library for iOS"

# Set up environment
export SDK_PATH=$(xcrun -sdk iphoneos --show-sdk-path)
export MIN_IOS_VERSION="12.0"

# Display build environment
echo "Using SDK path: $SDK_PATH"
echo "Min iOS version: $MIN_IOS_VERSION"

# Clean any previous builds
rm -f *.o fairystockfish.a

# Create a list of all source files to compile
SOURCE_FILES=(
  position.cpp movegen.cpp bitboard.cpp misc.cpp material.cpp 
  tt.cpp uci.cpp search.cpp evaluate.cpp timeman.cpp 
  thread.cpp ucioption.cpp pawns.cpp endgame.cpp psqt.cpp 
  variant.cpp piece.cpp parser.cpp xboard.cpp partner.cpp 
  movepick.cpp benchmark.cpp syzygy/tbprobe.cpp
  nnue/evaluate_nnue.cpp nnue/features/half_ka_v2.cpp nnue/features/half_ka_v2_variants.cpp
  bitbase.cpp
)

# Compile each source file
OBJECT_FILES=()
for SRC in "${SOURCE_FILES[@]}"; do
  if [ -f "$SRC" ]; then
    echo "Compiling $SRC..."
    BASENAME=$(basename "$SRC" .cpp)
    OBJECT_FILE="${BASENAME}.o"
    xcrun -sdk iphoneos clang++ \
      -Wall -Wcast-qual -fno-exceptions -std=c++17 \
      -fPIC -DNO_FILESYSTEM_OPERATIONS -O3 -DNDEBUG \
      -DIS_64BIT -DUSE_PTHREADS -DUSE_POPCNT -DUSE_NEON \
      -DLARGEBOARDS -DPRECOMPUTED_MAGICS -DNNUE_EMBEDDING_OFF \
      -arch arm64 -isysroot $SDK_PATH -mios-version-min=$MIN_IOS_VERSION \
      -I. -Isyzygy -Innue -Innue/features \
      -c "$SRC" -o "$OBJECT_FILE"
    OBJECT_FILES+=("$OBJECT_FILE")
  else
    echo "Warning: Source file $SRC not found, skipping"
  fi
done

# Compile fairy_stockfish_api.cpp
echo "Compiling fairy_stockfish_api.cpp..."
xcrun -sdk iphoneos clang++ \
  -Wall -Wcast-qual -fno-exceptions -std=c++17 \
  -fPIC -DNO_FILESYSTEM_OPERATIONS -O3 -DNDEBUG \
  -DIS_64BIT -DUSE_PTHREADS -DUSE_POPCNT -DUSE_NEON \
  -DLARGEBOARDS -DPRECOMPUTED_MAGICS -DNNUE_EMBEDDING_OFF \
  -arch arm64 -isysroot $SDK_PATH -mios-version-min=$MIN_IOS_VERSION \
  -I. -Isyzygy -Innue -Innue/features \
  -c fairy_stockfish_api.cpp -o fairy_stockfish_api.o

OBJECT_FILES+=("fairy_stockfish_api.o")

# Create static library
echo "Creating static library..."
xcrun -sdk iphoneos ar rcs fairystockfish.a "${OBJECT_FILES[@]}"

# Verify the static library
echo "Verifying static library..."
xcrun -sdk iphoneos ar -t fairystockfish.a
echo "Static library size: $(du -h fairystockfish.a | cut -f1)"

# Create a directory for distribution
mkdir -p dist
cp fairystockfish.a dist/
cp fairy_stockfish_api.h dist/

echo "Static library created: fairystockfish.a"
echo "Files are ready in the dist/ directory"