#!/bin/sh
# Run on the TV as root (rooted TV with Homebrew Channel) from the directory
# that contains libgstmatroska.so and the tv/ scripts.
set -e
SRC=$(cd "$(dirname "$0")" && pwd)
DIR=/media/developer/mkvdv
TARGET=/usr/lib/gstreamer-1.0/libgstmatroska.so
LINK=/var/lib/webosbrew/init.d/40-mkv-dolbyvision

SO="$SRC/libgstmatroska.so"
[ -f "$SO" ] || SO="$SRC/../libgstmatroska.so"
[ -f "$SO" ] || { echo "libgstmatroska.so not found next to install.sh"; exit 1; }

ORIG=$(md5sum < "$TARGET" | cut -d' ' -f1)
if grep -q " $TARGET " /proc/self/mountinfo; then
  echo "Updating an active installation."
elif ! grep -q "^$ORIG" "$SRC/supported-originals.md5"; then
  echo "Your LG original ($ORIG) is not in supported-originals.md5."
  echo "Test the build first (README: 'Isolated test'), then add the line if it works."
  exit 1
fi

mkdir -p "$DIR"
# write a new file and rename it: never overwrite a file that may be mapped
cp "$SO" "$DIR/libgstmatroska.so.new"
md5sum < "$DIR/libgstmatroska.so.new" | cut -d' ' -f1 > "$DIR/libgstmatroska.so.md5"
mv "$DIR/libgstmatroska.so.new" "$DIR/libgstmatroska.so"
cp "$SRC/autostart.sh" "$SRC/supported-originals.md5" "$DIR/"
chmod 755 "$DIR/autostart.sh"
mkdir -p /var/lib/webosbrew/init.d
ln -sf "$DIR/autostart.sh" "$LINK"

# switch an active overlay to the new file right away if nothing is playing
if grep -q " $TARGET " /proc/self/mountinfo; then
  if grep -l libgstmatroska /proc/[0-9]*/maps 2>/dev/null | grep -qv self; then
    echo "A player is using the demuxer right now; the new version is active after a reboot."
    exit 0
  fi
  umount "$TARGET"
fi
"$DIR/autostart.sh"
cat /tmp/mkvdv-autostart.log
