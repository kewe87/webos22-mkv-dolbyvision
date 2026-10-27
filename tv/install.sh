#!/bin/sh
# Copyright (c) 2026 kewe87. Licensed under LGPL-2.1-or-later.
# Run on the TV as root (rooted TV with Homebrew Channel) from the directory
# that contains libgstmatroska.so and the tv/ scripts.
# Same as "ctl.sh enable"; pass --force to accept an LG original that is not in
# supported-originals.md5 after the isolated check has passed.
SRC=$(cd "$(dirname "$0")" && pwd)
sh "$SRC/ctl.sh" enable "$1"
cat /tmp/mkvdv-autostart.log 2>/dev/null
