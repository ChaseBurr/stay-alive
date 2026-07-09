#!/bin/zsh
#
# install.sh — install stay-alive into your bin directory
#
# Usage:
#   ./install.sh                 # install to ~/.local/bin/stay-alive
#   ./install.sh /usr/local/bin  # install somewhere else

set -euo pipefail

SCRIPT_DIR=${0:a:h}
SOURCE="$SCRIPT_DIR/stay-alive.sh"

[[ -e $SOURCE ]] || { echo "error: source not found: $SOURCE" >&2; exit 1; }

# Normalize to an absolute, symlink-resolved path and refuse system dirs
BIN_DIR=${1:-$HOME/.local/bin}
BIN_DIR=${BIN_DIR:a}
case $BIN_DIR in
  /|/etc|/bin|/sbin|/usr/bin|/usr/sbin)
    echo "error: refusing to install into system directory '$BIN_DIR'" >&2; exit 1 ;;
esac

TARGET="$BIN_DIR/stay-alive"

mkdir -p "$BIN_DIR"
# -n: if TARGET exists as a symlink to a directory, replace it instead of
# creating the link inside the directory it points to
ln -sfn "$SOURCE" "$TARGET"
echo "Installed: $TARGET -> $SOURCE"

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  echo ""
  echo "note: $BIN_DIR is not on your PATH. Add this to your ~/.zshrc:"
  echo "  export PATH=\"$BIN_DIR:\$PATH\""
else
  echo "Run it with: stay-alive"
fi
