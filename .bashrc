# Gemini CLI bin for cross-shell compatibility (non-login shells)
export PATH="$HOME/.gcli/main/node_modules/.bin:$PATH"

# Mise activation for Bash
if command -v mise &> /dev/null; then
  eval "$(mise activate bash)"
fi

# Load Gemini CLI Shortcuts & Functions
if [ -f "$HOME/.gemini-scripts/gemini-functions.sh" ]; then
  . "$HOME/.gemini-scripts/gemini-functions.sh"
fi
