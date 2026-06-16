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

# GCC 15+ compiles glibc crt startup objects with .sframe sections that use R_X86_64_PC64
# relocations. Zig's self-hosted linker doesn't support this relocation type, causing
# build-time helpers (e.g. ghostty-build-data) to fail. Strip .sframe and its associated
# relocation section from the affected objects so the linker never encounters them.
for _crt in /usr/lib/crt1.o /usr/lib/Scrt1.o /usr/lib/rcrt1.o; do
	[ -f "$_crt" ] && objcopy --remove-section .sframe --remove-section .rela.sframe "$_crt"
done

ARCH="$(uname -m)"

MINISIGN_VERSION="$(get_latest_gh_release 'jedisct1/minisign')"

GH_BASE="https://github.com"

MINISIGN_URL="${GH_BASE}/jedisct1/minisign/releases/download/${MINISIGN_VERSION}/minisign-${MINISIGN_VERSION}-linux.tar.gz"

# Install Debloated Pkgs (get-debloated-pkgs provided by anylinux-setup-action)
get-debloated-pkgs --add-common --prefer-nano

# minisign: https://github.com/jedisct1/minisign
rm -rf /usr/local/bin/minisign
wget "${MINISIGN_URL}" -O /tmp/minisign-linux.tar.gz
tar -xzf /tmp/minisign-linux.tar.gz -C /tmp
mv /tmp/minisign-linux/"${ARCH}"/minisign /usr/local/bin

# Cleanup
pacman -Scc --noconfirm

rm -rf \
	/tmp/appimagetool.AppImage \
	/tmp/minisign-linux* \
	/tmp/zig-linux.tar.xz
