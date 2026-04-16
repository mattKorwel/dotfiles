# --- 1. Environment Detection ---
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS (Homebrew)
  [[ -f /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
  ALIAS_LS_COLOR="-G"
else
  # Linux / WSL
  export COLORTERM=truecolor
  ALIAS_LS_COLOR="--color=auto"
  # Support Linuxbrew if installed
  [[ -f /home/linuxbrew/.linuxbrew/bin/brew ]] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# --- 2. Tool Initialization (Mise, Starship, Zoxide) ---
# Mise (Main version manager)
if [[ -f "$HOME/.local/bin/mise" ]]; then
  eval "$($HOME/.local/bin/mise activate zsh)"
elif command -v mise &> /dev/null; then
  eval "$(mise activate zsh)"
fi

# Starship Prompt
if command -v starship &> /dev/null; then
  eval "$(starship init zsh)"
fi

# Zoxide (Smart cd)
if command -v zoxide &> /dev/null; then
  eval "$(zoxide init zsh)"
fi

# --- 3. Shell Options & Completion ---
setopt histignorealldups sharehistory appendhistory
zstyle ':completion:*' menu yes select

# Key bindings (Cross-platform standard)
bindkey '^[[3~' delete-char
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey  "^[[H"   beginning-of-line
bindkey  "^[[F"   end-of-line
bindkey '\t'   complete-word
bindkey '\t\t' autosuggest-accept

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=$HISTSIZE

# --- 4. Plugins & Enhancements ---
# Try common paths for syntax highlighting and autosuggestions
PLUGIN_PATHS=(
  "/opt/homebrew/share"
  "/usr/share"
  "/usr/local/share"
  "$HOME/.local/share"
)

for p in "${PLUGIN_PATHS[@]}"; do
  [[ -f "$p/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && source "$p/zsh-autosuggestions/zsh-autosuggestions.zsh"
  [[ -f "$p/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && source "$p/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
done

# FZF (Fuzzy Search & Tab-completion)
if command -v fzf &> /dev/null; then
  # Modern fzf has a built-in init
  if fzf --version | grep -q '0.48\|0.49\|0.5'; then
    eval "$(fzf --zsh)"
  else
    # Fallback to sourcing files for older versions
    FZF_BASE=""
    [[ -d /opt/homebrew/opt/fzf ]] && FZF_BASE="/opt/homebrew/opt/fzf"
    [[ -d /usr/share/doc/fzf ]] && FZF_BASE="/usr/share/doc/fzf"
    if [[ -n "$FZF_BASE" ]]; then
       [[ -f "$FZF_BASE/shell/completion.zsh" ]] && source "$FZF_BASE/shell/completion.zsh"
       [[ -f "$FZF_BASE/shell/key-bindings.zsh" ]] && source "$FZF_BASE/shell/key-bindings.zsh"
    fi
  fi
fi

# --- 5. Aliases & Functions ---
alias ls="ls $ALIAS_LS_COLOR"
alias ll="ls -alF $ALIAS_LS_COLOR"
alias la="ls -A"
alias l="ls -CF"
alias grep='grep --color=auto'

# --- 6. Tooling Paths ---
export PATH="$HOME/.gcli/main/node_modules/.bin:$PATH"
[[ -d "$HOME/.antigravity/antigravity/bin" ]] && export PATH="$PATH:$HOME/.antigravity/antigravity/bin"

# GCloud Shell Completion (Mise-managed)
if [[ -d "$HOME/.local/share/mise/installs/gcloud" ]]; then
  GCLOUD_BIN_DIR=$(ls -1d $HOME/.local/share/mise/installs/gcloud/* 2>/dev/null | tail -n1)
  [[ -f "$GCLOUD_BIN_DIR/completion.zsh.inc" ]] && source "$GCLOUD_BIN_DIR/completion.zsh.inc"
fi

# --- 7. Custom Scripts & Integrations ---
# Load Gemini CLI Shortcuts & Functions (Symlinked by install.sh)
[[ -f ~/.gemini-scripts/gemini-functions.sh ]] && source ~/.gemini-scripts/gemini-functions.sh

export PATH="$HOME/dev/bin:$PATH"

# Gemini Orbit Shell Integration
alias orbit='node "/Users/mattkorwel/.gemini/extensions/orbit/bundle/orbit-cli.js"'
_orbit() {
  local -a commands
  commands=(
    'ci:Monitor CI status for a branch with noise filtering.'
    'install-shell:Install Orbit shell aliases and tab-completion.'
    'jettison:Decommission a specific mission and its worktree.'
    'liftoff:Build or wake infrastructure (use --with-new-station).'
    'mission:Start, resume, or perform maneuvers on a PR mission.'
    'pulse:Check station health and active mission status.'
    'schematic:Manage infrastructure blueprints: <list|create|edit|import>'
    'splashdown:Emergency shutdown of all active remote capsules.'
    'station:Hardware control: <activate|list|liftoff|delete>'
    'uplink:Inspect local or remote mission telemetry.'
  )
  _describe 'orbit' commands
}
compdef _orbit orbit
# End Gemini Orbit Shell Integration
