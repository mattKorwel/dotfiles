#!/bin/bash
# Shared helpers for dotfiles + dotfiles-private install scripts.
# Source me; don't exec me.

# DOTFILES_BACKUP_DIR is set by the caller. Default if unset.
: "${DOTFILES_BACKUP_DIR:=$HOME/dev/dotfiles/.backups}"

# Pretty timestamp for backup filenames (locale-independent, sortable).
_dotfiles_ts() { date +%F_%H%M%S; }

# pkg_install <name>
#   Ensure a binary is on PATH; install via brew (mac) or apt (linux).
pkg_install() {
  local pkg=$1
  command -v "$pkg" >/dev/null 2>&1 && return 0
  echo "📦 $pkg not found. Installing..."
  if [[ "$OSTYPE" == "darwin"* ]]; then
    if command -v brew >/dev/null 2>&1; then
      brew install "$pkg"
    else
      echo "⚠️  Homebrew missing. Install $pkg manually." >&2
      return 1
    fi
  else
    sudo apt-get update && sudo apt-get install -y "$pkg"
  fi
}

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
#   Prompt for `gh auth login` if not authenticated. Honors $MISE_BIN.
ensure_gh_auth() {
  local gh_cmd=(gh)
  if [[ -n "${MISE_BIN:-}" ]] && [[ -x "$MISE_BIN" ]]; then
    gh_cmd=("$MISE_BIN" exec -- gh)
  fi
  if "${gh_cmd[@]}" auth status >/dev/null 2>&1; then
    return 0
  fi
  echo "🔐 GitHub authentication required for private repositories..."
  "${gh_cmd[@]}" auth login
}
