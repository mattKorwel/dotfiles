#!/bin/bash

echo "🗑 Cleaning up dotfiles symlinks..."

# Remove Symlinks
rm -f ~/.zshrc
rm -f ~/.config/mise/config.toml
rm -f ~/.config/starship.toml
rm -f ~/.gemini-scripts/gemini-functions.sh

# Restore backup if it exists
if [[ -f ~/.zshrc.bak.* ]]; then
  LATEST_BAK=$(ls -t ~/.zshrc.bak.* | head -n1)
  echo "♻️ Restoring backup: $LATEST_BAK"
  mv "$LATEST_BAK" ~/.zshrc
fi

echo "✅ Dotfiles uninstallation complete."
