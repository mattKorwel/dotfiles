# Gemini CLI bin for cross-shell compatibility
export PATH="$HOME/.gcli/main/node_modules/.bin:$PATH"

# Homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

# Load .bashrc if it exists (which handles mise activation)
if [ -f ~/.bashrc ]; then
  . ~/.bashrc
fi

# Mise activation for login shells
if command -v mise &> /dev/null; then
  eval "$(mise activate bash)"
fi
