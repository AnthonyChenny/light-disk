#!/bin/bash
# Build the exact bundled NTFS-3G revision without depending on Homebrew at runtime.
set -euo pipefail
SRC_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TASK_BUILD="${1:?Usage: build-engine.sh /absolute/build/directory}"
mkdir -p "$TASK_BUILD"
[ ! -e "$TASK_BUILD/ntfs-3g-2026.9.28" ] || { echo "Use a fresh build directory; existing source will not be overwritten" >&2; exit 65; }
TASK_BUILD="$(cd "$TASK_BUILD" && pwd)"
ARCHIVE="$SRC_ROOT/ThirdParty/ntfs-3g-2026.9.28.tar.gz"
EXPECTED=8a75293f07bf40df5701d296de32a4cb0e46d6ae135abb4f41b438df9868a390
ACTUAL="$(/usr/bin/shasum -a 256 "$ARCHIVE" | /usr/bin/awk '{print $1}')"
[ "$EXPECTED" = "$ACTUAL" ] || { echo 'Source checksum mismatch' >&2; exit 65; }
[ -f /usr/local/include/fuse/fuse.h ] || { echo 'Install official macFUSE first' >&2; exit 69; }
# Build tools: autoconf, automake, libtool. They are build-time dependencies only.
/usr/bin/tar -xzf "$ARCHIVE" -C "$TASK_BUILD"
cd "$TASK_BUILD/ntfs-3g-2026.9.28"
/usr/bin/patch -p1 < "$SRC_ROOT/Packaging/ntfs-fd-device.patch"
./autogen.sh
ac_cv_header_libintl_h=no \
CFLAGS='-O2 -arch arm64 -mmacosx-version-min=15.4' \
CPPFLAGS='-I/usr/local/include' \
LDFLAGS='-L/usr/local/lib' \
FUSE_CFLAGS='-I/usr/local/include/fuse' \
FUSE_LIBS='-L/usr/local/lib -lfuse' \
./configure --prefix=/opt/qingpan-engine --with-fuse=external \
  --disable-shared --enable-static --disable-crypto --disable-ldconfig
make -j6
echo "Engine built at: $TASK_BUILD/ntfs-3g-2026.9.28/src"
