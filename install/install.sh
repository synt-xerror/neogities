#!/bin/bash
CONFIG_DIR="$HOME/.config"
TMP_DIR="$CONFIG_DIR/neogities_tmp"
FINAL_DIR="$CONFIG_DIR/neogities"
GEM_DIR="$HOME/.local/share/gem/ruby/3.4.0"
BIN_DIR="$HOME/.local/bin"

echo "Installing Neogities..."
rm -rf "$TMP_DIR"
rm -rf "$FINAL_DIR"
sleep 1

git clone https://github.com/synt-xerror/neogities "$TMP_DIR"

# mover para a pasta final
mv "$TMP_DIR" "$FINAL_DIR"

bundle config set --local path "$GEM_DIR"

cd "$FINAL_DIR" || exit
bundle install

mkdir -p "$BIN_DIR"
ln -sf "$FINAL_DIR/bin/neogities" "$BIN_DIR/neogities"
chmod +x "$FINAL_DIR/bin/neogities"

echo "Installation complete! Make sure $BIN_DIR is in your PATH."
