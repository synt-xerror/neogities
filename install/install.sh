#!/bin/bash

# -----------------------------
# Neogities Installation Script
# -----------------------------

# Variables
CONFIG_DIR="$HOME/.config"
TMP_DIR="$CONFIG_DIR/neogities_tmp"
FINAL_DIR="$CONFIG_DIR/neogities"
GEM_DIR="$HOME/.local/share/gem/ruby/3.4.0"
BIN_DIR="$HOME/.local/bin"

# Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
ORANGE="\033[33m"
BLUE="\033[0;34m"
R="\033[0m"

# Function to handle errors
error_exit() {
    echo -e "${RED}[ERROR]:${R} $1"
    exit 1
}

# Function to check system package
check_package() {
    command -v "$1" >/dev/null 2>&1 || {
        echo -e "${YELLOW}[WARNING]:${R} $1 is not installed. Please install it."
        return 1
    }
    return 0
}

echo "Starting Neogities installation..."

# -----------------------------
# Check dependencies
# -----------------------------
check_package git || error_exit "${ORANGE}Git${R} is required. Install ${ORANGE}git${R} and try again."
check_package ruby || error_exit "${RED}Ruby${R} is required. Install ${RED}Ruby${R} and try again."
check_package bundle || {
    echo "Bundler not found. Installing bundler..."
    gem install bundler || error_exit "Failed to install bundler."
}

# Check common system packages for native gems
NEEDED_PKGS=(gcc make libssl-dev libreadline-dev zlib1g-dev build-essential)
MISSING_PKGS=()
for pkg in "${NEEDED_PKGS[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    echo "Warning: The following system packages are missing and may be required for native gems:"
    printf " - %s\n" "${MISSING_PKGS[@]}"
    echo "Install them with your package manager (e.g., sudo apt install <pkg>) before continuing."
fi

# -----------------------------
# Clean previous installations
# -----------------------------
echo "Cleaning previous installations..."
rm -rf "$TMP_DIR" "$FINAL_DIR" || echo "Warning: Could not remove old directories. Check permissions."

# -----------------------------
# Clone repository
# -----------------------------
echo "Cloning repository..."
git clone https://github.com/synt-xerror/neogities "$TMP_DIR" || error_exit "Failed to clone repository. Check your internet connection or URL."

# -----------------------------
# Move to final directory
# -----------------------------
mv "$TMP_DIR" "$FINAL_DIR" || error_exit "Failed to move files to $FINAL_DIR. Check permissions."

# -----------------------------
# Configure Bundler
# -----------------------------
echo "Configuring Bundler..."
mkdir -p "$GEM_DIR" || echo "Warning: Cannot create $GEM_DIR. Check permissions."
bundle config set --local path "$GEM_DIR" || echo "Warning: Bundler configuration failed."

# -----------------------------
# Install Ruby gems
# -----------------------------
cd "$FINAL_DIR" || error_exit "Cannot access $FINAL_DIR."
echo "Installing Ruby gems..."
if ! bundle install; then
    echo "Error: bundle install failed."
    echo "Possible solutions:"
    echo "- Install missing system packages listed above."
    echo "- Verify your Ruby version matches the project's requirements."
    echo "- Try running 'bundle install' manually for more details."
    exit 1
fi

# -----------------------------
# Create binary link
# -----------------------------
mkdir -p "$BIN_DIR" || echo "Warning: Could not create $BIN_DIR. Check permissions."
if [ -f "$FINAL_DIR/bin/neogities" ]; then
    ln -sf "$FINAL_DIR/bin/neogities" "$BIN_DIR/neogities"
    chmod +x "$FINAL_DIR/bin/neogities"
else
    echo "Warning: $FINAL_DIR/bin/neogities not found. Installation may be incomplete."
fi

echo "Installation complete!"
echo "Make sure $BIN_DIR is in your PATH, for example:"
echo 'export PATH="$HOME/.local/bin:$PATH"'
echo "Then you can run 'neogities' directly from the terminal."
