#!/usr/bin/env bash
# Builds the Azahar core and the Azurion bridge into build/AzurionCore.xcframework.
#
# Usage: scripts/build-core.sh [device|simulator|all]   (default: all)
# Env:   CONFIG=Release|Debug                           (default: Release)
#
# Re-run after changing anything in Bridge/ or external/azahar. Builds are incremental.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AZAHAR="$ROOT/external/azahar"
BUILD="$ROOT/build"
CONFIG="${CONFIG:-Release}"
SLICES="${1:-all}"

# Same MoltenVK release Azahar's CMake downloads, fetched once for both slices.
MOLTENVK_VERSION="v1.4.1"
MOLTENVK_DIR="$BUILD/deps/MoltenVK"

fetch_moltenvk() {
    if [[ -d "$MOLTENVK_DIR" ]]; then
        return
    fi
    echo "==> Downloading MoltenVK $MOLTENVK_VERSION"
    mkdir -p "$BUILD/deps"
    curl -fL --retry 3 -o "$BUILD/deps/MoltenVK.tar" \
        "https://github.com/KhronosGroup/MoltenVK/releases/download/$MOLTENVK_VERSION/MoltenVK-all.tar"
    tar -xf "$BUILD/deps/MoltenVK.tar" -C "$BUILD/deps"
    rm "$BUILD/deps/MoltenVK.tar"
}

# $1: slice name, $2: SDK, $3: glob matching the MoltenVK xcframework slice
build_slice() {
    local slice="$1" sdk="$2" moltenvk_slice="$3"
    local dir="$BUILD/core-$slice"
    local moltenvk_lib
    moltenvk_lib="$(ls -d "$MOLTENVK_DIR"/MoltenVK/static/MoltenVK.xcframework/$moltenvk_slice/libMoltenVK.a | head -n 1)"

    echo "==> Configuring $slice ($CONFIG)"
    cmake -S "$AZAHAR" -B "$dir" -G Ninja \
        -DCMAKE_BUILD_TYPE="$CONFIG" \
        -DCMAKE_SYSTEM_NAME=iOS \
        -DCMAKE_OSX_SYSROOT="$sdk" \
        -DCMAKE_OSX_ARCHITECTURES=arm64 \
        -DAZURION_BRIDGE_DIR="$ROOT/Bridge" \
        -DENABLE_QT=OFF \
        -DENABLE_SDL2=OFF \
        -DENABLE_WEB_SERVICE=OFF \
        -DENABLE_SCRIPTING=OFF \
        -DENABLE_GDBSTUB=OFF \
        -DENABLE_DISCORD_RPC=OFF \
        -DENABLE_BUILTIN_KEYBLOB=OFF \
        -DCITRA_WARNINGS_AS_ERRORS=OFF \
        -DUSE_SYSTEM_MOLTENVK=ON \
        -DMOLTENVK_LIBRARY="$moltenvk_lib"

    echo "==> Building $slice"
    cmake --build "$dir" --target AzurionCore
}

fetch_moltenvk

frameworks=()
build_device() {
    build_slice device iphoneos 'ios-arm64'
    frameworks+=(-framework "$BUILD/core-device/azurion/AzurionCore.framework")
}
build_simulator() {
    build_slice simulator iphonesimulator 'ios-*-simulator'
    frameworks+=(-framework "$BUILD/core-simulator/azurion/AzurionCore.framework")
}

case "$SLICES" in
    device) build_device ;;
    simulator) build_simulator ;;
    all)
        build_device
        build_simulator
        ;;
    *)
        echo "usage: $0 [device|simulator|all]" >&2
        exit 1
        ;;
esac

echo "==> Packaging AzurionCore.xcframework"
rm -rf "$BUILD/AzurionCore.xcframework"
xcodebuild -create-xcframework "${frameworks[@]}" -output "$BUILD/AzurionCore.xcframework"
echo "Done: $BUILD/AzurionCore.xcframework"
