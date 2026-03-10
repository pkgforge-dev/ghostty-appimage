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
	echo "${GHOSTTY_VERSION}" >VERSION
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

# Configure Zig: https://ziglang.org
ZIG_VERSION="$(cat "ghostty-${GHOSTTY_VERSION}/build.zig.zon" | grep ".minimum_zig_version" | cut -d'"' -f2)"
CURRENT_ZIG_VERSION=$(zig version 2>/dev/null || true)
if [ "$CURRENT_ZIG_VERSION" != "$ZIG_VERSION" ]; then
	echo "Installing Zig ${ZIG_VERSION}..."
	ZIG_PACKAGE_NAME="zig-${ARCH}-linux-${ZIG_VERSION}"
	ZIG_URL="https://ziglang.org/download/${ZIG_VERSION}/${ZIG_PACKAGE_NAME}.tar.xz"
	rm -rf /opt/zig*
	unlink /usr/local/bin/zig || true
	wget "${ZIG_URL}" -O /tmp/zig-linux.tar.xz
	tar -xJf /tmp/zig-linux.tar.xz -C /opt
	ln -s "/opt/${ZIG_PACKAGE_NAME}/zig" /usr/local/bin/zig
	echo "Zig ${ZIG_VERSION} installed successfully"
else
	echo "Zig ${ZIG_VERSION} is already installed, skipping installation"
fi

(
	cd "ghostty-${GHOSTTY_VERSION}"
	ZIG_GLOBAL_CACHE_DIR=/tmp/offline-cache ./nix/build-support/fetch-zig-cache.sh
	zig build ${BUILD_ARGS}
)
