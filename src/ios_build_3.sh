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

# Create dynamic library with explicit list of object files
echo "Creating dynamic library..."
xcrun -sdk iphoneos clang++ \
  -arch arm64 -isysroot $SDK_PATH -mios-version-min=$MIN_IOS_VERSION \
  -dynamiclib -install_name @rpath/libfairystockfish.dylib \
  "${OBJECT_FILES[@]}" -o libfairystockfish.dylib

# Create entitlements file for iOS
cat > fairystockfish.entitlements << 'EOL'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.device.audio-input</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
EOL

# Set the correct ID
xcrun -sdk iphoneos install_name_tool -id @rpath/libfairystockfish.dylib libfairystockfish.dylib

# Get developer identity for signing
IDENTITY=$(security find-identity -v -p codesigning | grep "Apple Development" | head -n 1 | awk -F '"' '{print $2}')

if [ -z "$IDENTITY" ]; then
    echo "No Apple Development identity found. Trying Apple Distribution identity..."
    IDENTITY=$(security find-identity -v -p codesigning | grep "Apple Distribution" | head -n 1 | awk -F '"' '{print $2}')
fi

# Fallback to ad-hoc if no identity found
if [ -z "$IDENTITY" ]; then
    echo "No suitable code signing identity found. Using ad-hoc signing."
    SIGNING_IDENTITY="-"
else
    echo "Using code signing identity: $IDENTITY"
    SIGNING_IDENTITY="$IDENTITY"
fi

# Sign the library
echo "Signing the library for iOS..."
xcrun -sdk iphoneos codesign --force --sign "$SIGNING_IDENTITY" --entitlements fairystockfish.entitlements --timestamp libfairystockfish.dylib

# Verify signing and check if valid for App Store
xcrun -sdk iphoneos codesign -vv -d libfairystockfish.dylib

# Check for resource directory and create if not exists
RESOURCE_DIR="src/chessapp/resources"
mkdir -p "$RESOURCE_DIR"

# Copy to resources directory
cp libfairystockfish.dylib "$RESOURCE_DIR/"
echo "Library copied to $RESOURCE_DIR/"

# Show library info
echo "Showing library details:"
xcrun -sdk iphoneos otool -L libfairystockfish.dylib

echo "Build complete! The library is ready for use in your iOS app."