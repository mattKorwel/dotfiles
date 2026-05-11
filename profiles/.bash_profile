# Note: gemini binary is provided by mise (npm:@google/gemini-cli),
# not from a per-channel ~/.gcli install (removed 2026-05-11).

# Load .bashrc if it exists (which handles mise activation)
if [ -f ~/.bashrc ]; then
  . ~/.bashrc
fi

# Mise activation for login shells
if command -v mise &> /dev/null; then
  eval "$(mise activate bash)"
fi
