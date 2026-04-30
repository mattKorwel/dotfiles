# --- 1. Environment Detection ---
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS (Homebrew)
  [[ -f /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
else
  # Linux / WSL
  export COLORTERM=truecolor
  # Support Linuxbrew if installed
  [[ -f /home/linuxbrew/.linuxbrew/bin/brew ]] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# --- 2. Tool Initialization (Mise, Starship, Zoxide) ---
# Mise (Main version manager)
if [[ -f "$HOME/.local/bin/mise" ]]; then
  eval "$($HOME/.local/bin/mise activate bash)"
elif command -v mise &> /dev/null; then
  eval "$(mise activate bash)"
fi

# Starship Prompt (FIXED: Always use 'bash' init)
if command -v starship &> /dev/null; then
  eval "$(starship init bash)"
fi

# Zoxide (Smart cd)
if command -v zoxide &> /dev/null; then
  eval "$(zoxide init bash)"
fi

# --- 3. Aliases & Functions ---
alias ls='ls --color=auto'
alias ll='ls -alF'
alias grep='grep --color=auto'

# Gemini CLI bin
export PATH="$HOME/.gcli/main/node_modules/.bin:$PATH"

# Load Gemini CLI Shortcuts & Functions
[[ -f ~/.gemini-scripts/gemini-functions.sh ]] && . ~/.gemini-scripts/gemini-functions.sh

# --- 4. Private Extensions Hook ---
# Load private/corporate configurations if they exist
PRIVATE_BOOTSTRAP="$HOME/dev/dotfiles-private/bootstrap.sh"
[[ -f "$PRIVATE_BOOTSTRAP" ]] && . "$PRIVATE_BOOTSTRAP"
