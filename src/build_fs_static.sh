#!/bin/bash
# build_fs_static.sh - Build and prepare Fairy-Stockfish for iOS
set -e

echo "Building Fairy-Stockfish static library for iOS"

# Set up environment
export SDK_PATH=$(xcrun -sdk iphoneos --show-sdk-path)
export MIN_IOS_VERSION="12.0"

# Compile each source file (simplified for example)
xcrun -sdk iphoneos clang++ \
  -Wall -std=c++17 -fno-exceptions \
  -DNO_FILESYSTEM_OPERATIONS -O3 -DNDEBUG \
  -arch arm64 -isysroot $SDK_PATH -mios-version-min=$MIN_IOS_VERSION \
  -c fairy_stockfish_api.cpp -o fairy_stockfish_api.o

# Create static library
xcrun -sdk iphoneos ar rcs fairystockfish.a fairy_stockfish_api.o

# Copy to project directory
mkdir -p ../src/chessapp/
cp fairystockfish.a fairy_stockfish_api.h ../src/chessapp/