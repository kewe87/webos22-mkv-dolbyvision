#!/bin/sh
# Removes the autostart link and files. LG's original is active again after a reboot.
DIR=/media/developer/mkvdv
rm -f /var/lib/webosbrew/init.d/40-mkv-dolbyvision
rm -rf "$DIR"
echo "Removed. Reboot the TV to return to LG's original demuxer."
