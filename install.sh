#!/bin/bash

set -e

# --- Configuration ---
REPO_URL="https://github.com/mattkorwel/dotfiles.git"
TARGET_DIR="$HOME/dev/dotfiles"
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

# --- 1. Bootstrap: Clone Repo if needed ---

if [ ! -d "$TARGET_DIR/.git" ]; then
  echo "📡 Bootstrapping: Cloning public dotfiles to $TARGET_DIR..."
  
  # Ensure git is installed first
  if ! command -v git &> /dev/null; then
    echo "📦 Git not found. Installing..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
      echo "⚠️ Please install Homebrew first to continue: https://brew.sh/"
      exit 1
    else
      sudo apt-get update && sudo apt-get install -y git curl wget
    fi
  fi

  mkdir -p "$(dirname "$TARGET_DIR")"
  git clone "$REPO_URL" "$TARGET_DIR"
fi

# Ensure we are working with the correct directory
DOTFILES_DIR="$TARGET_DIR"

# --- 2. Core Tooling Installation ---

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

  # Starship (Quiet install)
  if ! command -v starship &> /dev/null; then
    echo "🚀 Installing Starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y --bin-dir "$HOME/.local/bin" > /dev/null
  fi
  
  # Mise (Quiet install)
  if [[ ! -f "$HOME/.local/bin/mise" ]]; then
    echo "🚀 Installing Mise..."
    curl https://mise.jdx.dev/install.sh | sh > /dev/null
  fi
fi

# --- 3. Runtime & Tool Installation (Mise) ---

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
  (cd "$DOTFILES_DIR" && "$MISE_BIN" install)
  
  # Install Gemini CLI globally
  echo "📡 Installing Gemini CLI (@nightly)..."
  "$MISE_BIN" exec -- npm install -g @google/gemini-cli@nightly --registry=https://registry.npmjs.org/
else
  echo "⚠️ Mise not found. Runtimes and GCloud install skipped."
fi

ensure_zsh

# --- 4. Symlinks & Configuration ---

echo "🔗 Setting up symlinks from: $DOTFILES_DIR"

# Shell Profiles
for f in .zshrc .bashrc .bash_profile; do
  if [[ -f "$HOME/$f" && ! -L "$HOME/$f" ]]; then
    mv "$HOME/$f" "$HOME/$f.bak.$(date +%F_%T)"
  fi
  ln -sf "$DOTFILES_DIR/profiles/$f" "$HOME/$f"
done

# Config Directory
mkdir -p ~/.config/mise ~/.config/komorebi ~/.config/tmux ~/.config/aerospace ~/.config/windows-terminal ~/.config/git

# Core Configs
ln -sf "$DOTFILES_DIR/.config/mise/config.toml" ~/.config/mise/config.toml
ln -sf "$DOTFILES_DIR/.config/starship.toml" ~/.config/starship.toml
ln -sf "$DOTFILES_DIR/.config/tmux/tmux.conf" ~/.tmux.conf
ln -sf "$DOTFILES_DIR/.config/aerospace/aerospace.toml" "$HOME/.aerospace.toml"
ln -sf "$DOTFILES_DIR/.config/windows-terminal/settings.json" ~/.config/windows-terminal/settings.json
ln -sf "$DOTFILES_DIR/.config/git/gitconfig.shared" ~/.config/git/gitconfig.shared

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

# --- 5. GitHub & Private Extensions ---

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
  fi
fi

echo "✅ Dotfiles installation complete! Please restart your shell."
