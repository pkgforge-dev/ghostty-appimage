#!/bin/sh

set -e

export ARCH="$(uname -m)"

GHOSTTY_VERSION="1.0.1"

# Detect latest version numbers when jq is available.
if command -v jq >/dev/null 2>&1; then
	if [ "$1" = "latest" ]; then
		GHOSTTY_VERSION="$(
			curl -s https://api.github.com/repos/ghostty-org/ghostty/tags |
				jq '[.[] | select(.name != "tip") | .name | ltrimstr("v")] | sort_by(split(".") | map(tonumber)) | last'
		)"
	fi
fi

TMP_DIR="/tmp/ghostty-build"
APP_DIR="${TMP_DIR}/ghostty.AppDir"
PUB_KEY="RWQlAjJC23149WL2sEpT/l0QKy7hMIFhYdQOFy0Z7z7PbneUgvlsnYcV"
UPINFO="gh-releases-zsync|$(echo "${GITHUB_REPOSITORY:-no-user/no-repo}" | tr '/' '|')|latest|*$ARCH.AppImage.zsync"
APPDATA_FILE="${PWD}/assets/ghostty.appdata.xml"
DESKTOP_FILE="${PWD}/assets/ghostty.desktop"

rm -rf "${TMP_DIR}"

mkdir -p -- "${TMP_DIR}" "${APP_DIR}/usr" "${APP_DIR}/usr/lib" "${APP_DIR}/usr/share/metainfo"

cd "${TMP_DIR}"

wget -q "https://release.files.ghostty.org/${GHOSTTY_VERSION}/ghostty-${GHOSTTY_VERSION}.tar.gz"
wget -q "https://release.files.ghostty.org/${GHOSTTY_VERSION}/ghostty-${GHOSTTY_VERSION}.tar.gz.minisig"

minisign -V -m "ghostty-${GHOSTTY_VERSION}.tar.gz" -P "${PUB_KEY}" -s "ghostty-${GHOSTTY_VERSION}.tar.gz.minisig"

rm "ghostty-${GHOSTTY_VERSION}.tar.gz.minisig"

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

# bundle all libs
ldd ./usr/bin/ghostty | awk -F"[> ]" '{print $4}' | xargs -I {} cp --update=none -v {} ./usr/lib

# ld-linux contains x86-64 instead of x86_64. 
if [ "$ARCH" = "x86_64" ]; then
	if ! mv ./usr/lib/ld-linux-x86-64.so.2 ./ld-linux.so; then
		cp -v /lib64/ld-linux-x86-64.so.2 ./ld-linux.so
	fi
elif [ "$ARCH" = "aarch64" ]; then
	if ! mv ./usr/lib/ld-linux-aarch64.so.1 ./ld-linux.so; then
		cp -v /usr/lib/ld-linux-aarch64.so.1 ./ld-linux.so
	fi
else
	exit 1
fi

	

# Prepare AppImage -- Configure launcher script, metainfo and desktop file with icon.
cat <<'EOF' >./AppRun
#!/usr/bin/env sh

HERE="$(dirname "$(readlink -f "$0")")"

export TERM=xterm-256color
export GHOSTTY_RESOURCES_DIR="${HERE}/usr/share/ghostty"

exec "${HERE}"/ld-linux.so --library-path "${HERE}"/usr/lib "${HERE}"/usr/bin/ghostty "$@"
EOF

chmod +x AppRun

export VERSION="$(./AppRun --version 2>/dev/null | awk 'FNR==1 {print $2}')"
if [ -z "$VERSION" ]; then
	echo "ERROR: Could not get version from ghostty binary"
	exit 1
fi

cp "${APPDATA_FILE}" "usr/share/metainfo/com.mitchellh.ghostty.appdata.xml"

# Fix Gnome dock issues -- StartupWMClass attribute needs to be present.
cp "${DESKTOP_FILE}" "usr/share/applications/com.mitchellh.ghostty.desktop"
# WezTerm has this, it might be useful.
ln -s "com.mitchellh.ghostty.desktop" "usr/share/applications/ghostty.desktop"

ln -s "usr/share/applications/com.mitchellh.ghostty.desktop" .
ln -s "usr/share/icons/hicolor/256x256/apps/com.mitchellh.ghostty.png" .

cd "${TMP_DIR}"

# create app image
appimagetool -u "${UPINFO}" "${APP_DIR}"
