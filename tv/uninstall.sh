#!/bin/sh
# Copyright (c) 2026 kewe87. Licensed under LGPL-2.1-or-later.
# Removes the autostart link and files. LG's original is active again right away
# if nothing is playing, otherwise after a reboot. Same as "ctl.sh uninstall".
SRC=$(cd "$(dirname "$0")" && pwd)
if [ -f "$SRC/ctl.sh" ]; then
  sh "$SRC/ctl.sh" uninstall
else
  sh /media/developer/mkvdv/ctl.sh uninstall
fi
