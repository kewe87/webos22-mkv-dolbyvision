#!/bin/sh
# Copyright (c) 2026 kewe87. Licensed under LGPL-2.1-or-later.
# webos-mkv-dolbyvision control script. Run as root on the TV, either over SSH
# or from the Homebrew Channel app (luna://org.webosbrew.hbchannel.service/exec).
#
#   ctl.sh status            JSON status (one line)
#   ctl.sh probe             read-only diagnostics for a port to another webOS
#                            version; writes /tmp/mkvdv-probe.txt, prints JSON
#   ctl.sh enable [--persist] [--force]
#                            install the matching plugin and activate it now (in RAM,
#                            gone on reboot). --persist additionally adds it to
#                            autostart so it comes back after a restart - the user's
#                            choice, and only if this firmware still has the webOSbrew
#                            boot hook. --force accepts an unknown LG original after
#                            a passing check.
#   ctl.sh persist on|off    add / remove the autostart boot link later (needs the
#                            webOSbrew startup hook). "off" keeps it active now.
#   ctl.sh disable           switch off: remove the boot link and deactivate
#                            (now if idle, else after reboot)
#   ctl.sh p7 on|off         profile 7 -> 8.1 conversion (from the next playback on)
#   ctl.sh check             load the matching plugin in an isolated GStreamer instance
#   ctl.sh log               diagnostics logs (plain text)
#   ctl.sh uninstall         disable and delete all installed files
#
# Every command except log prints one JSON line: {"ok":true|false,...}. Exit code is 0.

SRC=$(cd "$(dirname "$0")" && pwd)
DIR=/media/developer/mkvdv
TARGET=/usr/lib/gstreamer-1.0/libgstmatroska.so
LINK=/var/lib/webosbrew/init.d/40-mkv-dolbyvision
WBINIT=/var/lib/webosbrew/init.d
WBROOT=/var/lib/webosbrew
LOG=/tmp/mkvdv-autostart.log
DVLOG=/tmp/matroska-dv.log

md5_of() { md5sum < "$1" 2>/dev/null | cut -d' ' -f1; }
js() { printf '%s' "$1" | tr '\n\r\t' '   ' | sed 's/\\/\\\\/g; s/"/\\"/g'; }
# like js(), but keeps line breaks as literal \n (for multi-line JSON values)
jsx() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r//g' | sed ':a;N;$!ba;s/\n/\\n/g'; }
tf() { if "$@"; then echo true; else echo false; fi; }
fail() { echo "{\"ok\":false,\"error\":\"$1\",\"detail\":\"$(js "$2")\"}"; exit 0; }

# turn a shared-library soname tail (e.g. 1802.0) into a version (1.18.2); $2 is the major
sover() { n=${1%%.*}; case "$n" in ''|*[!0-9]*) echo "${1:-?}";; *) echo "$2.$((n/100)).$((n%100))";; esac; }
tv_gst() { t=$(ls /usr/lib/libgstreamer-1.0.so.0.* 2>/dev/null | sed 's#.*\.so\.0\.##' | head -1); sover "$t" 1; }

# plugin catalogs: prefer the payload next to this script, fall back to the install dir
catalog()  { for f in "$SRC/originals.md5" "$DIR/originals.md5"; do [ -f "$f" ] && { echo "$f"; return; }; done; }
vartab()   { for f in "$SRC/variants.tab" "$DIR/variants.tab"; do [ -f "$f" ] && { echo "$f"; return; }; done; }
plugin_path() {
  for p in "$SRC/plugins/$1/libgstmatroska.so" "$DIR/plugins/$1/libgstmatroska.so"; do
    [ -f "$p" ] && { echo "$p"; return; }
  done
}

mounted() { grep -q " $TARGET " /proc/self/mountinfo; }
in_use() { grep -l libgstmatroska /proc/[0-9]*/maps 2>/dev/null | grep -qv self; }
# the webOSbrew persistence hook that runs /var/lib/webosbrew/init.d/* at boot
autostart_possible() { [ -d "$WBINIT" ] || [ -f "$WBROOT/startup.sh" ]; }

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

# Which plugin variant fits THIS TV, keyed on the TV's GStreamer version - the ABI
# the plugin binds to, identical across TV models of the same webOS major. echoes
# four words:
#   <variant> <verified> <known> <recorded>
#   variant  : id under plugins/, or "-" if no bundled build fits this version
#   verified : true | false  (confirmed on real hardware for this GStreamer version)
#   known    : official (verified) | experimental (build exists, unverified) | unknown (no build)
#   recorded : yes | no  (this exact LG original has been seen/listed before)
select_variant() {
  om=$1
  g=$(tv_gst)
  v=$(awk -v g="$g" '$2==g {print $1; exit}' "$(vartab)" 2>/dev/null)
  [ -n "$v" ] || { echo "- false unknown no"; return; }
  cls=$(awk -v g="$g" '$2==g {print $3; exit}' "$(vartab)" 2>/dev/null)
  ver=false; [ "$cls" = verified ] && ver=true
  if awk -v m="$om" '$1==m{f=1} END{exit !f}' "$(catalog)" 2>/dev/null \
     || grep -q "^$om" "$DIR/supported-originals.local" 2>/dev/null; then
    rec=yes
  else
    rec=no
  fi
  if [ "$ver" = true ]; then known=official; else known=experimental; fi
  echo "$v $ver $known $rec"
}

check() {
  so=$1
  [ -n "$so" ] && [ -f "$so" ] || { CHECK_OUT="replacement not found"; return 1; }
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
  set -- $(select_variant "$om"); variant=$1; verified=$2; known=$3; rec=$4
  [ "$variant" = "-" ] && variant=""
  so=$(plugin_path "$variant")
  bundled=$( [ -n "$so" ] && md5_of "$so")
  installed=$(cat "$DIR/libgstmatroska.so.md5" 2>/dev/null)
  ver=$(cat "$SRC/VERSION" 2>/dev/null)
  iver=$(cat "$DIR/VERSION" 2>/dev/null)
  rel=$(sed -n 's/.*"webos_release": *"\([^"]*\)".*/\1/p' /var/run/nyx/os_info.json 2>/dev/null)
  gst=$(ls /usr/lib/libgstreamer-1.0.so.0.* 2>/dev/null | sed 's/.*\.so\.0\.//' | head -1)
  running=$(mounted && md5_of "$TARGET")
  update=false
  [ -n "$installed" ] && [ -n "$bundled" ] && [ "$installed" != "$bundled" ] && update=true
  exp=false; { { [ -n "$variant" ] && [ "$verified" != true ]; } || [ -f "$DIR/experimental" ]; } && exp=true
  echo "{\"ok\":true,\"version\":\"$(js "$ver")\",\"installedVersion\":\"$(js "$iver")\",\
\"installed\":$(tf [ -f "$DIR/libgstmatroska.so" ]),\"linked\":$(tf [ -L "$LINK" ]),\
\"disabledFlag\":$(tf [ -f "$DIR/disable" ]),\"active\":$(tf mounted),\"inUse\":$(tf in_use),\
\"autostartAvailable\":$(tf autostart_possible),\"experimental\":$exp,\"verified\":$([ "$verified" = true ] && echo true || echo false),\"variant\":\"$(js "$variant")\",\
\"p7\":$(tf [ ! -f "$DIR/disable-p7" ]),\"original\":\"$(js "$om")\",\"originalKnown\":\"$(js "$known")\",\
\"bundledMd5\":\"$(js "$bundled")\",\"installedMd5\":\"$(js "$installed")\",\"runningMd5\":\"$(js "$running")\",\"updateAvailable\":$update,\
\"webosRelease\":\"$(js "$rel")\",\"gstreamer\":\"$(js "$gst")\",\"autostartLog\":\"$(js "$(cat "$LOG" 2>/dev/null)")\"}"
}

# Read-only diagnostics for a port request to another webOS version. Changes
# nothing on the TV (no mount, no writes outside /tmp). Collects exactly the
# facts a port needs, writes a full report to /tmp, and prints JSON with a
# compact summary the app turns into a pre-filled GitHub issue (QR code).
# Every probe is fail-soft: a missing file/command just yields an empty field.
cmd_probe() {
  PT=/tmp/mkvdv-probe.txt
  PJ=/tmp/mkvdv-probe.json
  PVER=1

  jget() { printf '%s' "$1" | sed -n 's/.*"'"$2"'"[: ]*"\([^"]*\)".*/\1/p' | head -1; }
  # strip the TV's identifiers from a JSON dump before it can be posted publicly
  redact_pii() { sed -e 's/\("serial_number"[^"]*"\)[^"]*"/\1<redacted>"/' \
                     -e 's/\("nduid"[^"]*"\)[^"]*"/\1<redacted>"/' \
                     -e 's/\("wifi_addr"[^"]*"\)[^"]*"/\1<redacted>"/' \
                     -e 's/\("wired_addr"[^"]*"\)[^"]*"/\1<redacted>"/'; }

  uname_a=$(uname -a 2>/dev/null)
  osinfo=$(cat /var/run/nyx/os_info.json 2>/dev/null)
  devinfo=$(cat /var/run/nyx/device_info.json 2>/dev/null)
  starfish=$(cat /etc/starfish-release 2>/dev/null)
  cpuinfo=$(head -n 40 /proc/cpuinfo 2>/dev/null)

  rel=$(jget "$osinfo" webos_release)
  bld=$(jget "$osinfo" webos_build_id)
  model=$(jget "$devinfo" modelName)
  [ -n "$model" ] || model=$(jget "$devinfo" device_name)
  board=$(jget "$devinfo" boardType)
  [ -n "$board" ] || board=$(jget "$devinfo" board_type)
  # the two keys that identify the LG open-source / firmware package to download
  product=$(jget "$devinfo" product_id)
  hwid=$(jget "$devinfo" hardware_id)
  fwver=$(jget "$osinfo" webos_manufacturing_version)

  sover2() { n=${1%%.*}; case "$n" in ''|*[!0-9]*) echo "${1:-?}";; *) echo "$2.$((n/100)).$((n%100))";; esac; }

  gstlib=$(ls /usr/lib/libgstreamer-1.0.so.0.* 2>/dev/null | sed 's/.*\.so\.0\.//' | head -1)
  gst=$(sover2 "$gstlib" 1)
  gstver=$(gst-inspect-1.0 --version 2>/dev/null | head -2 | tr '\n' ' ')
  cpuarch=$(printf '%s' "$cpuinfo" | sed -n 's/^CPU architecture[: \t]*\(.*\)/\1/p' | head -1)
  case "$cpuarch" in 8) cpudesc="ARMv8" ;; 7) cpudesc="ARMv7" ;; *) cpudesc="${cpuarch:-?}" ;; esac
  cpumodel=$(printf '%s' "$cpuinfo" | sed -n 's/^model name[: \t]*\(.*\)/\1/p' | head -1)
  [ -n "$cpumodel" ] || cpumodel=$(printf '%s' "$cpuinfo" | sed -n 's/^Hardware[: \t]*\(.*\)/\1/p' | head -1)
  [ -n "$cpumodel" ] || cpumodel=$(printf '%s' "$cpuinfo" | sed -n 's/^CPU part[: \t]*\(.*\)/part \1/p' | head -1)

  so_md5=$(orig_md5)
  so_size=$(wc -c < "$TARGET" 2>/dev/null)
  mkdemux=$(gst-inspect-1.0 matroskademux 2>/dev/null | sed -n 's/^\(  Version\).*/&/p' | head -1)

  # versions of the libraries the playback pipeline is built on, and the actual
  # video decoder/sink elements: tells us up front how far a port has to reach
  glib=$(ls /usr/lib/libglib-2.0.so.0.* 2>/dev/null | sed 's/.*\.so\.0\.//' | head -1)
  glibv=$(sover2 "$glib" 2)
  qtver=$(gst-inspect-1.0 qtdemux 2>/dev/null | awk '/^  Version/{print $2; exit}')
  vids=$(gst-inspect-1.0 2>/dev/null | grep -iE 'decoder|sink' | grep -iE 'video|dolby|hevc|h.?265' | head -25 | tr '\n' ';')

  # the gate: does this platform's media pipeline know Dolby Vision at all?
  qtdemux=$(gst-inspect-1.0 qtdemux 2>/dev/null)
  dv_qt=$(printf '%s' "$qtdemux" | grep -ic 'dolby' 2>/dev/null)
  dv_plugins=$(grep -rl 'dolby-vision' /usr/lib/gstreamer-1.0 2>/dev/null | tr '\n' ' ')
  dv_cfg=$(luna-send -n 1 -w 3000 luna://com.webos.service.config/getConfigs \
    '{"configNames":["tv.model.supportDolbyVision","tv.rmm.supportDolbyVision","tv.config.supportDolbyVision"]}' 2>/dev/null | tr '\n' ' ')
  dv_capable=false
  { [ "${dv_qt:-0}" -gt 0 ] 2>/dev/null || [ -n "$dv_plugins" ]; } && dv_capable=true

  {
    echo "== MKV Dolby Vision - port diagnostics (read-only) =="
    echo "probeVersion: $PVER"
    echo "date: $(date -u 2>/dev/null)"
    echo
    echo "[uname]  $uname_a"
    echo "[model]  product=$product  device=$model  board=$board  hwid=$hwid"
    echo "[fw]     manufacturingVersion=$fwver  webOS=$rel  buildId=$bld"
    echo "[gst]    version=$gst  lib=$gstlib  inspect=$gstver"
    echo "[glib]   version=$glibv  lib=$glib"
    echo "[cpu]    arch=$cpudesc ($cpuarch)  model=$cpumodel"
    echo "[mkv]    $TARGET  md5=$so_md5  size=$so_size"
    echo "[mkv]    $mkdemux"
    echo "[qtdemux] version=$qtver"
    echo "[video]  elements: $vids"
    echo "[dv]     qtdemuxDolbyLines=$dv_qt  capable=$dv_capable"
    echo "[dv]     plugins: $dv_plugins"
    echo "[dv]     config: $dv_cfg"
    echo
    echo "---- /etc/starfish-release ----"; printf '%s\n' "$starfish"
    echo "---- /var/run/nyx/os_info.json ----"; printf '%s\n' "$osinfo"
    echo "---- /var/run/nyx/device_info.json (serial/ids redacted) ----"; printf '%s\n' "$devinfo" | redact_pii
    echo "---- /proc/cpuinfo (head) ----"; printf '%s\n' "$cpuinfo"
    echo "---- qtdemux: dolby lines ----"; printf '%s\n' "$qtdemux" | grep -i dolby 2>/dev/null
  } > "$PT" 2>/dev/null
  [ -d "$DIR" ] && cp "$PT" "$DIR/" 2>/dev/null

  # also drop the report onto any plugged-in, writable USB stick, so a tester
  # without SSH can just pull the stick and upload the file from a PC
  usb_saved=""
  for u in $(awk '$2 ~ /^\/(tmp\/usb|media)\// && $3 ~ /^(vfat|exfat|ntfs|fuseblk|msdos|fat)$/ {print $2}' /proc/mounts 2>/dev/null); do
    if cp "$PT" "$u/mkvdv-probe.txt" 2>/dev/null; then
      usb_saved="$usb_saved${usb_saved:+; }$u/mkvdv-probe.txt"
    fi
  done
  [ -n "$usb_saved" ] && sync 2>/dev/null

  summary=$(printf 'MKV-DV port probe v%s\nmodel: %s (board %s / %s)\nfirmware: %s (webOS %s build %s)\nGStreamer: %s\nGLib: %s\nCPU: %s / %s\nmatroska md5: %s\nqtdemux: %s\nDV pipeline detected: %s\n(full report incl. decoder elements on TV: %s)' \
    "$PVER" "${product:-${model:-?}}" "${board:-?}" "${model:-?}" "${fwver:-?}" "${rel:-?}" "${bld:-?}" "${gst:-?}" "${glibv:-?}" "${cpudesc:-?}" "${cpumodel:-?}" "${so_md5:-?}" "${qtver:-?}" "$dv_capable" "$PT")
  title="webOS port diagnostics: ${product:-${model:-unknown}} fw ${fwver:-?}"

  json="{\"ok\":true,\"probe\":{\
\"probeVersion\":$PVER,\
\"productId\":\"$(js "$product")\",\"model\":\"$(js "$model")\",\"board\":\"$(js "$board")\",\"hardwareId\":\"$(js "$hwid")\",\
\"fwVersion\":\"$(js "$fwver")\",\"webosRelease\":\"$(js "$rel")\",\"buildId\":\"$(js "$bld")\",\
\"gstreamer\":\"$(js "$gst")\",\"gstreamerLib\":\"$(js "$gstlib")\",\"gstreamerVersion\":\"$(js "$gstver")\",\
\"glibVersion\":\"$(js "$glibv")\",\"glib\":\"$(js "$glib")\",\"qtdemuxVersion\":\"$(js "$qtver")\",\"videoElements\":\"$(js "$vids")\",\
\"cpuArch\":\"$(js "$cpuarch")\",\"cpuDesc\":\"$(js "$cpudesc")\",\"cpuModel\":\"$(js "$cpumodel")\",\
\"uname\":\"$(js "$uname_a")\",\
\"matroskaPath\":\"$(js "$TARGET")\",\"matroskaMd5\":\"$(js "$so_md5")\",\"matroskaSize\":\"$(js "$so_size")\",\
\"matroskaInspect\":\"$(js "$mkdemux")\",\
\"dvQtdemuxLines\":\"$(js "$dv_qt")\",\"dvPlugins\":\"$(js "$dv_plugins")\",\"dvCapable\":$dv_capable,\
\"reportPath\":\"$(js "$PT")\",\"usbSaved\":\"$(js "$usb_saved")\",\
\"title\":\"$(jsx "$title")\",\"summary\":\"$(jsx "$summary")\"}}"
  printf '%s\n' "$json" > "$PJ" 2>/dev/null
  printf '%s\n' "$json"
}

cmd_enable() {
  om=$(orig_md5)
  [ -n "$om" ] || fail no-original "$TARGET"
  set -- $(select_variant "$om"); variant=$1; verified=$2; known=$3; rec=$4
  [ "$variant" != "-" ] || fail no-variant "no bundled plugin for GStreamer $(tv_gst)"
  so=$(plugin_path "$variant")
  [ -n "$so" ] || fail no-payload "plugins/$variant/libgstmatroska.so not found"
  # Safety: load the plugin in an isolated GStreamer first whenever the variant is
  # not yet verified for this GStreamer version, or this exact LG original has not
  # been seen before. --force skips this last-resort check.
  if [ "$FORCE" != 1 ] && { [ "$verified" != true ] || [ "$rec" = no ]; }; then
    check "$so" || fail check-failed "$CHECK_OUT"
  fi

  mkdir -p "$DIR" || fail write-failed "$DIR"
  # write a new file and rename it: never overwrite a file that may be mapped
  cp "$so" "$DIR/libgstmatroska.so.new" || fail write-failed "copy failed"
  md5_of "$DIR/libgstmatroska.so.new" > "$DIR/libgstmatroska.so.md5"
  mv "$DIR/libgstmatroska.so.new" "$DIR/libgstmatroska.so"
  for f in autostart.sh ctl.sh originals.md5 variants.tab VERSION; do
    [ -f "$SRC/$f" ] && [ "$SRC" != "$DIR" ] && cp "$SRC/$f" "$DIR/"
  done
  chmod 755 "$DIR/autostart.sh" "$DIR/ctl.sh" 2>/dev/null
  # autostart.sh re-activates only for THIS TV's exact original; record just that line
  cls=experimental; [ "$verified" = true ] && cls=verified
  printf '%s  %s  %s\n' "$om" "$variant" "$cls" > "$DIR/supported-originals.md5"
  [ "$rec" = no ] && printf '%s  %s  seen %s\n' "$om" "$variant" "$(date)" >> "$DIR/supported-originals.local"
  if [ "$verified" = true ]; then rm -f "$DIR/experimental"; else : > "$DIR/experimental"; fi
  rm -f "$DIR/disable"

  # switch an active overlay to the new file right away if nothing is playing
  if mounted; then
    if in_use; then
      echo "{\"ok\":true,\"result\":\"reboot-required\"}"; exit 0
    fi
    umount "$TARGET"
  fi
  "$DIR/autostart.sh"
  mounted || fail activate-failed "$(cat "$LOG" 2>/dev/null)"

  # Autostart is always the user's choice (--persist), never automatic: by default
  # the overlay lives in RAM and is gone on the next reboot. It only survives if
  # the user opts in AND this firmware still has the webOSbrew boot hook (newer
  # webOS versions patched it, so autostart_possible can be false).
  autostart=off
  if [ "$PERSIST" = 1 ]; then
    if autostart_possible; then
      mkdir -p "$(dirname "$LINK")"; ln -sf "$DIR/autostart.sh" "$LINK"; autostart=on
    else
      autostart=unavailable
    fi
  fi
  echo "{\"ok\":true,\"result\":\"active\",\"variant\":\"$(js "$variant")\",\"experimental\":$([ "$verified" = true ] && echo false || echo true),\"autostart\":\"$autostart\"}"
}

cmd_persist() {
  [ -d "$DIR" ] || fail not-installed ""
  case "$1" in
    on)
      autostart_possible || fail no-autostart "this TV has no webOSbrew startup hook"
      [ -f "$DIR/autostart.sh" ] || fail not-installed "autostart.sh missing"
      mkdir -p "$(dirname "$LINK")"
      ln -sf "$DIR/autostart.sh" "$LINK"
      rm -f "$DIR/disable"
      echo "{\"ok\":true,\"autostart\":\"on\"}" ;;
    off)
      rm -f "$LINK"
      echo "{\"ok\":true,\"autostart\":\"off\"}" ;;
    *) fail usage "persist on|off" ;;
  esac
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
    rm -f "$DIR/autostart.sh" "$DIR/libgstmatroska.so.md5" "$DIR/supported-originals.local" "$DIR/experimental"
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
  probe)     cmd_probe ;;
  enable)
    FORCE=0; PERSIST=0
    for a in "$2" "$3"; do
      case "$a" in --force) FORCE=1 ;; --persist) PERSIST=1 ;; esac
    done
    cmd_enable ;;
  persist)   cmd_persist "$2" ;;
  disable)   cmd_disable ;;
  p7)        cmd_p7 "$2" ;;
  check)
    om=$(orig_md5); set -- $(select_variant "$om")
    if check "$(plugin_path "$1")"; then echo "{\"ok\":true,\"output\":\"$(js "$CHECK_OUT")\"}"
    else fail check-failed "$CHECK_OUT"; fi ;;
  log)
    echo "== $LOG"; cat "$LOG" 2>/dev/null
    echo "== $DVLOG (last 40 lines)"; tail -n 40 "$DVLOG" 2>/dev/null ;;
  uninstall) cmd_uninstall ;;
  *) fail usage "status|probe|enable [--force]|persist on|off|disable|p7 on|off|check|log|uninstall" ;;
esac
exit 0
