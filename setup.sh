#!/usr/bin/env bash
set -e # Exit immediately if any command fails

# Source the library
source "$(dirname "$0")/lib.sh"

# Detect OS
detect_os
echo "Detected OS: $MY_OS"

# Build the base dependencies array
PACKAGES=(neovim ripgrep fzf tree-sitter-cli stow tmux zsh)

# Clipboard Manager Detection
if [[ "$MY_OS" == "macos" ]]; then
    echo "macOS detected: Native clipboard (pbcopy/pbpaste) will be used."
elif [[ -z "$DISPLAY" && -z "$WAYLAND_DISPLAY" ]]; then
    echo "Headless/TTY/SSH session detected: Skipping desktop clipboard managers."
elif [[ "$XDG_SESSION_TYPE" == "wayland" ]] || [[ -n "$WAYLAND_DISPLAY" ]]; then
    echo "Wayland detected: Adding wl-clipboard..."
    PACKAGES+=(wl-clipboard)
else
    echo "X11 detected: Adding xclip..."
    PACKAGES+=(xclip)
fi

# Run installation
echo "Installing dependencies..."
install "${PACKAGES[@]}"

# Set ZSH as default
if [[ "$SHELL" != *"zsh"* ]]; then
    echo "Changing default shell..."
    ZSH_PATH=$(which zsh)
    # Only try to tee to /etc/shells if it's not already there
    if ! grep -q "$ZSH_PATH" /etc/shells; then
        echo "$ZSH_PATH" | sudo tee -a /etc/shells
    fi
    chsh -s "$ZSH_PATH"
fi

# Stow files
echo "Stowing dotfiles..."
cd "$(dirname "$0")" || exit
stow --verbose --target="$HOME" --adopt .

# Run the ZSH plugin installation script
PLUGIN_SCRIPT="$HOME/.config/zsh/install-plugins.sh"
if [[ -f "$PLUGIN_SCRIPT" ]]; then
    echo "Running ZSH plugin installer..."
    chmod +x "$PLUGIN_SCRIPT"
    "$PLUGIN_SCRIPT"
else
    echo "Note: ZSH plugin script not found at $PLUGIN_SCRIPT. Skipping."
fi

echo "Setup complete! Please log out and back in for ZSH changes to take effect."
