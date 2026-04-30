#!/bin/bash

set -e

# --- Configuration ---
TARGET_DIR="$HOME/dev/dotfiles"
PRIVATE_REPO_URL="https://github.com/mattkorwel/dotfiles-private.git"
PRIVATE_DIR="$HOME/dev/dotfiles-private"

# Ensure we are working with the correct directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)"
DOTFILES_DIR="${SCRIPT_DIR:-$TARGET_DIR}"

echo "🚀 Initializing Dotfiles from $DOTFILES_DIR..."

# --- Helper Functions ---

pkg_install() {
  local pkg=$1
  if ! command -v "$pkg" &>/dev/null; then
    echo "📦 $pkg not found. Installing..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
      if command -v brew &>/dev/null; then
        brew install "$pkg"
      else
        echo "⚠️ Homebrew missing. Cannot install $pkg."
        exit 1
      fi
    else
      sudo apt-get update && sudo apt-get install -y "$pkg"
    fi
  fi
}

# --- 1. Bootstrap: Dependencies & Mise ---

# Ensure core bootstrap tools are present
pkg_install curl
pkg_install git

# Ensure local bin exists
mkdir -p "$HOME/.local/bin"

# Mise (Quiet install) - STANDALONE VERSION
if [[ ! -f "$HOME/.local/bin/mise" ]]; then
  echo "🚀 Installing Mise..."
  curl https://mise.jdx.dev/install.sh | sh > /dev/null
fi

MISE_BIN="$HOME/.local/bin/mise"
MISE_CONFIG="$DOTFILES_DIR/.config/mise/config.toml"

if [[ -f "$MISE_BIN" ]]; then
  export MISE_YES=1
  export PATH="$HOME/.local/bin:$PATH"
  
  echo "📡 Configuring Mise & Installing Tools (Node 24, Dashlane, etc.)..."
  "$MISE_BIN" trust "$MISE_CONFIG"
  "$MISE_BIN" install --config "$MISE_CONFIG"
  
  echo "📡 Installing Gemini CLI (@nightly)..."
  "$MISE_BIN" exec --config "$MISE_CONFIG" -- npm install -g @google/gemini-cli@nightly

  # --- GCloud Component Management ---
  if "$MISE_BIN" exec -- gcloud version &> /dev/null; then
    GCLOUD_PATH=$("$MISE_BIN" which gcloud)
    if [[ "$GCLOUD_PATH" != *"/google/bin"* ]] && [[ "$GCLOUD_PATH" != *"/Caskroom"* ]]; then
      read -p "❓ Install optional GCloud components? (y/n) " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "📡 Installing GCloud components..."
        export CLOUDSDK_CORE_DISABLE_PROMPTS=1
        COMPONENTS=$(gcloud components list --filter="state.name='Not Installed'" --format="value(id)" 2>/dev/null || true)
        if [[ -n "$COMPONENTS" ]]; then
           echo "$COMPONENTS" | xargs -r gcloud components install --quiet
        fi
      fi
    fi
  fi
fi

# --- 2. Symlinks & Configuration ---

echo "🔗 Setting up core symlinks..."

# Shell Profiles
for f in .zshrc .bashrc .bash_profile; do
  if [[ -f "$HOME/$f" && ! -L "$HOME/$f" ]]; then
    mv "$HOME/$f" "$HOME/$f.bak.$(date +%F_%T)"
  fi
  ln -sf "$DOTFILES_DIR/profiles/$f" "$HOME/$f"
done

# Config Directory Structure
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
  git config --global include.path "$DOTFILES_DIR/.config/git/gitconfig.shared"
fi

# Gemini Config
mkdir -p ~/.gemini
if [[ -f ~/.gemini/settings.json && ! -L ~/.gemini/settings.json ]]; then
  mv ~/.gemini/settings.json ~/.gemini/settings.json.bak.$(date +%F_%T)
fi
ln -sf "$DOTFILES_DIR/.gemini/settings.json" ~/.gemini/settings.json

# --- 3. GitHub & Private Extensions ---

if [[ -f "$MISE_BIN" ]] && "$MISE_BIN" exec -- gh auth status &>/dev/null; then
  if [ ! -d "$PRIVATE_DIR" ]; then
    read -p "❓ Clone private dotfiles? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      "$MISE_BIN" exec -- gh repo clone "$PRIVATE_REPO_URL" "$PRIVATE_DIR"
    fi
  fi
fi

echo "✅ Done! Reloading shell..."
exec zsh -l
