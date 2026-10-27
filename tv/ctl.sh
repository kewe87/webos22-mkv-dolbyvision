#!/bin/sh
# Copyright (c) 2026 kewe87. Licensed under LGPL-2.1-or-later.
# webos22-mkv-dolbyvision control script. Run as root on the TV, either over SSH
# or from the Homebrew Channel app (luna://org.webosbrew.hbchannel.service/exec).
#
#   ctl.sh status            JSON status (one line)
#   ctl.sh enable [--force]  install the replacement next to this script and activate it;
#                            --force accepts an unknown LG original after a passing check
#   ctl.sh disable           remove the boot link, deactivate (now if idle, else after reboot)
#   ctl.sh p7 on|off         profile 7 -> 8.1 conversion (from the next playback on)
#   ctl.sh check             load the replacement in an isolated GStreamer instance
#   ctl.sh log               diagnostics logs (plain text)
#   ctl.sh uninstall         disable and delete all installed files
#
# Every command except log prints one JSON line: {"ok":true|false,...}. Exit code is 0.

SRC=$(cd "$(dirname "$0")" && pwd)
DIR=/media/developer/mkvdv
TARGET=/usr/lib/gstreamer-1.0/libgstmatroska.so
LINK=/var/lib/webosbrew/init.d/40-mkv-dolbyvision
LOG=/tmp/mkvdv-autostart.log
DVLOG=/tmp/matroska-dv.log

md5_of() { md5sum < "$1" 2>/dev/null | cut -d' ' -f1; }
js() { printf '%s' "$1" | tr '\n\r\t' '   ' | sed 's/\\/\\\\/g; s/"/\\"/g'; }
tf() { if "$@"; then echo true; else echo false; fi; }
fail() { echo "{\"ok\":false,\"error\":\"$1\",\"detail\":\"$(js "$2")\"}"; exit 0; }

src_so() {
  for f in "$SRC/libgstmatroska.so" "$SRC/../libgstmatroska.so"; do
    [ -f "$f" ] && { echo "$f"; return; }
  done
}
mounted() { grep -q " $TARGET " /proc/self/mountinfo; }
in_use() { grep -l libgstmatroska /proc/[0-9]*/maps 2>/dev/null | grep -qv self; }

# checksum of LG's original; while the overlay is active, a plain (non-recursive) bind
# of the directory shows the file underneath it
orig_md5() {
  if mounted; then
    O=/tmp/mkvdv-orig
    mkdir -p "$O" && mount --bind "$(dirname "$TARGET")" "$O" && md5_of "$O/$(basename "$TARGET")"
    umount "$O" 2>/dev/null; rmdir "$O" 2>/dev/null
  else
    md5_of "$TARGET"
  fi
}
# official | local | unknown
orig_known() {
  m=$1
  [ -n "$m" ] || { echo unknown; return; }
  for f in "$SRC/supported-originals.md5" "$DIR/supported-originals.md5"; do
    grep -q "^$m" "$f" 2>/dev/null && { echo official; return; }
  done
  grep -q "^$m" "$DIR/supported-originals.local" 2>/dev/null && { echo local; return; }
  echo unknown
}

check() {
  so=$(src_so)
  [ -n "$so" ] || { CHECK_OUT="replacement not found"; return 1; }
  T=/tmp/mkvdv-check
  rm -rf "$T"; mkdir -p "$T/p"; cp "$so" "$T/p/"
  CHECK_OUT=$(env -i PATH=/usr/bin:/bin HOME="$T" GST_REGISTRY_1_0="$T/reg.bin" \
    GST_PLUGIN_SYSTEM_PATH_1_0="$T/p" GST_PLUGIN_PATH_1_0= \
    gst-inspect-1.0 matroskademux 2>&1 | head -c 2000)
  rm -rf "$T"
  case "$CHECK_OUT" in *"Matroska demuxer"*) r=0 ;; *) r=1 ;; esac
  return $r
}

cmd_status() {
  om=$(orig_md5)
  so=$(src_so)
  bundled=$( [ -n "$so" ] && md5_of "$so")
  installed=$(cat "$DIR/libgstmatroska.so.md5" 2>/dev/null)
  ver=$(cat "$SRC/VERSION" 2>/dev/null)
  iver=$(cat "$DIR/VERSION" 2>/dev/null)
  rel=$(sed -n 's/.*"webos_release": *"\([^"]*\)".*/\1/p' /var/run/nyx/os_info.json 2>/dev/null)
  gst=$(ls /usr/lib/libgstreamer-1.0.so.0.* 2>/dev/null | sed 's/.*\.so\.0\.//' | head -1)
  running=$(mounted && md5_of "$TARGET")
  update=false
  [ -n "$installed" ] && [ -n "$bundled" ] && [ "$installed" != "$bundled" ] && update=true
  echo "{\"ok\":true,\"version\":\"$(js "$ver")\",\"installedVersion\":\"$(js "$iver")\",\
\"installed\":$(tf [ -f "$DIR/libgstmatroska.so" ]),\"linked\":$(tf [ -L "$LINK" ]),\
\"disabledFlag\":$(tf [ -f "$DIR/disable" ]),\"active\":$(tf mounted),\"inUse\":$(tf in_use),\
\"p7\":$(tf [ ! -f "$DIR/disable-p7" ]),\"original\":\"$(js "$om")\",\"originalKnown\":\"$(orig_known "$om")\",\
\"bundledMd5\":\"$(js "$bundled")\",\"installedMd5\":\"$(js "$installed")\",\"runningMd5\":\"$(js "$running")\",\"updateAvailable\":$update,\
\"webosRelease\":\"$(js "$rel")\",\"gstreamer\":\"$(js "$gst")\",\"autostartLog\":\"$(js "$(cat "$LOG" 2>/dev/null)")\"}"
}

cmd_enable() {
  so=$(src_so)
  [ -n "$so" ] || fail no-payload "libgstmatroska.so not found next to ctl.sh"
  om=$(orig_md5)
  [ -n "$om" ] || fail no-original "$TARGET"
  forced=false
  if [ "$(orig_known "$om")" = unknown ]; then
    [ "$1" = "--force" ] || fail unknown-original "$om"
    check || fail check-failed "$CHECK_OUT"
    forced=true
  fi

  mkdir -p "$DIR" || fail write-failed "$DIR"
  # write a new file and rename it: never overwrite a file that may be mapped
  cp "$so" "$DIR/libgstmatroska.so.new" || fail write-failed "copy failed"
  md5_of "$DIR/libgstmatroska.so.new" > "$DIR/libgstmatroska.so.md5"
  mv "$DIR/libgstmatroska.so.new" "$DIR/libgstmatroska.so"
  for f in autostart.sh ctl.sh supported-originals.md5 VERSION; do
    [ -f "$SRC/$f" ] && [ "$SRC" != "$DIR" ] && cp "$SRC/$f" "$DIR/"
  done
  chmod 755 "$DIR/autostart.sh" "$DIR/ctl.sh" 2>/dev/null
  [ "$forced" = true ] && echo "$om  added with --force on $(date)" >> "$DIR/supported-originals.local"
  rm -f "$DIR/disable"
  mkdir -p "$(dirname "$LINK")"
  ln -sf "$DIR/autostart.sh" "$LINK"

  # switch an active overlay to the new file right away if nothing is playing
  if mounted; then
    if in_use; then
      echo "{\"ok\":true,\"result\":\"reboot-required\"}"; exit 0
    fi
    umount "$TARGET"
  fi
  "$DIR/autostart.sh"
  if mounted; then
    echo "{\"ok\":true,\"result\":\"active\"}"
  else
    fail activate-failed "$(cat "$LOG" 2>/dev/null)"
  fi
}

cmd_disable() {
  rm -f "$LINK"
  [ -d "$DIR" ] && touch "$DIR/disable"
  if mounted; then
    if in_use; then
      echo "{\"ok\":true,\"result\":\"reboot-required\"}"; exit 0
    fi
    umount "$TARGET" || { echo "{\"ok\":true,\"result\":\"reboot-required\"}"; exit 0; }
  fi
  echo "disabled on $(date)" > "$LOG"
  echo "{\"ok\":true,\"result\":\"inactive\"}"
}

cmd_p7() {
  [ -d "$DIR" ] || fail not-installed ""
  case "$1" in
    on)  rm -f "$DIR/disable-p7" ;;
    off) touch "$DIR/disable-p7" ;;
    *)   fail usage "p7 on|off" ;;
  esac
  echo "{\"ok\":true,\"p7\":$(tf [ ! -f "$DIR/disable-p7" ])}"
}

cmd_uninstall() {
  rm -f "$LINK"
  # keep the directory while the overlay is mounted: the bind mount still points into it
  if mounted && { in_use || ! umount "$TARGET"; }; then
    rm -f "$DIR/autostart.sh" "$DIR/libgstmatroska.so.md5" "$DIR/supported-originals.local"
    touch "$DIR/disable"
    echo "{\"ok\":true,\"result\":\"reboot-required\"}"; exit 0
  fi
  rm -rf "$DIR"
  echo "uninstalled on $(date)" > "$LOG"
  echo "{\"ok\":true,\"result\":\"removed\"}"
}

[ "$(id -u)" = 0 ] || fail no-root "ctl.sh must run as root"

case "$1" in
  status)    cmd_status ;;
  enable)    cmd_enable "$2" ;;
  disable)   cmd_disable ;;
  p7)        cmd_p7 "$2" ;;
  check)
    if check; then echo "{\"ok\":true,\"output\":\"$(js "$CHECK_OUT")\"}"
    else fail check-failed "$CHECK_OUT"; fi ;;
  log)
    echo "== $LOG"; cat "$LOG" 2>/dev/null
    echo "== $DVLOG (last 40 lines)"; tail -n 40 "$DVLOG" 2>/dev/null ;;
  uninstall) cmd_uninstall ;;
  *) fail usage "status|enable [--force]|disable|p7 on|off|check|log|uninstall" ;;
esac
exit 0
