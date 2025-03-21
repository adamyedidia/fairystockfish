#!/bin/bash
# ios_build.sh

# Set up environment
export SDK_PATH=$(xcrun -sdk iphoneos --show-sdk-path)
export MIN_IOS_VERSION="12.0"

# Clean any previous builds
rm -f *.o *.a *.dylib

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

# Also compile the C API wrapper
cat > fairy_stockfish_api.cpp << 'EOL'
#include "fairy_stockfish_api.h"
#include <string>
#include <iostream>
#include <sstream>
#include <thread>
#include <mutex>
#include <condition_variable>

// Global variables
static std::string lastBestMove = "e2e4"; // Default move
static std::mutex mtx;
static std::condition_variable cv;
static bool ready = false;

// Initialize the engine
void fs_init(void) {
    // In a real implementation, initialize the Stockfish engine
    std::unique_lock<std::mutex> lock(mtx);
    ready = true;
    cv.notify_one();
}

// Set UCI options
void fs_set_option(const char* name, const char* value) {
    // In a real implementation, set UCI options
}

// Set position from FEN string
void fs_set_position(const char* fen) {
    // In a real implementation, set position
}

// Get best move with given time in milliseconds
const char* fs_get_best_move(int time_ms) {
    // In a real implementation, get best move
    std::unique_lock<std::mutex> lock(mtx);
    ready = true;
    cv.notify_one();
    return lastBestMove.c_str();
}

// Clean up
void fs_quit(void) {
    // In a real implementation, clean up resources
}
EOL

cat > fairy_stockfish_api.h << 'EOL'
#ifndef FAIRY_STOCKFISH_API_H
#define FAIRY_STOCKFISH_API_H

#ifdef __cplusplus
extern "C" {
#endif

// Initialize the engine
void fs_init(void);

// Set UCI options (time, etc)
void fs_set_option(const char* name, const char* value);

// Set position from FEN string
void fs_set_position(const char* fen);

// Get best move with given time in milliseconds
const char* fs_get_best_move(int time_ms);

// Clean up resources
void fs_quit(void);

#ifdef __cplusplus
}
#endif

#endif /* FAIRY_STOCKFISH_API_H */
EOL

# Compile the API wrapper
xcrun -sdk iphoneos clang++ \
  -Wall -Wcast-qual -fno-exceptions -std=c++17 \
  -fPIC -O3 -DNDEBUG \
  -arch arm64 -isysroot $SDK_PATH -mios-version-min=$MIN_IOS_VERSION \
  -c fairy_stockfish_api.cpp -o fairy_stockfish_api.o

# Create a dynamic library
xcrun -sdk iphoneos clang++ \
  -arch arm64 -isysroot $SDK_PATH -mios-version-min=$MIN_IOS_VERSION \
  -dynamiclib -install_name @rpath/libfairystockfish.dylib \
  fairy_stockfish_api.o -o libfairystockfish.dylib

# If the build is successful, show the location
if [ -f "libfairystockfish.dylib" ] && [ -s "libfairystockfish.dylib" ]; then
  echo "Build successful! Dynamic library created at: $(pwd)/libfairystockfish.dylib"
  echo "Library size: $(du -h libfairystockfish.dylib | cut -f1)"
else
  echo "Build failed or empty library created."
fi