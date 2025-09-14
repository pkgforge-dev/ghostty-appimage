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

ZIG_VERSION="${ZIG_VERSION:-0.13.0}"
PANDOC_VERSION="$(get_latest_gh_release 'jgm/pandoc')"
MINISIGN_VERSION="$(get_latest_gh_release 'jedisct1/minisign')"

GH_BASE="https://github.com"
GH_USER_CONTENT="https://raw.githubusercontent.com"

PANDOC_BASE="${GH_BASE}/jgm/pandoc/releases/download/${PANDOC_VERSION}"
MINISIGN_URL="${GH_BASE}/jedisct1/minisign/releases/download/${MINISIGN_VERSION}/minisign-${MINISIGN_VERSION}-linux.tar.gz"
ZIG_URL="https://ziglang.org/download/${ZIG_VERSION}/zig-linux-${ARCH}-${ZIG_VERSION}.tar.xz"

DEBLOATED_PKGS="${GH_USER_CONTENT}/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/get-debloated-pkgs.sh"
SHARUN="${GH_USER_CONTENT}/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/quick-sharun.sh"
URUNTIME="${GH_USER_CONTENT}/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/uruntime2appimage.sh"

case "${ARCH}" in
"x86_64")
	PANDOC_URL="${PANDOC_BASE}/pandoc-${PANDOC_VERSION}-linux-amd64.tar.gz"
	;;
"aarch64")
	PANDOC_URL="${PANDOC_BASE}/pandoc-${PANDOC_VERSION}-linux-arm64.tar.gz"
	;;
*)
	echo "Unsupported ARCH: '${ARCH}'"
	exit 1
	;;
esac

# Install Debloated Pkgs
wget "${DEBLOATED_PKGS}" -O /tmp/get-debloated-pkgs.sh
chmod a+x /tmp/get-debloated-pkgs.sh
sh /tmp/get-debloated-pkgs.sh --add-opengl --prefer-nano gtk4-mini libxml2-mini

# Download & install other dependencies
# zig: https://ziglang.org
rm -rf /opt/zig*
unlink /usr/local/bin/zig || true
wget "${ZIG_URL}" -O /tmp/zig-linux.tar.xz
tar -xJf /tmp/zig-linux.tar.xz -C /opt
ln -s "/opt/zig-linux-${ARCH}-${ZIG_VERSION}/zig" /usr/local/bin/zig

# minisign: https://github.com/jedisct1/minisign
rm -rf /usr/local/bin/minisign
wget "${MINISIGN_URL}" -O /tmp/minisign-linux.tar.gz
tar -xzf /tmp/minisign-linux.tar.gz -C /tmp
mv /tmp/minisign-linux/"${ARCH}"/minisign /usr/local/bin

# pandoc: https://github.com/jgm/pandoc
rm -rf /usr/local/bin/pandoc*
wget "${PANDOC_URL}" -O /tmp/pandoc-linux.tar.gz
tar -xzf /tmp/pandoc-linux.tar.gz -C /tmp
mv /tmp/"pandoc-${PANDOC_VERSION}"/bin/* /usr/local/bin

# Sharun
wget "${SHARUN}" -O quick-sharun
chmod +x quick-sharun

# Sharun
wget "${URUNTIME}" -O uruntime2appimage
chmod +x uruntime2appimage

# Cleanup
pacman -Scc --noconfirm

rm -rf \
	/tmp/appimagetool.AppImage \
	/tmp/minisign-linux* \
	/tmp/zig-linux.tar.xz \
	/tmp/pandoc* \
	/tmp/*.pkg.tar.zst
