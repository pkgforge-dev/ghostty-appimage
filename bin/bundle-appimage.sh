#!/bin/sh

set -eux

ARCH="$(uname -m)"
GHOSTTY_VERSION="$(cat VERSION)"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-pkgforge-dev/ghostty-appimage}"

if printf '%s' "${GHOSTTY_VERSION}" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
	UPINFO_TAG="latest"
else
	UPINFO_TAG="tip"
fi

UPINFO="gh-releases-zsync|$(echo "${GITHUB_REPOSITORY}" | tr '/' '|')|${UPINFO_TAG}|Ghostty-*$ARCH.AppImage.zsync"
export UPINFO
export DEPLOY_OPENGL=1
export EXEC_WRAPPER=1
export URUNTIME_PRELOAD=1
export OUTNAME="Ghostty-${GHOSTTY_VERSION}-${ARCH}.AppImage"
export DESKTOP="./ghostty-${GHOSTTY_VERSION}/zig-out/share/applications/com.mitchellh.ghostty.desktop"
export ICON="./ghostty-${GHOSTTY_VERSION}/zig-out/share/icons/hicolor/256x256/apps/com.mitchellh.ghostty.png"

quick-sharun ./ghostty-${GHOSTTY_VERSION}/zig-out/bin/ghostty
cp -rf ./ghostty-${GHOSTTY_VERSION}/zig-out/share/* ./AppDir/share/

# zig build substitutes @GHOSTTY@ in dist/linux/app.desktop.in with the absolute build
# prefix, and the copy above drops the generated tree into AppDir verbatim, so the
# embedded entries carry a build path such as
# /__w/ghostty-appimage/ghostty-appimage/ghostty-<ver>/zig-out/bin/ghostty.
# Integration tools (AM, GearLever, Soar, AppImageLauncher) rewrite Exec/TryExec when they
# install the entry, so this is not user-visible breakage for them; normalize it anyway so
# the entry shipped inside the image is portable on its own.
for desktop_file in ./AppDir/*.desktop ./AppDir/share/applications/*.desktop; do
	[ -f "${desktop_file}" ] || continue
	sed -i -E \
		-e 's|^Exec=[^ ]*/|Exec=|' \
		-e 's|^TryExec=.*|TryExec=ghostty|' \
		"${desktop_file}"
done

quick-sharun --make-appimage

mkdir -p ./dist
mv -v ./*.AppImage* ./dist
