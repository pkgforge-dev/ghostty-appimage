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

# Ghostty's build substitutes @GHOSTTY@ in app.desktop.in / dbus.service.in with the
# absolute path of the build prefix, and quick-sharun copies the entry into $APPDIR
# verbatim. Integration tools that extract the entry (e.g. appimaged) then get a
# TryExec that cannot exist, so the desktop environment hides it or fails to launch.
# Reset those paths to the binary name the README documents and drop DBus activation,
# which cannot work from an AppImage (quick-sharun removes DBusActivatable from the
# top level entry; the copy below would bring it back).
for desktop_file in ./AppDir/*.desktop ./AppDir/share/applications/*.desktop; do
	[ -f "${desktop_file}" ] || continue
	sed -i -E \
		-e 's|^Exec=[^ ]*/|Exec=|' \
		-e 's|^TryExec=.*|TryExec=ghostty|' \
		-e '/^DBusActivatable=/d' \
		"${desktop_file}"
done
rm -rf ./AppDir/share/dbus-1

quick-sharun --make-appimage

mkdir -p ./dist
mv -v ./*.AppImage* ./dist
