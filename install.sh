#!/bin/bash

# --- Git configuration ---
git config --global alias.co "checkout"
git config --global alias.br "branch"
git config --global alias.ci "commit"
git config --global alias.st "status"
git config --global user.email "mattkorwel@github.com"
git config --global user.name "matt korwel"
git config --global remote.origin.prune true
git config --global pull.rebase true
git config --global github.user "mattKorwel"
git config --global push.default "simple"
git config --global commit.gpgsign true

# --- Tooling installation (macOS/Homebrew) ---
if command -v brew &> /dev/null; then
  echo "📡 Installing core tools via Homebrew..."
  brew install starship mise zoxide fzf zsh-autosuggestions zsh-syntax-highlighting
else
  echo "⚠️ Homebrew not found. Please install it first: https://brew.sh"
fi

# --- Symlinks & Configuration ---
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔗 Setting up symlinks..."

# Backup existing .zshrc if it's not a symlink
if [[ -f ~/.zshrc && ! -L ~/.zshrc ]]; then
  mv ~/.zshrc ~/.zshrc.bak.$(date +%F_%T)
fi
ln -sf "$DOTFILES_DIR/.zshrc" ~/.zshrc

# Setup Mise Config
mkdir -p ~/.config/mise
ln -sf "$DOTFILES_DIR/.config/mise/config.toml" ~/.config/mise/config.toml

# Setup Starship Config
mkdir -p ~/.config
ln -sf "$DOTFILES_DIR/config.toml" ~/.config/starship.toml

# Setup Gemini Scripts
mkdir -p ~/.gemini-scripts
ln -sf "$DOTFILES_DIR/.gemini-scripts/gemini-functions.sh" ~/.gemini-scripts/gemini-functions.sh

echo "✅ Dotfiles installation complete! Please run: source ~/.zshrc"
