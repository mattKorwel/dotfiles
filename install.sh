#!/bin/bash

set -e

# --- Configuration ---
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRIVATE_REPO_URL="https://github.com/mattkorwel/dotfiles-private.git"
PRIVATE_DIR="$HOME/dev/dotfiles-private"

echo "🚀 Starting Robust Dotfiles Installation..."

# --- Helper Functions ---

pkg_install() {
  local pkg=$1
  if [[ "$OSTYPE" == "darwin"* ]]; then
    if command -v brew &> /dev/null; then
      brew install "$pkg"
    fi
  else
    sudo apt-get install -y "$pkg"
  fi
}

ensure_zsh() {
  if ! command -v zsh &> /dev/null; then
    echo "🐚 Zsh not found. Installing..."
    pkg_install zsh
  fi
  
  if [[ "$SHELL" != "$(which zsh)" ]]; then
    echo "🐚 Setting Zsh as default shell..."
    sudo chsh -s "$(which zsh)" "$USER"
  fi
}

# --- 1. Core Tooling Installation ---

if [[ "$OSTYPE" == "darwin"* ]]; then
  if ! command -v brew &> /dev/null; then
    echo "⚠️ Homebrew not found. Please install it first: https://brew.sh/"
  else
    echo "📡 Installing core tools via Homebrew..."
    brew install git starship mise zoxide fzf zsh-autosuggestions zsh-syntax-highlighting gh
  fi
else
  echo "📡 Checking/Installing core tools (Linux/WSL)..."
  sudo apt-get update
  
  # Ensure Git and other essentials are present
  sudo apt-get install -y git curl wget
  if ! command -v gh &> /dev/null; then
    echo "📦 Adding GitHub CLI repository..."
    (type -p wget >/dev/null || (sudo apt update && sudo apt-get install wget -y)) \
    && sudo mkdir -p -m 755 /etc/apt/keyrings \
    && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt-get update
  fi

  sudo apt-get install -y zsh fzf zoxide zsh-autosuggestions zsh-syntax-highlighting gh wslu
  
  # Ensure local bin exists
  mkdir -p "$HOME/.local/bin"

  # Starship
  if ! command -v starship &> /dev/null; then
    curl -sS https://starship.rs/install.sh | sh -s -- -y --bin-dir "$HOME/.local/bin"
  fi
  
  # Mise
  if [[ ! -f "$HOME/.local/bin/mise" ]]; then
    curl https://mise.jdx.dev/install.sh | sh
  fi
fi

# --- 2. Runtime & Tool Installation (Mise) ---

echo "📡 Configuring Mise (Runtimes & GCloud)..."
# Find mise binary
MISE_BIN="mise"
if [[ -f "$HOME/.local/bin/mise" ]]; then
  MISE_BIN="$HOME/.local/bin/mise"
elif [[ -f "/usr/local/bin/mise" ]]; then
  MISE_BIN="/usr/local/bin/mise"
elif [[ -f "/opt/homebrew/bin/mise" ]]; then
  MISE_BIN="/opt/homebrew/bin/mise"
fi

if command -v "$MISE_BIN" &> /dev/null; then
  export MISE_YES=1
  "$MISE_BIN" trust "$DOTFILES_DIR"
  "$MISE_BIN" install --dir "$DOTFILES_DIR"
else
  echo "⚠️ Mise not found. Runtimes and GCloud install skipped."
fi

ensure_zsh

# --- 3. Symlinks & Configuration ---

echo "🔗 Setting up symlinks from: $DOTFILES_DIR"

# Shell Profiles
for f in .zshrc .bashrc .bash_profile; do
  if [[ -f "$HOME/$f" && ! -L "$HOME/$f" ]]; then
    mv "$HOME/$f" "$HOME/$f.bak.$(date +%F_%T)"
  fi
  ln -sf "$DOTFILES_DIR/profiles/$f" "$HOME/$f"
done

# Config Directory
mkdir -p ~/.config/mise ~/.config/komorebi ~/.config/tmux ~/.config/aerospace

# Core Configs
ln -sf "$DOTFILES_DIR/.config/mise/config.toml" ~/.config/mise/config.toml
ln -sf "$DOTFILES_DIR/.config/starship.toml" ~/.config/starship.toml
ln -sf "$DOTFILES_DIR/.config/tmux/tmux.conf" ~/.tmux.conf
ln -sf "$DOTFILES_DIR/.config/aerospace/aerospace.toml" "$HOME/.aerospace.toml"

# Git Configuration
if [[ ! -f ~/.gitconfig ]]; then
  touch ~/.gitconfig
fi
if ! grep -q "gitconfig.shared" ~/.gitconfig; then
  echo "📝 Including shared git config in ~/.gitconfig..."
  git config --global include.path "$DOTFILES_DIR/.config/git/gitconfig.shared"
fi

# Gemini Config
mkdir -p ~/.gemini
if [[ -f ~/.gemini/settings.json && ! -L ~/.gemini/settings.json ]]; then
  mv ~/.gemini/settings.json ~/.gemini/settings.json.bak.$(date +%F_%T)
fi
ln -sf "$DOTFILES_DIR/.gemini/settings.json" ~/.gemini/settings.json

# Gemini Scripts
mkdir -p ~/.gemini-scripts
ln -sf "$DOTFILES_DIR/.gemini-scripts/gemini-functions.sh" ~/.gemini-scripts/gemini-functions.sh

# --- 3. GitHub & Private Extensions ---

if command -v gh &> /dev/null; then
  if ! gh auth status &>/dev/null; then
    echo "🔐 GitHub CLI not authenticated. Please log in to enable ecosystem clones."
    gh auth login
  fi

  if gh auth status &>/dev/null; then
    # Optional: Clone Private Extensions
    if [ ! -d "$PRIVATE_DIR" ]; then
      read -p "❓ Would you like to clone your private dotfiles extensions? (y/n) " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        mkdir -p "$(dirname "$PRIVATE_DIR")"
        gh repo clone "$PRIVATE_REPO_URL" "$PRIVATE_DIR" || echo "⚠️ Could not clone private repo. Ensure it exists at $PRIVATE_REPO_URL"
      fi
    fi

    echo "📡 Cloning Gemini ecosystem repositories..."
    # Gemini CLI
    if [ ! -d ~/dev/gemini-cli/main ]; then
      mkdir -p ~/dev/gemini-cli
      gh repo clone google-gemini/gemini-cli ~/dev/gemini-cli/main
    fi

    # Gemini Orbit
    if [ ! -d ~/dev/gemini-cli-orbit/main ]; then
      mkdir -p ~/dev/gemini-cli-orbit
      gh repo clone google-gemini/gemini-cli-orbit ~/dev/gemini-cli-orbit/main
    fi
  fi
fi

echo "✅ Dotfiles installation complete! Please restart your shell."
