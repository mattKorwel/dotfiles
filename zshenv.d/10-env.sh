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

# Prefer nano if installed; avoid vim/vi. Affects `git commit` etc.
# from non-interactive contexts that respect $EDITOR.
[[ -z "$EDITOR" ]] && {
  if command -v nano >/dev/null 2>&1; then
    export EDITOR=nano
  elif command -v pico >/dev/null 2>&1; then
    export EDITOR=pico
  else
    export EDITOR=vi
  fi
}
[[ -z "$VISUAL" ]] && export VISUAL="$EDITOR"

# Stop `mise` from walking the filesystem above $HOME looking for
# parent mise.toml overrides. We use only the global
# ~/.config/mise/config.toml; any walk above $HOME is wasted work,
# and on slow filesystems (network mounts, FUSE overlays) every `..`
# stat pays an overlay tax. Setting this here (zshenv.d) is required
# because `ceiling_paths` is an early-init setting — mise reads it
# BEFORE parsing ~/.config/mise/config.toml, so the toml entry is a
# no-op.
export MISE_CEILING_PATHS="$HOME"
