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
BIN_DIR=${1:-$HOME/.local/bin}
TARGET="$BIN_DIR/stay-alive"

mkdir -p "$BIN_DIR"
ln -sf "$SOURCE" "$TARGET"
echo "Installed: $TARGET -> $SOURCE"

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  echo ""
  echo "note: $BIN_DIR is not on your PATH. Add this to your ~/.zshrc:"
  echo "  export PATH=\"$BIN_DIR:\$PATH\""
else
  echo "Run it with: stay-alive"
fi
