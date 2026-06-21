#!/usr/bin/env bash

# Source the library
source "$(dirname "$0")/lib.sh"

# Detect OS
detect_os
echo "Detected OS: $MY_OS"

# Run installation
echo "Installing dependencies..."
install neovim ripgrep fzf tree-sitter-cli stow tmux zsh

# Set ZSH as default
if [[ "$SHELL" != *"zsh"* ]]; then
    echo "Changing default shell..."
    ZSH_PATH=$(which zsh)
    grep -q "$ZSH_PATH" /etc/shells || echo "$ZSH_PATH" | sudo tee -a /etc/shells
    chsh -s "$ZSH_PATH"
fi

# Stow files
echo "Stowing dotfiles..."
cd "$(dirname "$0")" || exit
stow --verbose --target="$HOME" --adopt .
