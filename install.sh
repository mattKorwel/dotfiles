#!/bin/bash
#
# dotfiles installer — single entry point for mac & linux setup.
#
# Run on a fresh machine (one-liner):
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/mattkorwel/dotfiles/main/install.sh)
#
# Or after cloning:
#   ~/.local/share/dotfiles/install.sh
#
# Google fleet members (mac + corp cloudtops): the canonical bootstrap is
# the at-head install.sh in google3 experimental, which runs chezmoi for
# Google-specific config and then calls THIS script for the cross-machine
# baseline. See:
#   /google/src/head/depot/google3/experimental/users/mattkorwel/home/install.sh
#
# Idempotent: safe to re-run any time. Each step skips itself if already done.
#
# Sections:
#   1. Bootstrap dotfiles repo (clone or pull)
#   2. Symlink shell + tool configs
#   3. Zsh plugins + tool completions
#   4. Mise + runtimes

set -e

# --- Non-interactive mode ---
# Set ORI_INSTALL_YES=1 (or pass --yes) to skip prompts.
for arg in "$@"; do
  case "$arg" in
    --yes|-y)      ORI_INSTALL_YES=1 ;;
  esac
done

# answer_yes <prompt>
#   Echoes "y" if ORI_INSTALL_YES=1, else prompts the user. Lets the rest
#   of the script use one shape: `if [[ "$(answer_yes '...')" =~ ^[Yy]$ ]]`
answer_yes() {
  local prompt=$1
  if [[ "${ORI_INSTALL_YES:-0}" == "1" ]]; then
    echo "y"
    return
  fi
  local ans
  read -r -p "$prompt" ans
  echo "$ans"
}

# --- Configuration ---
REPO_URL="https://github.com/mattkorwel/dotfiles.git"
DOTFILES_DIR="$HOME/.local/share/dotfiles"
export DOTFILES_BACKUP_DIR="$DOTFILES_DIR/.backups"

# --- 1. Bootstrap dotfiles repo ---
echo "🚀 Initializing dotfiles..."
if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
  echo "📡 Cloning dotfiles to $DOTFILES_DIR..."
  command -v git >/dev/null 2>&1 || {
    if [[ "$OSTYPE" == "darwin"* ]]; then
      echo "❌ git not found. Install Apple's Command Line Tools first:" >&2
      echo "     xcode-select --install" >&2
      echo "   Then re-run this script." >&2
      exit 1
    else
      sudo apt-get update && sudo apt-get install -y git
    fi
  }
  mkdir -p "$(dirname "$DOTFILES_DIR")"
  git clone "$REPO_URL" "$DOTFILES_DIR"
else
  echo "📡 Updating dotfiles..."
  git -C "$DOTFILES_DIR" pull --ff-only
fi

# Now we can source the shared helpers.
# shellcheck disable=SC1091
source "$DOTFILES_DIR/lib/symlink.sh"

# --- 2. Symlink shell + tool configs ---
echo
echo "🔗 Linking configs..."

for f in .zshrc .zshenv .bashrc .bash_profile; do
  [[ -f "$DOTFILES_DIR/profiles/$f" ]] && backup_and_link "$DOTFILES_DIR/profiles/$f" "$HOME/$f"
done

# ~/.zshenv.d/ public drop-ins (env vars sourced for ALL zsh, including
# non-interactive ssh). Each file self-gates so it's safe to symlink
# everywhere. Operator-specific PATH lives in dotfiles-private/configs/
# zshenv.d/ (handled below in the private block).
if [[ -d "$DOTFILES_DIR/zshenv.d" ]]; then
  mkdir -p "$HOME/.zshenv.d"
  for sh in "$DOTFILES_DIR"/zshenv.d/*.sh; do
    [[ -f "$sh" ]] || continue
    backup_and_link "$sh" "$HOME/.zshenv.d/$(basename "$sh")"
  done
fi

backup_and_link "$DOTFILES_DIR/.config/mise/config.toml"     "$HOME/.config/mise/config.toml"
backup_and_link "$DOTFILES_DIR/.config/starship.toml"        "$HOME/.config/starship.toml"
backup_and_link "$DOTFILES_DIR/.config/git/gitconfig.shared" "$HOME/.config/git/gitconfig.shared"
backup_and_link "$DOTFILES_DIR/.config/git/allowed_signers"  "$HOME/.config/git/allowed_signers"
backup_and_link "$DOTFILES_DIR/.gemini/settings.json"        "$HOME/.gemini/settings.json"

if [[ "$OSTYPE" == "darwin"* ]]; then
  backup_and_link "$DOTFILES_DIR/.config/aerospace/aerospace.toml" "$HOME/.config/aerospace/aerospace.toml"
fi

if [[ "$OSTYPE" == "darwin"* || "$OSTYPE" == "linux-gnu"* ]]; then
  backup_and_link "$DOTFILES_DIR/.config/tmux/tmux.conf" "$HOME/.tmux.conf"
fi

# Git: include shared config from ~/.gitconfig.
[[ -f "$HOME/.gitconfig" ]] || touch "$HOME/.gitconfig"
if ! grep -q "gitconfig.shared" "$HOME/.gitconfig"; then
  echo "📝 Adding shared git config include to ~/.gitconfig"
  git config --global include.path "$DOTFILES_DIR/.config/git/gitconfig.shared"
fi

# --- 3. Zsh plugins + completions ---
echo
echo "🔌 Setting up zsh plugins..."
ZSH_PLUGIN_DIR="$HOME/.local/share/zsh-plugins"
mkdir -p "$ZSH_PLUGIN_DIR"
for plugin in "zsh-users/zsh-autosuggestions" "zsh-users/zsh-syntax-highlighting" "zsh-users/zsh-completions"; do
  name=$(basename "$plugin")
  if [[ ! -d "$ZSH_PLUGIN_DIR/$name" ]]; then
    echo "📥 Cloning $name..."
    git clone "https://github.com/$plugin.git" "$ZSH_PLUGIN_DIR/$name"
  else
    git -C "$ZSH_PLUGIN_DIR/$name" pull --quiet
  fi
done

echo "⚙️  Generating shell completions..."
ZSH_COMP_DIR="$HOME/.local/share/zsh-completions"
mkdir -p "$ZSH_COMP_DIR"
command -v mise >/dev/null && mise completion zsh > "$ZSH_COMP_DIR/_mise"
command -v gh   >/dev/null && gh   completion -s zsh > "$ZSH_COMP_DIR/_gh"
command -v npm  >/dev/null && npm  completion > "$ZSH_COMP_DIR/npm.zsh"

if command -v gcloud >/dev/null; then
  GCLOUD_SDK_ROOT=$(gcloud info --format="value(basic.sdk_root)" 2>/dev/null || true)
elif command -v mise >/dev/null; then
  GCLOUD_SDK_ROOT=$(mise where gcloud 2>/dev/null || true)
fi
if [[ -n "${GCLOUD_SDK_ROOT:-}" && -d "$GCLOUD_SDK_ROOT" ]]; then
  echo "source '$GCLOUD_SDK_ROOT/completion.zsh.inc'" > "$ZSH_COMP_DIR/gcloud.zsh"
fi

# Static completion files shipped in this dotfiles repo.
if [[ -d "$DOTFILES_DIR/zsh-completions" ]]; then
  for f in "$DOTFILES_DIR/zsh-completions/"_* "$DOTFILES_DIR/zsh-completions/"*.zsh; do
    [[ -f "$f" ]] && backup_and_link "$f" "$ZSH_COMP_DIR/$(basename "$f")"
  done
fi

# --- 4. Mise + runtimes ---
echo
if [[ ! -f "$HOME/.local/bin/mise" ]]; then
  echo "🚀 Installing mise..."
  mkdir -p "$HOME/.local/bin"
  curl -fsSL https://mise.jdx.dev/install.sh | sh > /dev/null
fi
export MISE_BIN="$HOME/.local/bin/mise"
if [[ -f "$MISE_BIN" ]]; then
  export MISE_YES=1
  export PATH="$HOME/.local/bin:$PATH"
  echo "📡 Configuring mise + installing tools..."
  "$MISE_BIN" trust "$DOTFILES_DIR"
  "$MISE_BIN" install
fi

echo
echo "✅ Done. Reload your shell (or run: exec zsh -l)"
