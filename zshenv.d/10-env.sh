# 10-env.sh — universal env vars for ALL zsh invocations.
#
# Sourced by ~/.zshenv (loader globs ~/.zshenv.d/*.sh). Public,
# non-secret, non-host-specific. Operator-specific PATHs live in
# dotfiles-private/configs/zshenv.d/00-path.sh.

# Color terminal advertise-string. Most modern terminals (iTerm2,
# WezTerm, kitty, alacritty, gnome-terminal, konsole) support truecolor;
# advertising it lets ls/grep/git emit 24-bit color when piped to a tty.
# Harmless on terminals that don't support it.
export COLORTERM=truecolor

# Prefer vim if installed; fall back to vi. Affects `git commit` etc.
# from non-interactive contexts that respect $EDITOR.
[[ -z "$EDITOR" ]] && {
  if command -v vim >/dev/null 2>&1; then
    export EDITOR=vim
  elif command -v nvim >/dev/null 2>&1; then
    export EDITOR=nvim
  else
    export EDITOR=vi
  fi
}
[[ -z "$VISUAL" ]] && export VISUAL="$EDITOR"
