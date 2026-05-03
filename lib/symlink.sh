#!/bin/bash
# Shared helpers for dotfiles + dotfiles-private install scripts.
# Source me; don't exec me.

# DOTFILES_BACKUP_DIR is set by the caller. Default if unset.
: "${DOTFILES_BACKUP_DIR:=$HOME/dev/dotfiles/.backups}"

# Pretty timestamp for backup filenames (locale-independent, sortable).
_dotfiles_ts() { date +%F_%H%M%S; }

# backup_and_link <src> <dst>
#   Symlink src → dst. If dst already exists as a non-symlink file/dir,
#   move it to $DOTFILES_BACKUP_DIR with a timestamp first. If dst is
#   already a symlink (correct or otherwise), just re-point it.
backup_and_link() {
  local src=$1
  local dst=$2

  # Already pointing at the right place? Nothing to do.
  if [[ -L "$dst" ]] && [[ "$(readlink "$dst")" == "$src" ]]; then
    return 0
  fi

  if [[ -e "$dst" && ! -L "$dst" ]]; then
    mkdir -p "$DOTFILES_BACKUP_DIR"
    local name=$(basename "$dst")
    local backup="$DOTFILES_BACKUP_DIR/${name}.bak.$(_dotfiles_ts)"
    echo "💾 Backing up existing $dst → $backup"
    mv "$dst" "$backup"
  elif [[ -L "$dst" ]]; then
    rm "$dst"
  fi

  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  echo "🔗 $dst → $src"
}

# clone_or_pull <git-url> <dest-dir> [--gh]
#   Clone if missing, ff-pull if present. With --gh, uses `gh repo clone`
#   (for private repos) instead of `git clone`. Honors $MISE_BIN if set.
clone_or_pull() {
  local url=$1
  local dest=$2
  local use_gh=${3:-}

  if [[ -d "$dest/.git" ]]; then
    echo "📡 Updating $(basename "$dest")..."
    git -C "$dest" pull --ff-only
    return $?
  fi

  echo "📡 Cloning $(basename "$dest")..."
  mkdir -p "$(dirname "$dest")"
  if [[ "$use_gh" == "--gh" ]]; then
    if [[ -n "${MISE_BIN:-}" ]] && [[ -x "$MISE_BIN" ]]; then
      "$MISE_BIN" exec -- gh repo clone "$url" "$dest"
    else
      gh repo clone "$url" "$dest"
    fi
  else
    git clone "$url" "$dest"
  fi
}

# ensure_gh_auth
#   Ensure `gh` is authenticated. Honors $MISE_BIN.
#
#   Three modes, in priority order:
#     1. $GITHUB_PAT set → non-interactive: pipe to `gh auth login --with-token`
#     2. tty present → interactive `gh auth login` (browser flow)
#     3. no tty + no PAT → fail loudly so the caller knows the install will
#        skip private-repo steps
ensure_gh_auth() {
  local gh_cmd=(gh)
  if [[ -n "${MISE_BIN:-}" ]] && [[ -x "$MISE_BIN" ]]; then
    gh_cmd=("$MISE_BIN" exec -- gh)
  fi
  if "${gh_cmd[@]}" auth status >/dev/null 2>&1; then
    return 0
  fi
  if [[ -n "${GITHUB_PAT:-}" ]]; then
    echo "🔐 Authenticating gh with $GITHUB_PAT (non-interactive)..."
    echo "${GITHUB_PAT}" | "${gh_cmd[@]}" auth login --with-token
    return $?
  fi
  if [[ -t 0 ]] && [[ -t 1 ]]; then
    echo "🔐 GitHub authentication required for private repositories..."
    "${gh_cmd[@]}" auth login
    return $?
  fi
  echo "⚠️  gh not authenticated and no \$GITHUB_PAT and no tty. Skipping." >&2
  echo "   Set GITHUB_PAT=<token> in env to auth non-interactively." >&2
  return 1
}
