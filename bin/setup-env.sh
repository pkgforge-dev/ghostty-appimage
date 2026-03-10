#!/bin/sh

set -eux

get_latest_gh_release() {

	gh_ref="${1}"
	curl -s "https://api.github.com/repos/${gh_ref}/releases/latest" | jq -r .tag_name
}

# Update & install OS base dependencies
buildDeps="base-devel freetype2 oniguruma wget mesa file zsync appstream xorg-server-xvfb patchelf binutils strace git jq"
ghosttyDeps="gtk4 libadwaita gtk4-layer-shell"
rm -rf "/usr/share/libalpm/hooks/package-cleanup.hook"
pacman -Syuq --needed --noconfirm --noprogressbar ${buildDeps} ${ghosttyDeps}

ARCH="$(uname -m)"

MINISIGN_VERSION="$(get_latest_gh_release 'jedisct1/minisign')"

GH_BASE="https://github.com"
GH_USER_CONTENT="https://raw.githubusercontent.com"

MINISIGN_URL="${GH_BASE}/jedisct1/minisign/releases/download/${MINISIGN_VERSION}/minisign-${MINISIGN_VERSION}-linux.tar.gz"

DEBLOATED_PKGS="${GH_USER_CONTENT}/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/get-debloated-pkgs.sh"
SHARUN="${GH_USER_CONTENT}/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/quick-sharun.sh"

# Install Debloated Pkgs
wget "${DEBLOATED_PKGS}" -O /tmp/get-debloated-pkgs.sh
chmod a+x /tmp/get-debloated-pkgs.sh
sh /tmp/get-debloated-pkgs.sh --add-opengl --prefer-nano gtk4-mini libxml2-mini gdk-pixbuf2-mini librsvg-mini

# minisign: https://github.com/jedisct1/minisign
rm -rf /usr/local/bin/minisign
wget "${MINISIGN_URL}" -O /tmp/minisign-linux.tar.gz
tar -xzf /tmp/minisign-linux.tar.gz -C /tmp
mv /tmp/minisign-linux/"${ARCH}"/minisign /usr/local/bin

# Sharun
wget "${SHARUN}" -O quick-sharun
chmod +x quick-sharun

# Cleanup
pacman -Scc --noconfirm

rm -rf \
	/tmp/appimagetool.AppImage \
	/tmp/minisign-linux* \
	/tmp/zig-linux.tar.xz
