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

# Re-assert operator dirs at the FRONT of PATH after mise activates.
# mise prepends its install dirs (~/.local/share/mise/installs/.../bin)
# which would otherwise shadow ~/dev/bin — and `go install` writes to
# the mise go bin dir by default, so an accidental `go install ./cmd/ori`
# would beat the operator-built ~/dev/bin/ori. Putting ~/dev/bin ahead
# of mise dirs ensures `which ori` always resolves to the operator's
# canonical binary.
typeset -U path
path=("$HOME/.local/bin" $path)
path=("$HOME/dev/bin" $path)
export PATH

# Starship hostname color: each per-class drop-in in ~/.zshrc.d/ exports
# STARSHIP_HOSTNAME_<CLASS> for its own class. If nothing claimed the
# host, treat it as local.
if [[ -z "${STARSHIP_HOSTNAME_WORK}${STARSHIP_HOSTNAME_REMOTE}${STARSHIP_HOSTNAME_CORP}" ]]; then
  export STARSHIP_HOSTNAME_LOCAL="$(hostname -s 2>/dev/null || hostname)"
fi

# Starship Prompt
if command -v starship &> /dev/null; then
  eval "$(starship init zsh)"

  # Slow-filesystem opt-out for git_branch / git_status. On some
  # filesystems (network mounts, FUSE overlays) git's repo-discovery
  # walks the parent directory tree and each `..` is slow, so the
  # git_branch module can spend hundreds of ms per prompt. We can
  # render those prompts with a derived "fast" variant of the config
  # that has [git_branch] and [git_status] disabled.
  #
  # The fast config (~/.config/starship-fast.toml) is generated from
  # starship.toml at install time — see install.sh's
  # "Generating starship-fast.toml" block. Do not edit by hand.
  #
  # The set of paths to treat as "slow" is configurable via the
  # STARSHIP_FAST_PATHS env var (colon-separated zsh glob patterns).
  # The public default is empty (no swap happens). Hosts that need
  # the swap export STARSHIP_FAST_PATHS in a host-specific drop-in
  # (e.g. ~/.zshenv.d/<class>.sh).
  #
  # Starship reads STARSHIP_CONFIG on every `starship prompt`
  # invocation, so flipping it via a chpwd hook takes effect on the
  # next prompt with zero plugin reinitialization.
  if [[ -f "$HOME/.config/starship-fast.toml" && -n "$STARSHIP_FAST_PATHS" ]]; then
    autoload -Uz add-zsh-hook
    _starship_config_swap() {
      local pattern
      for pattern in ${(s.:.)STARSHIP_FAST_PATHS}; do
        # Use zsh's [[ pattern matching ]] so glob chars in
        # STARSHIP_FAST_PATHS work (e.g. /mnt/slow/*).
        if [[ "$PWD" == ${~pattern} ]]; then
          export STARSHIP_CONFIG="$HOME/.config/starship-fast.toml"
          return
        fi
      done
      unset STARSHIP_CONFIG  # falls back to ~/.config/starship.toml
    }
    add-zsh-hook chpwd _starship_config_swap
    _starship_config_swap   # apply immediately for the initial $PWD
  fi
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

# Initialize completion system.
#
# `compinit -C` skips the security check that scans every fpath dir for
# world-writable files. Saves ~150ms per shell start. The check is still
# valuable occasionally (a malicious completion file in a writable
# fpath dir could ride along on next compinit), so we run the FULL
# compinit once a week — keyed on the mtime of ~/.zcompdump. If the
# dump is older than 7 days, do the slow secure init; otherwise fast.
autoload -Uz compinit
_zcompdump="${ZDOTDIR:-$HOME}/.zcompdump"
if [[ -n "$_zcompdump"(#qN.mh+168) ]]; then
  # zsh glob qualifier: `mh+168` = mtime-in-hours older than 168 (7 days).
  # The match-list is non-empty iff the file exists AND is older than 7d.
  compinit
else
  compinit -C
fi
unset _zcompdump

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
# zsh-autosuggestions perf tuning. Defaults run synchronous history
# search on every keystroke, which produces visible per-key lag on
# slow disks (mac APFS cold cache, network mounts). Three knobs:
#   * USE_ASYNC=1            — fetch suggestions in a background process
#                              so keystrokes echo immediately.
#   * BUFFER_MAX_SIZE=20     — disable suggestions on lines longer than
#                              20 chars (where the search is most
#                              expensive and the suggestion is least
#                              useful — you've already typed enough to
#                              know what you want).
#   * MANUAL_REBIND=1        — don't reattach the widgets on every
#                              prompt redraw; saves ~10ms per prompt.
#                              (We never re-source plugins mid-session.)
ZSH_AUTOSUGGEST_USE_ASYNC=1
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
ZSH_AUTOSUGGEST_MANUAL_REBIND=1

# Source plugins from local directory
[[ -f "$ZSH_PLUGIN_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && source "$ZSH_PLUGIN_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh"
[[ -f "$ZSH_PLUGIN_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && source "$ZSH_PLUGIN_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# FZF removed 2026-05-11. The `eval "$(fzf --zsh)"` block was producing
# cosmetic `(eval):1: can't change option: zle` warnings on every
# non-interactive shell start, and the operator preferred zsh's built-in
# Ctrl-R history search over the fzf-replaced TUI picker. To restore:
# add `fzf = "latest"` to ~/.config/mise/config.toml and source
# `$(fzf --zsh)` here.

# Wedge-recovery widget. Bound to Ctrl-X Ctrl-R. When a TUI app (vim,
# less, an agent CLI, an SSH session that died ungracefully) leaves
# the terminal in a broken state — mouse-tracking on, bracketed-paste
# off, cursor in vi NORMAL mode, raw input mode, alt-screen still
# active — this widget restores known-good defaults in one keystroke.
#
# What it does:
#   * stty sane                   — restore canonical line discipline
#                                   (echo, signals, line buffering).
#   * `\e[?1000l \e[?1002l \e[?1003l \e[?1006l`
#                                 — disable all four mouse-reporting
#                                   modes (X10/click, drag, all-events,
#                                   SGR-encoded).
#   * `\e[?2004h`                 — re-enable bracketed-paste (some
#                                   apps disable it on exit and forget
#                                   to restore).
#   * `\e[?1049l`                 — leave alt-screen if we're stuck in
#                                   it (causes the "scrollback is gone"
#                                   wedge after an aborted vim).
#   * `\e[?25h`                   — show cursor (vim/less hide it on
#                                   crash).
#   * `tput reset` is intentionally NOT used — it clears the screen,
#                                   which destroys context. We restore
#                                   modes without scrolling.
#   * bindkey -e                  — return to emacs keymap (in case a
#                                   stray ESC dropped us into vicmd).
#   * zle reset-prompt            — redraw starship cleanly.
#
# This is a ZLE widget, so it works mid-buffer (your half-typed
# command survives the recovery).
__wedge_recover() {
  stty sane 2>/dev/null
  printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006l\e[?2004h\e[?1049l\e[?25h'
  bindkey -e
  zle reset-prompt
}
zle -N __wedge_recover
bindkey '^X^R' __wedge_recover

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
#                                                    antigravity)
#   dotfiles/zshenv.d/10-env.sh                     (COLORTERM, EDITOR)

# --- 7. Custom Scripts & Integrations ---
# Load Gemini CLI Shortcuts & Functions. These are interactive
# (functions like gswitch operate on the current shell's cwd) so they
# stay here, not in zshenv.
[[ -f ~/dev/dotfiles/.gemini-scripts/gemini-functions.sh ]] && source ~/dev/dotfiles/.gemini-scripts/gemini-functions.sh
