#!/bin/bash

CONFIG_DIR="$HOME/.config"
FINAL_DIR="$CONFIG_DIR/neogities"
TMP_DIR="$CONFIG_DIR/neogities_tmp"
GEM_DIR="$HOME/.local/share/gem/ruby/3.4.0"
BIN_DIR="$HOME/.local/bin"

rm -rf "$TMP_DIR" "$FINAL_DIR"
cp -r ../neogities "$TMP_DIR"
mv "$TMP_DIR" "$FINAL_DIR"

mkdir -p "$GEM_DIR"
cd "$FINAL_DIR"
bundle config set --local path "$GEM_DIR"
bundle install

mkdir -p "$BIN_DIR"
ln -sf "$FINAL_DIR/bin/neogities" "$BIN_DIR/neogities"
chmod +x "$FINAL_DIR/bin/neogities"
