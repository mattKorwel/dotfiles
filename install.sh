#!/bin/bash

# --- Tooling installation (macOS/Homebrew) ---
if command -v brew &> /dev/null; then
  echo "📡 Installing core tools via Homebrew..."
  brew install starship mise zoxide fzf zsh-autosuggestions zsh-syntax-highlighting
else
  echo "⚠️ Homebrew not found. Skipping Homebrew tool installation."
fi

# --- Symlinks & Configuration ---
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔗 Setting up symlinks..."

# 1. ZSH Configuration
if [[ -n "$ZSH_VERSION" || -f /bin/zsh || -f /usr/bin/zsh ]]; then
  if [[ -f ~/.zshrc && ! -L ~/.zshrc ]]; then
    mv ~/.zshrc ~/.zshrc.bak.$(date +%F_%T)
  fi
  ln -sf "$DOTFILES_DIR/.zshrc" ~/.zshrc
fi

# 2. Git Configuration (Using Include strategy)
# We don't overwrite the entire .gitconfig because user.email and credential helpers 
# can be machine-specific (e.g. Windows vs Mac paths for gh).
if [[ ! -f ~/.gitconfig ]]; then
  touch ~/.gitconfig
fi

# Ensure the shared config is included in the local .gitconfig
if ! grep -q ".gitconfig.shared" ~/.gitconfig; then
  echo "📝 Including shared git config in ~/.gitconfig..."
  git config --global include.path "$DOTFILES_DIR/.gitconfig.shared"
fi

# 3. App-specific Configs
mkdir -p ~/.config/mise
ln -sf "$DOTFILES_DIR/.config/mise/config.toml" ~/.config/mise/config.toml

mkdir -p ~/.config
ln -sf "$DOTFILES_DIR/config.toml" ~/.config/starship.toml

# 4. Gemini Scripts
mkdir -p ~/.gemini-scripts
ln -sf "$DOTFILES_DIR/.gemini-scripts/gemini-functions.sh" ~/.gemini-scripts/gemini-functions.sh

echo "✅ Dotfiles installation complete! (Bash/Zsh)"
