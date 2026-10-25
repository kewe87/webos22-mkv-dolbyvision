#!/bin/sh
# webos22-mkv-dolbyvision: overlays LG's matroska demuxer with the patched one
# via a bind mount. RAM only - LG's files are never modified; a reboot without
# this script restores the original.
#
# Disable: touch /media/developer/mkvdv/disable  (then reboot)
# Disable only the profile 7 -> 8.1 conversion: touch /media/developer/mkvdv/disable-p7

DIR=/media/developer/mkvdv
TARGET=/usr/lib/gstreamer-1.0/libgstmatroska.so
LOG=/tmp/mkvdv-autostart.log

md5_of() { md5sum < "$1" | cut -d' ' -f1; }

if [ -f "$DIR/disable" ]; then
  echo "disabled ($DIR/disable exists)" > "$LOG"; exit 0
fi
if grep -q " $TARGET " /proc/self/mountinfo; then
  echo "already active" > "$LOG"; exit 0
fi
# Only overlay LG originals the build is known to be compatible with
if ! grep -q "^$(md5_of "$TARGET")" "$DIR/supported-originals.md5" 2>/dev/null; then
  echo "unknown original $(md5_of "$TARGET") - not activated (see README)" > "$LOG"; exit 0
fi
if [ ! -f "$DIR/libgstmatroska.so.md5" ] || [ "$(md5_of "$DIR/libgstmatroska.so")" != "$(cat "$DIR/libgstmatroska.so.md5")" ]; then
  echo "replacement missing or damaged - not activated" > "$LOG"; exit 0
fi

if mount --bind "$DIR/libgstmatroska.so" "$TARGET"; then
  echo "active since $(date)" > "$LOG"
else
  echo "bind mount failed" > "$LOG"
fi
exit 0
