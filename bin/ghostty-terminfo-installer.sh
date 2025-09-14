#!/bin/sh
# vim: ft=bash sw=2 ts=2 et

set -eu

APPDIR=${APPDIR:-$SHARUN_DIR}
terminfo_exists=true
terminfo_install=false

terminfo_files="share/terminfo/g/ghostty share/terminfo/x/xterm-ghostty"

for f in $terminfo_files; do
	if [ ! -e "/usr/$f" ]; then
		terminfo_exists=false
	fi
done

if [ "$terminfo_exists" = false ]; then
	echo "Terminfo configuration missing, advertised features might not be available"
	echo "Refer: https://ghostty.org/docs/help/terminfo"
else
	exit 0
fi

printf "Would you like to configure terminfo files [y/N]: "
read prompt

prompt=$(echo "$prompt" | tr '[:upper:]' '[:lower:]')

case "$prompt" in
yes | y)
	terminfo_install=true
	;;
no | n)
	terminfo_install=false && exit 0
	;;
*)
	echo "Invalid response" && exit 1
	;;
esac

if [ "$terminfo_install" = true ]; then
	for f in $terminfo_files; do
		(
			cd $APPDIR
			sudo mkdir -p "/usr/local/$(echo "$f" | rev | cut -d'/' -f2- | rev)"
			sudo cp -rpv ./$f /usr/local/$f
		)
	done
fi
