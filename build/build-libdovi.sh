#!/bin/bash
# Builds libdovi (quietvoid/dovi_tool, crate dolby_vision, C API) as a static
# library for the TV (armv7-unknown-linux-gnueabi, soft-float calling convention,
# compatible with webOS' softfp userland).
#
# Requires rustup with: rustup target add armv7-unknown-linux-gnueabi
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
DOVI_REPO=https://github.com/quietvoid/dovi_tool.git
DOVI_COMMIT=${DOVI_COMMIT:-41dae64}
WORK="$ROOT/out/dovi_tool"
STARFISH_SDK=${STARFISH_SDK:-$HOME/tc/starfish}

if [ ! -d "$WORK/.git" ]; then
  git clone "$DOVI_REPO" "$WORK"
fi
git -C "$WORK" fetch --quiet origin
git -C "$WORK" checkout --quiet "$DOVI_COMMIT"

# shellcheck disable=SC1090
. "$STARFISH_SDK"/environment-setup-ca9v1-starfishmllib32-linux-gnueabi 2>/dev/null
export CC_armv7_unknown_linux_gnueabi="$CC"
export CARGO_TARGET_ARMV7_UNKNOWN_LINUX_GNUEABI_LINKER="${CC%% *}"

(cd "$WORK/dolby_vision" && cargo rustc --release --lib --features capi \
  --target armv7-unknown-linux-gnueabi --crate-type staticlib)

mkdir -p "$ROOT/out/libdovi"
cp "$WORK/dolby_vision/target/armv7-unknown-linux-gnueabi/release/libdolby_vision.a" "$ROOT/out/libdovi/"
echo "Built: $ROOT/out/libdovi/libdolby_vision.a"
