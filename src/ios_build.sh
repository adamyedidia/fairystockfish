#!/bin/bash
# ios_build.sh

# Set up environment
export SDK_PATH=$(xcrun -sdk iphoneos --show-sdk-path)
export MIN_IOS_VERSION="12.0"

# Clean any previous builds
rm -f *.o *.a

# Compile each source file directly
for SRC in *.cpp syzygy/*.cpp nnue/*.cpp nnue/features/*.cpp; do
  if [ -f "$SRC" ]; then
    echo "Compiling $SRC..."
    xcrun -sdk iphoneos clang++ \
      -Wall -Wcast-qual -fno-exceptions -std=c++17 \
      -fPIC -DNO_FILESYSTEM_OPERATIONS -O3 -DNDEBUG \
      -DIS_64BIT -DUSE_PTHREADS -DUSE_POPCNT -DUSE_NEON \
      -DLARGEBOARDS -DPRECOMPUTED_MAGICS -DNNUE_EMBEDDING_OFF \
      -arch arm64 -isysroot $SDK_PATH -mios-version-min=$MIN_IOS_VERSION \
      -I. -Isyzygy -Innue -Innue/features \
      -c "$SRC" -o "$(basename "$SRC" .cpp).o"
  fi
done

# Create static library
xcrun -sdk iphoneos ar rcs libfairystockfish.a *.o

# If the build is successful, show the location
if [ -f "libfairystockfish.a" ] && [ -s "libfairystockfish.a" ]; then
  echo "Build successful! Static library created at: $(pwd)/libfairystockfish.a"
  echo "Library size: $(du -h libfairystockfish.a | cut -f1)"
else
  echo "Build failed or empty library created."
fi