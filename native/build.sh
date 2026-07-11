#!/usr/bin/env sh
# Builds the vendored Box3D C library into a static archive that dub links.
# Invoked by dub via preBuildCommands. Safe to run repeatedly (incremental).
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$DIR/box3d"
BUILD="$SRC/build"
OUT="$DIR/libbox3d.a"

if ! command -v cmake >/dev/null 2>&1; then
    echo "box3d.d: cmake is required to build the vendored Box3D library." >&2
    echo "         Install cmake, or use the \"system\" configuration to link a system Box3D." >&2
    exit 1
fi

cmake -S "$SRC" -B "$BUILD" -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build "$BUILD" --config Release -j >/dev/null

# Copy to a stable path regardless of single/multi-config generator layout.
LIB="$(find "$BUILD" -name libbox3d.a -print 2>/dev/null | head -n 1)"
if [ -z "$LIB" ]; then
    echo "box3d.d: failed to locate built libbox3d.a under $BUILD" >&2
    exit 1
fi
cp "$LIB" "$OUT"
