#!/bin/sh

set -e

GHOSTTY_VERSION="1.0.1"
TMP_DIR="/tmp/ghostty-build"
APP_DIR="${TMP_DIR}/ghostty.AppDir"
PUB_KEY="RWQlAjJC23149WL2sEpT/l0QKy7hMIFhYdQOFy0Z7z7PbneUgvlsnYcV"

rm -rf "${TMP_DIR}"

mkdir -p -- "${TMP_DIR}" "${APP_DIR}/usr"

cd "${TMP_DIR}"

wget -q "https://release.files.ghostty.org/${GHOSTTY_VERSION}/ghostty-${GHOSTTY_VERSION}.tar.gz"
wget -q "https://release.files.ghostty.org/${GHOSTTY_VERSION}/ghostty-${GHOSTTY_VERSION}.tar.gz.minisig"

minisign -V -m "ghostty-${GHOSTTY_VERSION}.tar.gz" -P "${PUB_KEY}" -s "ghostty-${GHOSTTY_VERSION}.tar.gz.minisig"

rm ghostty-${GHOSTTY_VERSION}.tar.gz.minisig

tar -xzmf "ghostty-${GHOSTTY_VERSION}.tar.gz"

rm "ghostty-${GHOSTTY_VERSION}.tar.gz"

cd "${TMP_DIR}/ghostty-${GHOSTTY_VERSION}"

sed -i 's/linkSystemLibrary2("bzip2", dynamic_link_opts)/linkSystemLibrary2("bz2", dynamic_link_opts)/' build.zig

# Fetch Zig Cache
ZIG_GLOBAL_CACHE_DIR=/tmp/offline-cache ./nix/build-support/fetch-zig-cache.sh

# Build Ghostty with zig
zig build \
  --summary all \
  --prefix "${APP_DIR}/usr" \
  --system /tmp/offline-cache/p \
  -Doptimize=ReleaseFast \
  -Dcpu=baseline \
  -Dpie=true \
  -Demit-docs \
  -Dversion-string="${GHOSTTY_VERSION}"

cd "${APP_DIR}"

# prep appimage
printf '#!/bin/sh\n\nexec "$(dirname "$(readlink -f "$0")")/usr/bin/ghostty"\n' | tee AppRun > /dev/null
chmod +x AppRun
ln -s usr/share/applications/com.mitchellh.ghostty.desktop
ln -s usr/share/icons/hicolor/256x256/apps/com.mitchellh.ghostty.png

cd "${TMP_DIR}"
# create app image
ARCH=x8_64 appimagetool "${APP_DIR}"