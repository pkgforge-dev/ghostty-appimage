#!/bin/sh

set -e

preload_lib() {
	[ -f "$1" ] && [ -d "$2" ] && mv "$1" "$2"
}

export ARCH="$(uname -m)"
export APPIMAGE_EXTRACT_AND_RUN=1

GHOSTTY_VERSION="$(cat VERSION)"
TMP_DIR="/tmp/ghostty-build"
APP_DIR="${TMP_DIR}/ghostty.AppDir"
PUB_KEY="RWQlAjJC23149WL2sEpT/l0QKy7hMIFhYdQOFy0Z7z7PbneUgvlsnYcV"
UPINFO="gh-releases-zsync|$(echo "${GITHUB_REPOSITORY:-no-user/no-repo}" | tr '/' '|')|latest|*$ARCH.AppImage.zsync"
APPDATA_FILE="${PWD}/assets/ghostty.appdata.xml"
DESKTOP_FILE="${PWD}/assets/ghostty.desktop"
LIB4BN="https://raw.githubusercontent.com/VHSgunzo/sharun/refs/heads/main/lib4bin"
BUILD_ARGS="
	--summary all \
	--prefix ${APP_DIR} \
	-Doptimize=ReleaseFast \
	-Dcpu=baseline \
	-Dpie=true \
	-Demit-docs \
	-Dgtk-wayland=true \
	-Dgtk-x11=true"
# --system /tmp/offline-cache/p \

rm -rf "${TMP_DIR}"

mkdir -p -- "${TMP_DIR}" "${APP_DIR}/share/metainfo" "${APP_DIR}/shared/preload"

cd "${TMP_DIR}"

if [ $GHOSTTY_VERSION == "tip" ]; then
	BUILD_DIR="ghostty-source"
	wget "https://github.com/ghostty-org/ghostty/releases/download/tip/ghostty-source.tar.gz" -O ghostty-${GHOSTTY_VERSION}.tar.gz
	wget "https://github.com/ghostty-org/ghostty/releases/download/tip/ghostty-source.tar.gz.minisig" -O ghostty-${GHOSTTY_VERSION}.tar.gz.minisig
else
	BUILD_DIR="ghostty-${GHOSTTY_VERSION}"
	BUILD_ARGS="$BUILD_ARGS -Dversion-string=${GHOSTTY_VERSION}"
	wget "https://release.files.ghostty.org/${GHOSTTY_VERSION}/ghostty-${GHOSTTY_VERSION}.tar.gz"
	wget "https://release.files.ghostty.org/${GHOSTTY_VERSION}/ghostty-${GHOSTTY_VERSION}.tar.gz.minisig"
fi

minisign -V -m "ghostty-${GHOSTTY_VERSION}.tar.gz" -P "${PUB_KEY}" -s "ghostty-${GHOSTTY_VERSION}.tar.gz.minisig"

rm "ghostty-${GHOSTTY_VERSION}.tar.gz.minisig"

tar -xzmf "ghostty-${GHOSTTY_VERSION}.tar.gz"

rm "ghostty-${GHOSTTY_VERSION}.tar.gz"

cd "${TMP_DIR}/${BUILD_DIR}"

# Fetch Zig Cache
# TODO: Revert cache once upstream fixes fetch
# ZIG_GLOBAL_CACHE_DIR=/tmp/offline-cache ./nix/build-support/check-zig-cache.sh

# Build Ghostty with zig
zig build ${BUILD_ARGS}

cd "${APP_DIR}"

cp "${APPDATA_FILE}" "share/metainfo/com.mitchellh.ghostty.appdata.xml"
cp "${DESKTOP_FILE}" "share/applications/com.mitchellh.ghostty.desktop"

ln -s "com.mitchellh.ghostty.desktop" "share/applications/ghostty.desktop"
ln -s "share/applications/com.mitchellh.ghostty.desktop" .
ln -s "share/icons/hicolor/256x256/apps/com.mitchellh.ghostty.png" .

# bundle all libs
wget "$LIB4BN" -O ./lib4bin
chmod +x ./lib4bin
xvfb-run -a -- ./lib4bin -p -v -e -s -k ./bin/ghostty /usr/lib/libEGL*

# Prepare AppImage -- Configure launcher script, metainfo and desktop file with icon.
echo 'GHOSTTY_RESOURCES_DIR=${SHARUN_DIR}/share/ghostty' >>./.env
echo 'unset ARGV0' >>./.env

preload_lib "shared/lib/gdk-pixbuf-2.0/2.10.0/loaders/libpixbufloader_svg.so" "shared/preload"

[ -d 'shared/lib/gdk-pixbuf-2.0' ] && rm -rf shared/lib/gdk-pixbuf-2.0

ln -s ./bin/ghostty ./AppRun
./sharun -g

export VERSION="$(./AppRun --version | awk 'FNR==1 {print $2}')"
if [ -z "$VERSION" ]; then
	echo "ERROR: Could not get version from ghostty binary"
	exit 1
fi

cd "${TMP_DIR}"

# create app image
appimagetool -u "${UPINFO}" "${APP_DIR}"
