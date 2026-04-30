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

DOTFILES_DIR="$TARGET_DIR"
mkdir -p "$HOME/.local/bin"

# --- 2. Core Tooling Installation ---

if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "📡 Ensuring core tools are present (Mac)..."
  if command -v brew &> /dev/null; then
    # We exclude mise and starship from brew to keep them standalone
    brew install git zoxide fzf zsh-autosuggestions zsh-syntax-highlighting gh
  fi
else
  echo "📡 Checking/Installing core tools (Linux/WSL)..."
  sudo apt-get update
  sudo apt-get install -y git curl wget zsh fzf zoxide zsh-autosuggestions zsh-syntax-highlighting gh wslu
fi

# Standalone Starship Install (Common for both)
if ! command -v starship &> /dev/null; then
  echo "🚀 Installing Starship (Standalone)..."
  curl -sS https://starship.rs/install.sh | sh -s -- -y --bin-dir "$HOME/.local/bin" > /dev/null
fi

# Standalone Mise Install (Common for both)
if [[ ! -f "$HOME/.local/bin/mise" ]]; then
  echo "🚀 Installing Mise (Standalone)..."
  curl https://mise.jdx.dev/install.sh | sh > /dev/null
fi

# --- 3. Runtime & Tool Installation (Mise) ---

echo "📡 Configuring Mise (Runtimes & GCloud)..."
MISE_BIN="$HOME/.local/bin/mise"

if [[ -f "$MISE_BIN" ]]; then
  # CRITICAL: Put mise in the PATH for this script and activate it
  export PATH="$HOME/.local/bin:$PATH"
  eval "$($MISE_BIN activate bash)"
  export MISE_YES=1
  
  "$MISE_BIN" trust "$DOTFILES_DIR"
  echo "📦 Running mise install..."
  (cd "$DOTFILES_DIR" && "$MISE_BIN" install)
  
  # Install Gemini CLI globally
  # Because of 'eval' above, npm should now be in the path
  if command -v npm &> /dev/null; then
    echo "📡 Installing Gemini CLI (@nightly)..."
    npm install -g @google/gemini-cli@nightly --registry=https://registry.npmjs.org/
  else
    echo "⚠️ npm not found. Is node defined in your mise.toml?"
  fi

  # --- GCloud Component Management ---
  if command -v gcloud &> /dev/null; then
    GCLOUD_PATH=$(which gcloud)
    
    if [[ "$GCLOUD_PATH" == *"/google/bin"* ]] || [[ "$GCLOUD_PATH" == *"/Caskroom"* ]]; then
      echo "💡 Detected managed GCloud installation. Skipping component management."
    else
      read -p "❓ Would you like to install optional GCloud components? (y/n) " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        export CLOUDSDK_CORE_DISABLE_PROMPTS=1
        gcloud components install --quiet alpha beta cloud-datastore-emulator
      fi
    fi
  fi
else
  echo "⚠️ Mise binary not found at $MISE_BIN. Runtimes skipped."
fi

ensure_zsh

# --- 4. Symlinks & Configuration ---

echo "🔗 Setting up symlinks from: $DOTFILES_DIR"

for f in .zshrc .bashrc .bash_profile; do
  if [[ -f "$HOME/$f" && ! -L "$HOME/$f" ]]; then
    mv "$HOME/$f" "$HOME/$f.bak.$(date +%F_%T)"
  fi
  ln -sf "$DOTFILES_DIR/profiles/$f" "$HOME/$f"
done

mkdir -p ~/.config/mise ~/.config/komorebi ~/.config/tmux ~/.config/aerospace ~/.config/windows-terminal ~/.config/git

ln -sf "$DOTFILES_DIR/.config/mise/config.toml" ~/.config/mise/config.toml
ln -sf "$DOTFILES_DIR/.config/starship.toml" ~/.config/starship.toml
ln -sf "$DOTFILES_DIR/.config/tmux/tmux.conf" ~/.tmux.conf
ln -sf "$DOTFILES_DIR/.config/aerospace/aerospace.toml" "$HOME/.aerospace.toml"
ln -sf "$DOTFILES_DIR/.config/windows-terminal/settings.json" ~/.config/windows-terminal/settings.json
ln -sf "$DOTFILES_DIR/.config/git/gitconfig.shared" ~/.config/git/gitconfig.shared

if [[ ! -f ~/.gitconfig ]]; then touch ~/.gitconfig; fi
if ! grep -q "gitconfig.shared" ~/.gitconfig; then
  git config --global include.path "$DOTFILES_DIR/.config/git/gitconfig.shared"
fi

# Gemini Setup
mkdir -p ~/.gemini
ln -sf "$DOTFILES_DIR/.gemini/settings.json" ~/.gemini/settings.json
mkdir -p ~/.gemini-scripts
ln -sf "$DOTFILES_DIR/.gemini-scripts/gemini-functions.sh" ~/.gemini-scripts/gemini-functions.sh

# --- 5. GitHub & Private Extensions ---

if command -v gh &> /dev/null; then
  if gh auth status &>/dev/null; then
    if [ ! -d "$PRIVATE_DIR" ]; then
      read -p "❓ Clone private dotfiles extensions? (y/n) " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        mkdir -p "$(dirname "$PRIVATE_DIR")"
        gh repo clone "$PRIVATE_REPO_URL" "$PRIVATE_DIR" || echo "⚠️ Private repo clone failed."
      fi
    fi
  fi
fi

echo "✅ Installation complete! Please restart your terminal."
exec zsh -l
