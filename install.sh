#!/bin/bash

set -e

# --- Configuration ---
REPO_URL="https://github.com/mattkorwel/dotfiles.git"
DOTFILES_DIR="$HOME/dev/dotfiles"
PRIVATE_REPO_URL="https://github.com/mattkorwel/dotfiles-private.git"
PRIVATE_DIR="$HOME/dev/dotfiles-private"
BACKUP_DIR="$DOTFILES_DIR/.backups"

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

backup_and_link() {
  local src=$1
  local dst=$2
  
  if [[ -f "$dst" && ! -L "$dst" ]]; then
    mkdir -p "$BACKUP_DIR"
    local filename=$(basename "$dst")
    echo "💾 Backing up $filename to $BACKUP_DIR"
    mv "$dst" "$BACKUP_DIR/${filename}.bak.$(date +%F_%T)"
  fi

  mkdir -p "$(dirname "$dst")"
  ln -sf "$src" "$dst"
}

# --- 1. Bootstrap: Repository ---

if [ ! -d "$DOTFILES_DIR/.git" ]; then
  pkg_install git
  echo "📡 Bootstrapping: Cloning dotfiles to $DOTFILES_DIR..."
  mkdir -p "$(dirname "$DOTFILES_DIR")"
  git clone "$REPO_URL" "$DOTFILES_DIR"
fi

# --- 2. Symlinks & Configuration ---

echo "🔗 Setting up symlinks..."

# Shell Profiles
for f in .zshrc .bashrc .bash_profile; do
  if [[ -f "$DOTFILES_DIR/profiles/$f" ]]; then
    backup_and_link "$DOTFILES_DIR/profiles/$f" "$HOME/$f"
  fi
done

# Cross-Platform Configs
backup_and_link "$DOTFILES_DIR/.config/mise/config.toml" "$HOME/.config/mise/config.toml"
backup_and_link "$DOTFILES_DIR/.config/starship.toml"    "$HOME/.config/starship.toml"
backup_and_link "$DOTFILES_DIR/.config/git/gitconfig.shared" "$HOME/.config/git/gitconfig.shared"
backup_and_link "$DOTFILES_DIR/.gemini/settings.json"    "$HOME/.gemini/settings.json"

# macOS Specific
if [[ "$OSTYPE" == "darwin"* ]]; then
  backup_and_link "$DOTFILES_DIR/.config/aerospace/aerospace.toml" "$HOME/.aerospace.toml"
fi

# Unix/Linux Specific (Tmux)
if [[ "$OSTYPE" == "darwin"* || "$OSTYPE" == "linux-gnu"* ]]; then
  backup_and_link "$DOTFILES_DIR/.config/tmux/tmux.conf" "$HOME/.tmux.conf"
fi

# Git Configuration (Local Include)
# This appends a pointer to your local ~/.gitconfig so it uses your shared settings
if [[ ! -f "$HOME/.gitconfig" ]]; then
  touch "$HOME/.gitconfig"
fi
if ! grep -q "gitconfig.shared" "$HOME/.gitconfig"; then
  echo "📝 Including shared git config in $HOME/.gitconfig"
  git config --global include.path "$DOTFILES_DIR/.config/git/gitconfig.shared"
fi

# --- 3. Tools: Mise & Runtimes ---

# Mise (Quiet install) - STANDALONE VERSION
if [[ ! -f "$HOME/.local/bin/mise" ]]; then
  echo "🚀 Installing Mise..."
  mkdir -p "$HOME/.local/bin"
  curl https://mise.jdx.dev/install.sh | sh > /dev/null
fi

MISE_BIN="$HOME/.local/bin/mise"

if [[ -f "$MISE_BIN" ]]; then
  export MISE_YES=1
  export PATH="$HOME/.local/bin:$PATH"
  
  echo "📡 Configuring Mise & Installing Tools (Node 24, Gemini, etc.)..."
  "$MISE_BIN" trust "$DOTFILES_DIR"
  "$MISE_BIN" install
fi

# --- 4. GitHub & Private Extensions ---

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
