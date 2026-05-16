# Troubleshooting

## `Error opening terminal: xterm-ghostty` when using `sudo`

Ghostty sets `TERM=xterm-ghostty`, but the terminfo entry is bundled inside the AppImage and is not installed on the host system. When you run a terminal application via `sudo` (e.g., `sudo aptitude`, `sudo vim`), the root environment cannot find the terminfo entry and fails with:

```
Error opening terminal: xterm-ghostty.
```

**Fix:** extract the terminfo entry from the AppImage and install it system-wide.

```bash
# Extract the terminfo entry into a temporary directory
tmpdir=$(mktemp -d /tmp/ghostty-appimage.XXXXXX)
(cd "$tmpdir" && /path/to/Ghostty.AppImage --appimage-extract share/terminfo/x/xterm-ghostty)

# Install for the current user
mkdir -p ~/.local/share/terminfo/x
cp "$tmpdir/squashfs-root/share/terminfo/x/xterm-ghostty" ~/.local/share/terminfo/x/

# Install system-wide so root and sudo can find it
sudo mkdir -p /usr/share/terminfo/x
sudo cp "$tmpdir/squashfs-root/share/terminfo/x/xterm-ghostty" /usr/share/terminfo/x/

# Clean up
rm -rf "$tmpdir"
```

This only needs to be done once, or again after upgrading to a new AppImage release.
