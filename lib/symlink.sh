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

# clone_or_pull <git-url> <dest-dir>
#   Clone if missing, ff-pull if present.
clone_or_pull() {
  local url=$1
  local dest=$2

  if [[ -d "$dest/.git" ]]; then
    echo "📡 Updating $(basename "$dest")..."
    git -C "$dest" pull --ff-only
    return $?
  fi

  echo "📡 Cloning $(basename "$dest")..."
  mkdir -p "$(dirname "$dest")"
  git clone "$url" "$dest"
}
