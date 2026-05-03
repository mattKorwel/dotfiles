# --- 1. Per-host shell drop-ins ---
# Each file in ~/.bashrc.d/ is sourced. ori bootstrap drops a per-class
# file here (ori-class.sh); add your own freely.
for _f in "$HOME"/.bashrc.d/*.sh; do [[ -r "$_f" ]] && . "$_f"; done
unset _f

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

# Starship hostname color: per-class drop-in in ~/.bashrc.d/ exports
# STARSHIP_HOSTNAME_<CLASS>. Fallback to LOCAL if nothing claimed it.
if [[ -z "${STARSHIP_HOSTNAME_WORK}${STARSHIP_HOSTNAME_REMOTE}${STARSHIP_HOSTNAME_CORP}" ]]; then
  export STARSHIP_HOSTNAME_LOCAL="$(hostname -s 2>/dev/null || hostname)"
fi

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

export PATH="$HOME/dev/bin:$PATH"
