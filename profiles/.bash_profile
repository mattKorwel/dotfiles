# Gemini CLI bin for cross-shell compatibility
export PATH="$HOME/.gcli/main/node_modules/.bin:$PATH"

# Load .bashrc if it exists (which handles mise activation)
if [ -f ~/.bashrc ]; then
  . ~/.bashrc
fi

# Mise activation for login shells
if command -v mise &> /dev/null; then
  eval "$(mise activate bash)"
fi
