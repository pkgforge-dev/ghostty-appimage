#!/bin/sh

set -e

export ARCH="$(uname -m)"
export APPIMAGE_EXTRACT_AND_RUN=1

GHOSTTY_VERSION="$(cat VERSION)"
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

sed -i 's/linkSystemLibrary2("bzip2", dynamic_link_opts)/linkSystemLibrary2("bz2", dynamic_link_opts)/' src/build/SharedDeps.zig

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

# deploy opengl manually 💀
cp -vPn /usr/lib/libdrm_*             ./usr/lib
cp -vPn /usr/lib/libdrm.so*           ./usr/lib
cp -vPn /usr/lib/libedit.so*          ./usr/lib
cp -vPn /usr/lib/libEGL.so*           ./usr/lib
cp -vPn /usr/lib/libelf.so*           ./usr/lib
cp -vPn /usr/lib/libelf-*             ./usr/lib
cp -vPn /usr/lib/libgallium-*         ./usr/lib
cp -vPn /usr/lib/libglapi.so*         ./usr/lib
cp -vPn /usr/lib/libGLdispatch.so*    ./usr/lib
cp -vPn /usr/lib/libGL.so*            ./usr/lib
cp -vPn /usr/lib/libGLX_indirect.so*  ./usr/lib
cp -vPn /usr/lib/libGLX_mesa.so*      ./usr/lib
cp -vPn /usr/lib/libGLX.so*           ./usr/lib
cp -vPn /usr/lib/libLLVM.so*          ./usr/lib
cp -vPn /usr/lib/libX11.so*           ./usr/lib
cp -vPn /usr/lib/libSPIRV-Tools.so*   ./usr/lib
cp -vPn /usr/lib/libncursesw.so*      ./usr/lib
cp -vPn /usr/lib/libpciaccess.so*     ./usr/lib
cp -vPn /usr/lib/libsensors.so*       ./usr/lib
cp -vPn /usr/lib/libX11-xcb.so*       ./usr/lib
cp -vPn /usr/lib/libxcb-dri3.so*      ./usr/lib
cp -vPn /usr/lib/libxcb-glx.so*       ./usr/lib
cp -vPn /usr/lib/libxcb-present.so*   ./usr/lib
cp -vPn /usr/lib/libxcb-randr.so*     ./usr/lib
cp -vPn /usr/lib/libxcb-sync.so*      ./usr/lib
cp -vPn /usr/lib/libxcb-xfixes.so*    ./usr/lib
cp -vPn /usr/lib/libxshmfence.so*     ./usr/lib
cp -vPn /usr/lib/libXxf86vm.so*       ./usr/lib

# ld-linux contains x86-64 instead of x86_64
case "${ARCH}" in
"x86_64")
	ld_linux="ld-linux-x86-64.so.2"
	;;
"aarch64")
	ld_linux="ld-linux-aarch64.so.1"
	;;
*)
	echo "Unsupported ARCH: '${ARCH}'"
	exit 1
	;;
esac

cp -v /usr/lib/libpthread.so.0 ./usr/lib

if ! mv ./usr/lib/${ld_linux} ./ld-linux.so; then
	cp -v /usr/lib/${ARCH}-linux-gnu/${ld_linux} ./ld-linux.so
fi

strip -s -R .comment --strip-unneeded ./usr/lib/lib*

# Prepare AppImage -- Configure launcher script, metainfo and desktop file with icon.
cat <<'EOF' >./AppRun
#!/usr/bin/env sh

HERE="$(dirname "$(readlink -f "$0")")"
unset ARGV0
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
