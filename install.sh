#!/bin/bash

set -e

echo "🚀 Starting Full Dotfiles Installation..."

# --- 1. Tooling installation ---
if [[ "$OSTYPE" == "darwin"* ]]; then
  if command -v brew &> /dev/null; then
    echo "📡 Installing core tools via Homebrew (macOS)..."
    brew install starship mise zoxide fzf zsh-autosuggestions zsh-syntax-highlighting gh
  else
    echo "⚠️ Homebrew not found. Skipping Homebrew tool installation."
  fi
else
  # Assume Linux / Ubuntu / WSL
  echo "📡 Checking/Installing core tools (Linux/WSL)..."
  
  # Add GitHub CLI repository if needed
  if ! command -v gh &> /dev/null; then
    echo "📦 Adding GitHub CLI repository..."
    (type -p wget >/dev/null || (sudo apt update && sudo apt-get install wget -y)) \
    && sudo mkdir -p -m 755 /etc/apt/keyrings \
    && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  fi

  sudo apt update
  sudo apt install -y zsh fzf zoxide zsh-autosuggestions zsh-syntax-highlighting gh wslu
  
  # Install Starship
  if ! command -v starship &> /dev/null; then
    echo "🚀 Installing Starship..."
    mkdir -p "$HOME/.local/bin"
    curl -sS https://starship.rs/install.sh | sh -s -- -y --bin-dir "$HOME/.local/bin"
  fi
  
  # Install Mise
  if [[ ! -f "$HOME/.local/bin/mise" ]]; then
    echo "🚀 Installing Mise..."
    curl https://mise.jdx.dev/install.sh | sh
  fi

  # Trust and Install versions via Mise
  echo "📡 Configuring Mise..."
  export MISE_YES=1
  "$HOME/.local/bin/mise" trust "$DOTFILES_DIR"
  "$HOME/.local/bin/mise" install --dir "$DOTFILES_DIR"
fi

# --- 2. Symlinks & Configuration ---
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔗 Setting up symlinks from: $DOTFILES_DIR"

# ZSH Configuration
if [[ -f ~/.zshrc && ! -L ~/.zshrc ]]; then
  mv ~/.zshrc ~/.zshrc.bak.$(date +%F_%T)
fi
ln -sf "$DOTFILES_DIR/.zshrc" ~/.zshrc

# Git Configuration
if [[ ! -f ~/.gitconfig ]]; then
  touch ~/.gitconfig
fi
if ! grep -q ".gitconfig.shared" ~/.gitconfig; then
  echo "📝 Including shared git config in ~/.gitconfig..."
  git config --global include.path "$DOTFILES_DIR/.gitconfig.shared"
fi

# App-specific Configs
mkdir -p ~/.config/mise
ln -sf "$DOTFILES_DIR/.config/mise/config.toml" ~/.config/mise/config.toml

mkdir -p ~/.config
ln -sf "$DOTFILES_DIR/starship.toml" ~/.config/starship.toml

# Gemini Configuration
mkdir -p ~/.gemini
if [[ -f ~/.gemini/settings.json && ! -L ~/.gemini/settings.json ]]; then
  mv ~/.gemini/settings.json ~/.gemini/settings.json.bak.$(date +%F_%T)
fi
ln -sf "$DOTFILES_DIR/.gemini/settings.json" ~/.gemini/settings.json

# Gemini Scripts
mkdir -p ~/.gemini-scripts
ln -sf "$DOTFILES_DIR/.gemini-scripts/gemini-functions.sh" ~/.gemini-scripts/gemini-functions.sh

# Set Zsh as default shell if it isn't already
if [ "$SHELL" != "$(which zsh)" ]; then
  echo "🐚 Setting Zsh as default shell..."
  sudo chsh -s "$(which zsh)" "$USER"
fi

echo "✅ Dotfiles installation complete!"
