#!/bin/bash
#
# dotfiles installer — single entry point for mac & linux setup.
#
# Run on a fresh machine:
#   curl -fsSL https://raw.githubusercontent.com/mattkorwel/dotfiles/main/install.sh | bash
# Or after cloning:
#   ~/dev/dotfiles/install.sh
#
# Idempotent: safe to re-run any time. Each step skips itself if already done.
#
# Sections:
#   1. Bootstrap dotfiles repo (clone or pull)
#   2. Symlink shell + tool configs
#   3. Zsh plugins + tool completions
#   4. Mise + runtimes
#   5. Private dotfiles (clone, link cloudcode + ori configs + ssh config)
#   6. Ori binary (download from GitHub Releases) + `ori install`
#      (`ori install` clones the vault, writes cloudcode.json, links
#       AGENTS.md+skills into every harness, installs the git hook, audits)

set -e

# --- Non-interactive mode ---
# Set ORI_INSTALL_YES=1 (or pass --yes) to skip all prompts and default to YES
# for: clone private dotfiles, clone & build ori, clone the .agents vault.
# Combine with $GITHUB_PAT for fully unattended remote installs:
#   GITHUB_PAT=ghp_xxx ORI_INSTALL_YES=1 bash <(curl -fsSL .../install.sh)
for arg in "$@"; do
  case "$arg" in
    --yes|-y) ORI_INSTALL_YES=1 ;;
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
PRIVATE_REPO_URL="https://github.com/mattkorwel/dotfiles-private.git"

DOTFILES_DIR="$HOME/dev/dotfiles"
PRIVATE_DIR="$HOME/dev/dotfiles-private"

# Vault location, clone URL, and clone logic all live in ori
# (~/.ori/vaults.toml + `ori install`). This script no longer needs to
# know about it.

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

for f in .zshrc .bashrc .bash_profile; do
  [[ -f "$DOTFILES_DIR/profiles/$f" ]] && backup_and_link "$DOTFILES_DIR/profiles/$f" "$HOME/$f"
done

backup_and_link "$DOTFILES_DIR/.config/mise/config.toml"     "$HOME/.config/mise/config.toml"
backup_and_link "$DOTFILES_DIR/.config/starship.toml"        "$HOME/.config/starship.toml"
backup_and_link "$DOTFILES_DIR/.config/git/gitconfig.shared" "$HOME/.config/git/gitconfig.shared"
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

# --- 5. Private dotfiles (cloudcode config + corp shell-init) ---
echo
if [[ ! -d "$PRIVATE_DIR" ]]; then
  ans=$(answer_yes "❓ Clone private dotfiles ($PRIVATE_REPO_URL)? (y/N) ")
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    ensure_gh_auth
    clone_or_pull "$PRIVATE_REPO_URL" "$PRIVATE_DIR" --gh
  fi
else
  clone_or_pull "$PRIVATE_REPO_URL" "$PRIVATE_DIR"
fi

if [[ -d "$PRIVATE_DIR" ]]; then
  echo
  echo "🔗 Linking cloudcode plugins + commands from $PRIVATE_DIR..."
  echo "   (cloudcode.json itself is per-machine; 'ori install' below"
  echo "    generates it with this host's paths.)"
  CLOUDCODE_SRC="$PRIVATE_DIR/configs/cloudcode"
  CLOUDCODE_DST="$HOME/.config/cloudcode"
  mkdir -p "$CLOUDCODE_DST/plugins"
  if [[ -d "$CLOUDCODE_SRC/plugins" ]]; then
    for f in "$CLOUDCODE_SRC/plugins/"*.js; do
      [[ -f "$f" ]] || continue
      backup_and_link "$f" "$CLOUDCODE_DST/plugins/$(basename "$f")"
    done
  fi
  if [[ -d "$CLOUDCODE_SRC/commands" ]]; then
    backup_and_link "$CLOUDCODE_SRC/commands" "$CLOUDCODE_DST/commands"
  fi

  # ~/.ori/{classes,bootstrap,vaults}.toml: per-user policy that travels
  # with dotfiles. Sharable across machines (no host-specific paths).
  ORI_CFG_SRC="$PRIVATE_DIR/configs/ori"
  ORI_CFG_DST="$HOME/.ori"
  mkdir -p "$ORI_CFG_DST"
  for f in classes.toml bootstrap.toml vaults.toml; do
    [[ -f "$ORI_CFG_SRC/$f" ]] && backup_and_link "$ORI_CFG_SRC/$f" "$ORI_CFG_DST/$f"
  done

  # ~/.ssh/config: my personal ssh config travels with private dotfiles
  # so I don't lose it across machines. Mode 0644 is fine (no secrets).
  if [[ -f "$PRIVATE_DIR/configs/ssh/config" ]]; then
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    backup_and_link "$PRIVATE_DIR/configs/ssh/config" "$HOME/.ssh/config"
  fi
fi

# --- 6. Ori binary + `ori install` ---
# fetch_ori downloads the matching release binary into ~/.local/bin/ori.
# `ori install` then clones the vault (per ~/.ori/vaults.toml), writes
# cloudcode.json, links AGENTS.md+skills into every harness, installs
# the git pre-commit hook, and runs the fortification audit. Both steps
# are idempotent.
echo
# shellcheck disable=SC1091
source "$DOTFILES_DIR/lib/ori-fetch.sh"
if fetch_ori --dest "$HOME/.local/bin/ori"; then
  "$HOME/.local/bin/ori" install || echo "⚠️  ori install reported issues (continuing)"
else
  echo "⚠️  ori not installed; skipping 'ori install'. Re-run after fixing." >&2
fi

echo
echo "✅ Done. Reload your shell (or run: exec zsh -l)"
