# ~/.zshenv — sourced by zsh for ALL invocations:
#   - login shells (interactive at terminal start)
#   - non-login interactive shells (new terminal tabs)
#   - non-interactive shells (e.g. ssh remote-host 'cmd')
#
# That last case is the reason this file exists: ~/.zshrc only fires
# for interactive shells, so PATH set there isn't visible to
# `ssh host 'ori --version'`. Anything that needs to be on PATH for
# remote command execution belongs here (or in ~/.zshenv.d/).
#
# Mirrors the ~/.zshrc.d/ + dotfiles-private pattern: this file is the
# loader; per-tool fragments live in ~/.zshenv.d/ so multiple installers
# (dotfiles, ori install, future ones) can drop conflict-free files.
#
# Keep this file MINIMAL: env vars only (PATH, locale, editor). No
# aliases, no functions, no expensive command lookups — these run on
# every shell instance including SSH command invocations.

# Drop-in loader (zsh glob qualifier (N) makes empty matches no-op).
for _f in "$HOME"/.zshenv.d/*.sh(N); do
  source "$_f"
done
unset _f
