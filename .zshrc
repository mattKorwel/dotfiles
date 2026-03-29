# 1. Homebrew (Must be first so Starship and other tools are found)
eval "$(/opt/homebrew/bin/brew shellenv)"

# 2. Starship Prompt (Initialize early for corporate hook compatibility)
if command -v starship &> /dev/null; then
  eval "$(starship init zsh)"
fi

# ZSH options and styles
setopt histignorealldups sharehistory appendhistory
zstyle ':completion:*' menu yes select

# Key bindings
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

# Shell Enhancements (Homebrew)
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Custom Functions
alias ls='ls -G --color=auto'
alias ll='ls -GalF --color=always'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'

# 3. Mise (Manages Node, NPM, Go, and GCloud)
eval "$(/Users/mattkorwel/.local/bin/mise activate zsh)"

# 4. Zoxide (Smart cd)
eval "$(zoxide init zsh)"

# 5. FZF (Fuzzy Search & Tab-completion)
# Using the explicit Homebrew path for better reliability on macOS
source "/opt/homebrew/opt/fzf/shell/completion.zsh"
source "/opt/homebrew/opt/fzf/shell/key-bindings.zsh"

# Internal Tooling Paths
export PATH="$PATH:/Users/mattkorwel/.antigravity/antigravity/bin"

# GCloud Shell Completion (Loaded from Mise-managed install)
if [[ -d "$HOME/.local/share/mise/installs/gcloud" ]]; then
  # Find the most recently installed version
  GCLOUD_BIN_DIR=$(ls -1d $HOME/.local/share/mise/installs/gcloud/* 2>/dev/null | tail -n1)
  [[ -f "$GCLOUD_BIN_DIR/completion.zsh.inc" ]] && source "$GCLOUD_BIN_DIR/completion.zsh.inc"
fi

# Load Gemini CLI Shortcuts & Functions
[[ -f ~/dev/dotfiles/main/.gemini-scripts/gemini-functions.zsh ]] && source ~/dev/dotfiles/main/.gemini-scripts/gemini-functions.zsh

