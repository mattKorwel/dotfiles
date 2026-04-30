# --- 1. Private Extensions Hook (Load Environment Variables First) ---
# Load private/corporate configurations if they exist
PRIVATE_BOOTSTRAP="$HOME/dev/dotfiles-private/bootstrap.sh"
[[ -f "$PRIVATE_BOOTSTRAP" ]] && . "$PRIVATE_BOOTSTRAP"

# --- 2. Environment Detection ---
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS (Homebrew)
  [[ -f /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
else
  # Linux / WSL
  export COLORTERM=truecolor
  # Support Linuxbrew if installed
  [[ -f /home/linuxbrew/.linuxbrew/bin/brew ]] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# --- 3. Tool Initialization (Mise, Starship, Zoxide) ---
# Mise (Main version manager)
if [[ -f "$HOME/.local/bin/mise" ]]; then
  eval "$($HOME/.local/bin/mise activate bash)"
elif command -v mise &> /dev/null; then
  eval "$(mise activate bash)"
fi

# Starship Prompt (FIXED: Always use 'bash' init)
_dotfiles_export_starship_hostname() {
  local hostname pattern
  hostname="$(hostname -f 2>/dev/null || hostname 2>/dev/null || printf '%s' "${HOSTNAME:-}")"
  unset STARSHIP_HOSTNAME_LOCAL STARSHIP_HOSTNAME_WORK STARSHIP_HOSTNAME_REMOTE STARSHIP_HOSTNAME_ROAM

  for pattern in "${DOTFILES_HOSTNAME_REMOTE_PATTERNS[@]}"; do
    if [[ "$hostname" == $pattern ]]; then
      export STARSHIP_HOSTNAME_REMOTE="$hostname"
      return
    fi
  done

  for pattern in "${DOTFILES_HOSTNAME_WORK_PATTERNS[@]}"; do
    if [[ "$hostname" == $pattern ]]; then
      export STARSHIP_HOSTNAME_WORK="$hostname"
      return
    fi
  done

  for pattern in "${DOTFILES_HOSTNAME_ROAM_PATTERNS[@]}"; do
    if [[ "$hostname" == $pattern ]]; then
      export STARSHIP_HOSTNAME_ROAM="$hostname"
      return
    fi
  done

  export STARSHIP_HOSTNAME_LOCAL="$hostname"
}
_dotfiles_export_starship_hostname
unset -f _dotfiles_export_starship_hostname

if command -v starship &> /dev/null; then
  eval "$(starship init bash)"
fi

# Zoxide (Smart cd)
if command -v zoxide &> /dev/null; then
  eval "$(zoxide init bash)"
fi

# --- 4. Aliases & Functions ---
alias ls='ls --color=auto'
alias ll='ls -alF'
alias grep='grep --color=auto'

# Gemini CLI bin
export PATH="$HOME/.gcli/main/node_modules/.bin:$PATH"

# Load Gemini CLI Shortcuts & Functions
[[ -f ~/dev/dotfiles/.gemini-scripts/gemini-functions.sh ]] && . ~/dev/dotfiles/.gemini-scripts/gemini-functions.sh
