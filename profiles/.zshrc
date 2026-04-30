# --- 1. Private Extensions Hook (Load Environment Variables First) ---
# Load private/corporate configurations if they exist
PRIVATE_BOOTSTRAP="$HOME/dev/dotfiles-private/bootstrap.sh"
[[ -f "$PRIVATE_BOOTSTRAP" ]] && source "$PRIVATE_BOOTSTRAP"

# --- 2. Environment Detection ---
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
# Load Zsh completions
ZSH_PLUGIN_DIR="$HOME/.local/share/zsh-plugins"
ZSH_COMP_DIR="$HOME/.local/share/zsh-completions"

# Add custom completions and plugin completions to fpath
fpath=("$ZSH_COMP_DIR" $fpath)
if [[ -d "$ZSH_PLUGIN_DIR/zsh-completions/src" ]]; then
  fpath=("$ZSH_PLUGIN_DIR/zsh-completions/src" $fpath)
fi

# Initialize completion system
autoload -Uz compinit
compinit

# Source any extra completion scripts (non-fpath)
for script in "$ZSH_COMP_DIR"/*.zsh(N); do
  source "$script"
done

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
# Source plugins from local directory
[[ -f "$ZSH_PLUGIN_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && source "$ZSH_PLUGIN_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh"
[[ -f "$ZSH_PLUGIN_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && source "$ZSH_PLUGIN_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

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

# --- 7. Custom Scripts & Integrations ---
# Load Gemini CLI Shortcuts & Functions
[[ -f ~/dev/dotfiles/.gemini-scripts/gemini-functions.sh ]] && source ~/dev/dotfiles/.gemini-scripts/gemini-functions.sh

export PATH="$HOME/dev/bin:$PATH"
