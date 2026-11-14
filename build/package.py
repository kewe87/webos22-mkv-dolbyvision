#!/usr/bin/env python3
# Copyright (c) 2026 kewe87. Licensed under LGPL-2.1-or-later.
"""Packages a release into out/release/:

  libgstmatroska.so          the patched demuxer of the primary variant
  tv-scripts.tar.gz          tv/ scripts + plugins for a manual install over SSH
  <app id>_<version>_all.ipk Homebrew Channel app (app/ + payload/)
  <app id>.manifest.json     manifest for the webosbrew apps repo
  SHA256SUMS

The payload bundles ONE plugin per supported webOS variant under
payload/plugins/<variant>/, plus the catalog files originals.md5 (original-md5 ->
variant) and variants.tab (variant -> GStreamer version). ctl.sh picks the
variant that matches the TV at enable time.

Usage: build/package.py [path/to/webos22/libgstmatroska.so]
Needs only the Python standard library; the archives are reproducible.
"""
import gzip
import hashlib
import io
import json
import os
import sys
import tarfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "out", "release")
REPO_URL = "https://github.com/kewe87/webos-mkv-dolbyvision"
MTIME = 1792886400  # fixed timestamp for reproducible archives

EXECUTABLE = {"ctl.sh", "autostart.sh", "install.sh", "uninstall.sh"}

# (variant id, source .so path, is primary). A variant whose .so is missing is
# skipped (so the build still works with only the webOS 22 plugin present).
PRIMARY_SO = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "out", "libgstmatroska.so")
# Variants are named by GStreamer version (what the plugin binds to), not TV model.
VARIANTS = [
    ("gst-1.18.2", PRIMARY_SO, True),
    # additional variants are placed under out/plugins/<variant>/libgstmatroska.so
    # (gitignored, built separately); skipped if absent.
    ("gst-1.16.2", os.path.join(ROOT, "out", "plugins", "gst-1.16.2", "libgstmatroska.so"), False),
    ("gst-1.14.4", os.path.join(ROOT, "out", "plugins", "gst-1.14.4", "libgstmatroska.so"), False),
]


def read(path):
    with open(path, "rb") as f:
        return f.read()


def text(path):
    # the TV's shell must never see CRLF, whatever git did on checkout
    return read(path).replace(b"\r\n", b"\n")


def tar_gz(entries):
    """entries: list of (archive path, bytes or None for a directory, mode)"""
    raw = io.BytesIO()
    with tarfile.open(fileobj=raw, mode="w", format=tarfile.GNU_FORMAT) as tar:
        for name, data, mode in entries:
            info = tarfile.TarInfo(name)
            info.mtime = MTIME
            info.uname = info.gname = "root"
            info.mode = mode
            if data is None:
                info.type = tarfile.DIRTYPE
                tar.addfile(info)
            else:
                info.size = len(data)
                tar.addfile(info, io.BytesIO(data))
    out = io.BytesIO()
    with gzip.GzipFile(fileobj=out, mode="wb", mtime=MTIME, filename="") as gz:
        gz.write(raw.getvalue())
    return out.getvalue()


def ar(members):
    out = [b"!<arch>\n"]
    for name, data in members:
        out.append(b"%-16s%-12d%-6d%-6d%-8s%-10d`\n" % (name.encode(), MTIME, 0, 0, b"100644", len(data)))
        out.append(data)
        if len(data) % 2:
            out.append(b"\n")
    return b"".join(out)


def with_parents(files):
    """adds directory entries for every parent of the given archive paths"""
    dirs = set()
    for name, _, _ in files:
        parts = name.strip("./").split("/")[:-1]
        for i in range(1, len(parts) + 1):
            dirs.add("/".join(parts[:i]) + "/")
    return [(d, None, 0o755) for d in sorted(dirs)] + sorted(files)


def present_variants():
    out = []
    for vid, path, primary in VARIANTS:
        if os.path.isfile(path):
            out.append((vid, read(path), primary))
        elif primary:
            sys.exit("missing primary plugin %s - run build/build.sh first" % path)
        else:
            print("note: variant %s skipped (%s not found)" % (vid, path))
    return out


def filter_catalog(raw, present, col):
    """keep comment/blank lines and data rows whose variant (1-based column `col`)
    is in the present set, so we never advertise a variant we did not bundle."""
    keep = []
    for line in raw.decode("utf-8").splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            keep.append(line)
            continue
        parts = s.split()
        if len(parts) >= col and parts[col - 1] in present:
            keep.append(line)
    return ("\n".join(keep) + "\n").encode("utf-8")


def main():
    os.makedirs(OUT, exist_ok=True)
    app = json.loads(read(os.path.join(ROOT, "app", "appinfo.json")))
    app_id, version = app["id"], app["version"]

    variants = present_variants()
    present_ids = {vid for vid, _, _ in variants}
    primary_so = next(so for vid, so, primary in variants if primary)

    originals = filter_catalog(text(os.path.join(ROOT, "tv", "originals.md5")), present_ids, 2)
    vartab = filter_catalog(text(os.path.join(ROOT, "tv", "variants.tab")), present_ids, 1)

    def tv_file(name):
        return text(os.path.join(ROOT, "tv", name))

    # tv-scripts.tar.gz: a self-contained dir that ctl.sh can run from over SSH
    tv = []
    for f in ("ctl.sh", "autostart.sh", "install.sh", "uninstall.sh"):
        tv.append(("tv/" + f, tv_file(f), 0o755))
    tv.append(("tv/originals.md5", originals, 0o644))
    tv.append(("tv/variants.tab", vartab, 0o644))
    tv.append(("tv/VERSION", (version + "\n").encode(), 0o644))
    for vid, so, _ in variants:
        tv.append(("tv/plugins/%s/libgstmatroska.so" % vid, so, 0o755))
    scripts = tar_gz(with_parents(tv))

    # ipk
    base = "usr/palm/applications/%s/" % app_id
    files = []
    for f in sorted(os.listdir(os.path.join(ROOT, "app"))):
        p = os.path.join(ROOT, "app", f)
        data = read(p) if f.endswith(".png") else text(p)
        files.append((base + f, data, 0o644))
    for f in ("LICENSE", "THIRD-PARTY-NOTICES.md"):
        files.append((base + f, text(os.path.join(ROOT, f)), 0o644))

    payload = base + "payload/"
    for vid, so, _ in variants:
        files.append((payload + "plugins/%s/libgstmatroska.so" % vid, so, 0o755))
    files.append((payload + "originals.md5", originals, 0o644))
    files.append((payload + "variants.tab", vartab, 0o644))
    files.append((payload + "VERSION", (version + "\n").encode(), 0o644))
    files.append((payload + "ctl.sh", tv_file("ctl.sh"), 0o755))
    files.append((payload + "autostart.sh", tv_file("autostart.sh"), 0o755))

    pkginfo = {
        "app": app_id, "id": app_id, "loc_name": app["title"],
        "package_format_version": 2, "vendor": app["vendor"], "version": version,
    }
    files.append(("usr/palm/packages/%s/packageinfo.json" % app_id,
                  json.dumps(pkginfo, indent=2).encode() + b"\n", 0o644))
    data_tgz = tar_gz(with_parents(files))
    size = sum(len(d) for _, d, _ in files)
    control = (
        "Package: %s\nVersion: %s\nSection: misc\nPriority: optional\nArchitecture: all\n"
        "Installed-Size: %d\nMaintainer: %s\nDescription: %s\n"
        "webOS-Package-Format-Version: 2\nwebOS-Packager-Version: x.y.x\n"
        % (app_id, version, (size + 1023) // 1024, app["vendor"], app["appDescription"])
    ).encode()
    control_tgz = tar_gz([("control", control, 0o644)])
    ipk = ar([("debian-binary", b"2.0\n"), ("control.tar.gz", control_tgz), ("data.tar.gz", data_tgz)])
    ipk_name = "%s_%s_all.ipk" % (app_id, version)

    manifest = {
        "id": app_id,
        "version": version,
        "type": "web",
        "title": app["title"],
        "appDescription": app["appDescription"],
        "iconUri": "https://raw.githubusercontent.com/kewe87/webos-mkv-dolbyvision/main/app/largeIcon.png",
        "sourceUrl": REPO_URL,
        "rootRequired": True,
        "ipkUrl": ipk_name,
        "ipkHash": {"sha256": hashlib.sha256(ipk).hexdigest()},
    }

    outputs = {
        "libgstmatroska.so": primary_so,
        "tv-scripts.tar.gz": scripts,
        ipk_name: ipk,
        "%s.manifest.json" % app_id: json.dumps(manifest, indent=2).encode() + b"\n",
    }
    sums = []
    for name, data in outputs.items():
        with open(os.path.join(OUT, name), "wb") as f:
            f.write(data)
        sums.append("%s  %s\n" % (hashlib.sha256(data).hexdigest(), name))
    with open(os.path.join(OUT, "SHA256SUMS"), "w", newline="\n") as f:
        f.writelines(sums)
    print("variants bundled: %s" % ", ".join(sorted(present_ids)))
    print("".join(sums), end="")


if __name__ == "__main__":
    main()
