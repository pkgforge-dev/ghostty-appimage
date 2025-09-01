#!/bin/sh

set -eux

ARCH="$(uname -m)"
GHOSTTY_VERSION="$(cat VERSION)"
PUB_KEY="RWQlAjJC23149WL2sEpT/l0QKy7hMIFhYdQOFy0Z7z7PbneUgvlsnYcV"

export ADD_HOOKS="self-updater.bg.hook"
export UPINFO="gh-releases-zsync|$(echo "${GITHUB_REPOSITORY}" | tr '/' '|')|latest|Ghostty-*$ARCH.AppImage.zsync"
export URUNTIME_PRELOAD=1
export DEPLOY_OPENGL=1
export EXEC_WRAPPER=1

BUILD_ARGS="
	--summary all \
	-Doptimize=ReleaseFast \
	-Dcpu=baseline \
	-Dpie=true \
	-Demit-docs \
	-Dgtk-wayland=true \
	-Dgtk-x11=true"

if [ "${GHOSTTY_VERSION}" = "tip" ]; then
	wget "https://github.com/ghostty-org/ghostty/releases/download/tip/ghostty-source.tar.gz" -O "ghostty-${GHOSTTY_VERSION}.tar.gz"
	wget "https://github.com/ghostty-org/ghostty/releases/download/tip/ghostty-source.tar.gz.minisig" -O "ghostty-${GHOSTTY_VERSION}.tar.gz.minisig"
	GHOSTTY_VERSION="$(tar -tf "ghostty-${GHOSTTY_VERSION}.tar.gz" --wildcards "*zig.zon.txt" | awk -F'[-/]' '{print $2"-"$3}')"
	mv ghostty-tip.tar.gz "ghostty-${GHOSTTY_VERSION}.tar.gz"
	mv ghostty-tip.tar.gz.minisig "ghostty-${GHOSTTY_VERSION}.tar.gz.minisig"
else
	wget "https://release.files.ghostty.org/${GHOSTTY_VERSION}/ghostty-${GHOSTTY_VERSION}.tar.gz"
	wget "https://release.files.ghostty.org/${GHOSTTY_VERSION}/ghostty-${GHOSTTY_VERSION}.tar.gz.minisig"
fi

minisign -V -m "ghostty-${GHOSTTY_VERSION}.tar.gz" -P "${PUB_KEY}" -s "ghostty-${GHOSTTY_VERSION}.tar.gz.minisig"

tar -xzmf "ghostty-${GHOSTTY_VERSION}.tar.gz"

rm "ghostty-${GHOSTTY_VERSION}.tar.gz" \
	"ghostty-${GHOSTTY_VERSION}.tar.gz.minisig"

BUILD_ARGS="${BUILD_ARGS} -Dversion-string=${GHOSTTY_VERSION}"

#Fetch Zig Cache
if [ -f './nix/build-support/fetch-zig-cache.sh' ]; then
	ZIG_GLOBAL_CACHE_DIR=/tmp/offline-cache ./nix/build-support/fetch-zig-cache.sh
	BUILD_ARGS="${BUILD_ARGS} --system /tmp/offline-cache/p"
fi

# Build Ghostty with zig
(
	cd "ghostty-${GHOSTTY_VERSION}"
	zig build ${BUILD_ARGS}
)

export OUTNAME="Ghostty-${GHOSTTY_VERSION}-${ARCH}.AppImage"
export DESKTOP="./ghostty-${GHOSTTY_VERSION}/zig-out/share/applications/com.mitchellh.ghostty.desktop"
export ICON="./ghostty-${GHOSTTY_VERSION}/zig-out/share/icons/hicolor/256x256/apps/com.mitchellh.ghostty.png"

./quick-sharun ./ghostty-${GHOSTTY_VERSION}/zig-out/bin/ghostty
./uruntime2appimage

mkdir -p ./dist
mv -v ./*.AppImage* ./dist
