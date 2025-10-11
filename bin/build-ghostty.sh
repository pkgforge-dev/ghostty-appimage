#!/bin/sh

set -eux

ARCH="$(uname -m)"
GHOSTTY_VERSION="$(cat VERSION)"
PUB_KEY="RWQlAjJC23149WL2sEpT/l0QKy7hMIFhYdQOFy0Z7z7PbneUgvlsnYcV"

rm -rf AppDir dist ghostty-*

BUILD_ARGS="
	-Dcpu=baseline \
	-Doptimize=ReleaseFast \
	-Dpie=true \
    --system /tmp/offline-cache/p \
    -Dgtk-wayland=true \
    -Dgtk-x11=true \
    -Demit-docs=false \
    -Dstrip=true"

if [ "${GHOSTTY_VERSION}" = "tip" ]; then
	export UPINFO="gh-releases-zsync|$(echo "${GITHUB_REPOSITORY}" | tr '/' '|')|tip|Ghostty-*$ARCH.AppImage.zsync"
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

(
	cd "ghostty-${GHOSTTY_VERSION}"
	ZIG_GLOBAL_CACHE_DIR=/tmp/offline-cache ./nix/build-support/fetch-zig-cache.sh
	zig build ${BUILD_ARGS}
)
