#!/bin/bash
# Copyright (c) 2026 kewe87. Licensed under LGPL-2.1-or-later.
# Builds libgstmatroska.so for LG webOS 22 (32-bit ARM userland, GStreamer 1.18.2)
# with LG's starfish SDK 7.0.0 and LG's target sysroot.
#
# Usage: build/build.sh [output.so]
#
# Environment:
#   STARFISH_SDK  path of the installed starfish SDK  (default: ~/tc/starfish)
#   DOVI_LIB      libdovi static library              (default: see build-libdovi.sh)
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
SRC="$ROOT/src/matroska"
OUT=${1:-$ROOT/out/libgstmatroska.so}
STARFISH_SDK=${STARFISH_SDK:-$HOME/tc/starfish}
DOVI_LIB=${DOVI_LIB:-$ROOT/out/libdovi/libdolby_vision.a}

# shellcheck disable=SC1090
. "$STARFISH_SDK"/environment-setup-ca9v1-starfishmllib32-linux-gnueabi 2>/dev/null
S=$SDKTARGETSYSROOT
if [ ! -f "$S/usr/include/gstreamer-1.0/gst/gst.h" ]; then
  echo "LG's GStreamer headers are missing in $S."
  echo "Extract target_sysroot_dependencies.tar.gz from LG's source package into it (see README)."
  exit 1
fi

mkdir -p "$(dirname "$OUT")"
OBJ=$(mktemp -d)
trap 'rm -rf "$OBJ"' EXIT

CFLAGS_GST="-I$SRC -I$HERE -I$S/usr/include/gstreamer-1.0 -I$S/usr/include/glib-2.0 -I$S/usr/lib/glib-2.0/include \
 -pipe -D_FILE_OFFSET_BITS=64 -Wall -O2 -g -fvisibility=hidden -fno-strict-aliasing -DG_DISABLE_CAST_CHECKS \
 -Wmissing-declarations -Wno-multichar -Wpointer-arith -Wmissing-prototypes -Wdeclaration-after-statement \
 -feliminate-unused-debug-types -fPIC -pthread -DHAVE_CONFIG_H"

for f in ebml-read ebml-write matroska matroska-demux matroska-parse matroska-ids matroska-mux matroska-read-common webm-mux lzo; do
  $CC $CFLAGS_GST -c "$SRC/$f.c" -o "$OBJ/$f.o"
done

EXTRA=""
if grep -q '^#define DOLBYHDR_P7_TO_P81' "$SRC/matroska-demux.h"; then
  [ -f "$DOVI_LIB" ] || { echo "libdovi missing: $DOVI_LIB (run build/build-libdovi.sh)"; exit 1; }
  EXTRA="$DOVI_LIB -Wl,--exclude-libs,ALL -Wl,--gc-sections -lpthread -ldl -lgcc_s"
fi

$CC -shared -fPIC $LDFLAGS -Wl,-soname,libgstmatroska.so -o "$OUT" "$OBJ"/*.o $EXTRA \
  -lgstpbutils-1.0 -lgstaudio-1.0 -lgstriff-1.0 -lgstvideo-1.0 -lgsttag-1.0 -lgstbase-1.0 -lgstreamer-1.0 \
  -lgobject-2.0 -lglib-2.0 -lz -lbz2 -lm

$STRIP --strip-debug "$OUT"
echo "Built: $OUT"
sha256sum "$OUT"
