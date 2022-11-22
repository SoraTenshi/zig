#!/bin/sh

# Requires cmake ninja-build

set -x
set -e

ARCH="$(uname -m)"
TARGET="$ARCH-linux-musl"
MCPU="baseline"
CACHE_BASENAME="zig+llvm+lld+clang-$TARGET-0.11.0-dev.256+271cc52a1"
PREFIX="$HOME/deps/$CACHE_BASENAME"
ZIG="$PREFIX/bin/zig" 

export PATH="$HOME/deps/wasmtime-v2.0.2-$ARCH-linux:$PATH"

# Make the `zig version` number consistent.
# This will affect the cmake command below.
git config core.abbrev 9
git fetch --unshallow || true
git fetch --tags

export CC="$ZIG cc -target $TARGET -mcpu=$MCPU"
export CXX="$ZIG c++ -target $TARGET -mcpu=$MCPU"

rm -rf build-release
mkdir build-release
cd build-release
cmake .. \
  -DCMAKE_INSTALL_PREFIX="stage3-release" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_BUILD_TYPE=Release \
  -DZIG_TARGET_TRIPLE="$TARGET" \
  -DZIG_TARGET_MCPU="$MCPU" \
  -DZIG_STATIC=ON \
  -GNinja

# Now cmake will use zig as the C/C++ compiler. We reset the environment variables
# so that installation and testing do not get affected by them.
unset CC
unset CXX

ninja install

echo "Looking for non-conforming code formatting..."
stage3-release/bin/zig fmt --check .. \
  --exclude ../test/cases/ \
  --exclude ../build-release

# simultaneously test building self-hosted without LLVM and with 32-bit arm
stage3-release/bin/zig build -Dtarget=arm-linux-musleabihf

# TODO: add -fqemu back to this line

stage3-release/bin/zig build test docs \
  -fwasmtime \
  -Dstatic-llvm \
  -Dtarget=native-native-musl \
  --search-prefix "$PREFIX" \
  --zig-lib-dir "$(pwd)/../lib"

# Look for HTML errors.
tidy --drop-empty-elements no -qe zig-cache/langref.html

# Produce the experimental std lib documentation.
mkdir -p "stage3-release/doc/std"
stage3-release/bin/zig test ../lib/std/std.zig \
  -femit-docs=stage3-release/doc/std \
  -fno-emit-bin \
  --zig-lib-dir "$(pwd)/../lib"