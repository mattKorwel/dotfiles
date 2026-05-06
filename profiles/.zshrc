# --- 1. Per-host shell drop-ins ---
# Each file in ~/.zshrc.d/ is sourced. ori bootstrap drops a per-class
# file here (ori-class.sh); add your own freely. Each file is responsible
# for its own host gating (or just doesn't gate — drop-in only on the
# hosts that need it).
for _f in "$HOME"/.zshrc.d/*.sh(N); do source "$_f"; done
unset _f

# --- 2. Environment Detection ---
if [[ "$OSTYPE" == "darwin"* ]]; then
  ALIAS_LS_COLOR="-G"
else
  export COLORTERM=truecolor
  ALIAS_LS_COLOR="--color=auto"
fi

# --- 2. Tool Initialization (Mise, Starship, Zoxide) ---
# Mise (Main version manager)
if [[ -f "$HOME/.local/bin/mise" ]]; then
  eval "$($HOME/.local/bin/mise activate zsh)"
elif command -v mise &> /dev/null; then
  eval "$(mise activate zsh)"
fi

# Starship hostname color: each per-class drop-in in ~/.zshrc.d/ exports
# STARSHIP_HOSTNAME_<CLASS> for its own class. If nothing claimed the
# host, treat it as local.
if [[ -z "${STARSHIP_HOSTNAME_WORK}${STARSHIP_HOSTNAME_REMOTE}${STARSHIP_HOSTNAME_CORP}" ]]; then
  export STARSHIP_HOSTNAME_LOCAL="$(hostname -s 2>/dev/null || hostname)"
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
# PATH is set in ~/.zshenv.d/ so non-interactive SSH (ori fleet upgrade,
# agent invocations) sees the same binaries. See:
#   dotfiles-private/configs/zshenv.d/00-path.sh    (operator dirs:
#                                                    ~/dev/bin, ~/.local/bin,
#                                                    ~/.gcli, antigravity)
#   dotfiles/zshenv.d/10-env.sh                     (COLORTERM, EDITOR)

# --- 7. Custom Scripts & Integrations ---
# Load Gemini CLI Shortcuts & Functions. These are interactive
# (functions like gswitch operate on the current shell's cwd) so they
# stay here, not in zshenv.
[[ -f ~/dev/dotfiles/.gemini-scripts/gemini-functions.sh ]] && source ~/dev/dotfiles/.gemini-scripts/gemini-functions.sh
