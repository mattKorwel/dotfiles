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
else
  echo "📡 Updating dotfiles..."
  git -C "$DOTFILES_DIR" pull --ff-only
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
  backup_and_link "$DOTFILES_DIR/.config/aerospace/aerospace.toml" "$HOME/.config/aerospace/aerospace.toml"
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

# --- 3. Shell Plugins (Manual) ---

echo "🔌 Setting up Zsh plugins..."
ZSH_PLUGIN_DIR="$HOME/.local/share/zsh-plugins"
mkdir -p "$ZSH_PLUGIN_DIR"

PLUGINS=(
  "zsh-users/zsh-autosuggestions"
  "zsh-users/zsh-syntax-highlighting"
  "zsh-users/zsh-completions"
)

for plugin in "${PLUGINS[@]}"; do
  name=$(basename "$plugin")
  if [ ! -d "$ZSH_PLUGIN_DIR/$name" ]; then
    echo "📥 Cloning $name..."
    git clone "https://github.com/$plugin.git" "$ZSH_PLUGIN_DIR/$name"
  else
    echo "upgrading $name..."
    git -C "$ZSH_PLUGIN_DIR/$name" pull --quiet
  fi
done

# --- 4. Tool Completions (Automated) ---

echo "⚙️ Generating shell completions..."
ZSH_COMP_DIR="$HOME/.local/share/zsh-completions"
mkdir -p "$ZSH_COMP_DIR"

# Mise
if command -v mise &>/dev/null; then
  mise completion zsh > "$ZSH_COMP_DIR/_mise"
fi

# GitHub CLI
if command -v gh &>/dev/null; then
  gh completion -s zsh > "$ZSH_COMP_DIR/_gh"
fi

# NPM
if command -v npm &>/dev/null; then
  npm completion > "$ZSH_COMP_DIR/npm.zsh"
fi

# GCloud
# Note: GCloud completions are usually sourced from the SDK path.
# We will create a pointer script.
if command -v gcloud &>/dev/null; then
  GCLOUD_SDK_ROOT=$(gcloud info --format="value(basic.sdk_root)")
elif command -v mise &>/dev/null; then
  GCLOUD_SDK_ROOT=$(mise where gcloud 2>/dev/null)
fi

if [[ -d "$GCLOUD_SDK_ROOT" ]]; then
  echo "source '$GCLOUD_SDK_ROOT/completion.zsh.inc'" > "$ZSH_COMP_DIR/gcloud.zsh"
fi

# Usage
# (Skipping automated completion generation for 'usage' tool due to complex flags)

# --- 5. Tools: Mise & Runtimes ---

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

# --- 6. GitHub & Private Extensions ---

# Private repos (dotfiles-private and ori) require authentication
ensure_gh_auth() {
  if ! "$MISE_BIN" exec -- gh auth status &>/dev/null; then
    echo "🔐 GitHub authentication required for private repositories..."
    "$MISE_BIN" exec -- gh auth login
  fi
}

# 6a. Private Dotfiles
if [ ! -d "$PRIVATE_DIR" ]; then
  read -p "❓ Clone private dotfiles? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    ensure_gh_auth
    echo "📡 Cloning private dotfiles..."
    "$MISE_BIN" exec -- gh repo clone "$PRIVATE_REPO_URL" "$PRIVATE_DIR"
  fi
else
  echo "📡 Updating private dotfiles..."
  git -C "$PRIVATE_DIR" pull --ff-only
fi

# Run private installation logic if directory exists
if [[ -d "$PRIVATE_DIR" && -f "$PRIVATE_DIR/install.sh" ]]; then
  echo "🛠️ Running private installation script..."
  bash "$PRIVATE_DIR/install.sh"
fi

echo "✅ Done! Reloading shell..."
exec zsh -l
