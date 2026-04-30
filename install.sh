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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)"
DOTFILES_DIR="${SCRIPT_DIR:-$TARGET_DIR}"

# --- 2. Core Tooling Installation ---

if [[ "$OSTYPE" == "darwin"* ]]; then
  if ! command -v brew &> /dev/null; then
    echo "⚠️ Homebrew not found. Please install it first: https://brew.sh/"
  else
    echo "📡 Ensuring core tools are present via Homebrew (git, starship, zoxide, etc.)..."
    # REMOVED mise from brew install list to favor standalone
    brew install git starship zoxide fzf zsh-autosuggestions zsh-syntax-highlighting gh
  fi
else
  echo "📡 Checking/Installing core tools (Linux/WSL)..."
  sudo apt-get update
  sudo apt-get install -y git curl wget zsh fzf zoxide zsh-autosuggestions zsh-syntax-highlighting gh
fi

# Ensure local bin exists
mkdir -p "$HOME/.local/bin"

# Starship (Quiet install)
if ! command -v starship &> /dev/null; then
  echo "🚀 Installing Starship..."
  curl -sS https://starship.rs/install.sh | sh -s -- -y --bin-dir "$HOME/.local/bin" > /dev/null
fi

# Mise (Quiet install) - STANDALONE VERSION
if [[ ! -f "$HOME/.local/bin/mise" ]]; then
  echo "🚀 Installing Mise..."
  curl https://mise.jdx.dev/install.sh | sh > /dev/null
fi

# --- 3. Runtime & Tool Installation (Mise) ---
echo "📡 Configuring Mise (Runtimes & GCloud)..."
MISE_BIN="$HOME/.local/bin/mise"
# Find your config file (adjust name if it's .mise.toml)
MISE_CONFIG="$DOTFILES_DIR/.config/mise/config.toml"

if [[ -f "$MISE_BIN" ]]; then
  export MISE_YES=1
  export PATH="$HOME/.local/bin:$PATH"
  
  # Tell mise to trust and use the specific config in your repo
  "$MISE_BIN" trust "$MISE_CONFIG"
  
  echo "📦 Installing runtimes from $MISE_CONFIG..."
  "$MISE_BIN" install --config "$MISE_CONFIG"
  
  # Now mise knows what Node is, so npm will work
  echo "📡 Installing Gemini CLI (@nightly)..."
  "$MISE_BIN" exec --config "$MISE_CONFIG" -- npm install -g @google/gemini-cli@nightly
else
  echo "⚠️ Mise not found at $MISE_BIN"
fi

  # --- GCloud Component Management ---
  # FIX 3: Check gcloud status via mise exec
  if "$MISE_BIN" exec -- gcloud version &> /dev/null; then
    GCLOUD_PATH=$("$MISE_BIN" which gcloud)
    
    if [[ "$GCLOUD_PATH" == *"/google/bin"* ]] || [[ "$GCLOUD_PATH" == *"/Caskroom"* ]]; then
      echo "💡 Detected managed/corporate GCloud installation ($GCLOUD_PATH). Skipping component management."
    else
      read -p "❓ Would you like to install all optional GCloud components? (y/n) " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "📡 Installing all Google Cloud components (this may take a while)..."
        export CLOUDSDK_CORE_DISABLE_PROMPTS=1
        COMPONENTS=$(gcloud components list --filter="state.name='Not Installed'" --format="value(id)" 2>/dev/null || true)
        if [[ -n "$COMPONENTS" ]]; then
           echo "$COMPONENTS" | xargs -r gcloud components install --quiet
        fi
      fi
    fi
  fi
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

# --- 6. Optional: Dashlane CLI ---
if ! command -v dcli &> /dev/null; then
  read -p "❓ Would you like to install Dashlane CLI? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "📡 Installing Dashlane CLI..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
      brew install dashlane/tap/dashlane-cli
    else
      if command -v brew &> /dev/null; then
        brew install dashlane/tap/dashlane-cli
      else
        mkdir -p "$HOME/.local/bin"
        curl -L https://github.com/Dashlane/dashlane-cli/releases/latest/download/dashlane-cli-linux-x64 -o "$HOME/.local/bin/dcli"
        chmod +x "$HOME/.local/bin/dcli"
      fi
    fi
  fi
fi

echo "✅ Dotfiles installation complete! Dropping into Zsh..."
exec zsh -l
