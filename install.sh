#!/bin/bash
#
# dotfiles installer — single entry point for mac & linux setup.
#
# Run on a fresh machine (one-liner — pipe a PAT in so the private
# dotfiles repo can be cloned without prompts):
#
#   GITHUB_PAT=ghp_xxx ORI_INSTALL_YES=1 \
#     bash <(curl -fsSL https://raw.githubusercontent.com/mattkorwel/dotfiles/main/install.sh)
#
# Or after cloning:
#   ~/dev/dotfiles/install.sh
#
# After this completes, install the brain-only ori with:
#   ori-setup all     # (mac only; sets up GCE server + cattle clients)
#
# Idempotent: safe to re-run any time. Each step skips itself if already done.
#
# Sections:
#   1. Bootstrap dotfiles repo (clone or pull)
#   2. Symlink shell + tool configs
#   3. Zsh plugins + tool completions
#   4. Mise + runtimes
#   5. Private dotfiles (clone, link configs incl. ori-setup, then run
#      private/install.sh which is now a brain-only no-op stub)

set -e

# --- Non-interactive mode ---
# Set ORI_INSTALL_YES=1 (or pass --yes) to skip prompts and default YES
# for: clone private dotfiles. Combine with $GITHUB_PAT for fully
# unattended installs (see the one-liner at the top of this file).
SKIP_PRIVATE=0
for arg in "$@"; do
  case "$arg" in
    --yes|-y)      ORI_INSTALL_YES=1 ;;
    --no-private)  SKIP_PRIVATE=1 ;;
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

# --- 5. Private dotfiles (cloudcode config + corp shell-init + ori-setup) ---
# Skipped on remote workers (bootstrap passes --no-private). Operator
# physical machines clone it for ssh aliases, cloudcode policy, ori-setup,
# and corp shell drop-ins.
echo
if [[ "$SKIP_PRIVATE" == "1" ]]; then
  echo "⏭️  Skipping private dotfiles (--no-private)"
elif [[ ! -d "$PRIVATE_DIR" ]]; then
  ans=$(answer_yes "❓ Clone private dotfiles ($PRIVATE_REPO_URL)? (y/N) ")
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    ensure_gh_auth
    clone_or_pull "$PRIVATE_REPO_URL" "$PRIVATE_DIR" --gh
  fi
else
  clone_or_pull "$PRIVATE_REPO_URL" "$PRIVATE_DIR"
fi

if [[ -d "$PRIVATE_DIR" ]]; then
  # ~/.ori/policies/cloudcode.permission.json: operator's harness
  # permission policy. Used by cloudcode (separate from ori brain).
  ORI_CFG_DST="$HOME/.ori"
  if [[ -f "$PRIVATE_DIR/configs/cloudcode/permission.json" ]]; then
    mkdir -p "$ORI_CFG_DST/policies"
    backup_and_link "$PRIVATE_DIR/configs/cloudcode/permission.json" \
      "$ORI_CFG_DST/policies/cloudcode.permission.json"
  fi

  # ~/dev/bin/ori-setup: bespoke installer for the ori brain (per-fleet:
  # mac/prime/alpha/beta/ori-gce). Symlinked from dotfiles-private/bin/.
  if [[ -f "$PRIVATE_DIR/bin/ori-setup" ]]; then
    mkdir -p "$HOME/dev/bin"
    backup_and_link "$PRIVATE_DIR/bin/ori-setup" "$HOME/dev/bin/ori-setup"
  fi

  # ~/dev/bin/health: bespoke system-wide health check (dotfiles, gcert,
  # ssh, mise, ori brain). File is systemwidehealthcheck.sh; symlinked
  # as 'health' for short typing.
  if [[ -f "$PRIVATE_DIR/bin/systemwidehealthcheck.sh" ]]; then
    mkdir -p "$HOME/dev/bin"
    backup_and_link "$PRIVATE_DIR/bin/systemwidehealthcheck.sh" "$HOME/dev/bin/health"
  fi

  # ~/.config/cloudcode/plugins/*: ESM plugins shared across machines.
  # cloudcode.json itself is per-machine (paths to ori binary embed),
  # so it's NOT symlinked — ori-setup writes it on each host.
  if [[ -d "$PRIVATE_DIR/configs/cloudcode/plugins" ]]; then
    mkdir -p "$HOME/.config/cloudcode/plugins"
    for plugin in "$PRIVATE_DIR"/configs/cloudcode/plugins/*.js; do
      [[ -f "$plugin" ]] || continue
      backup_and_link "$plugin" "$HOME/.config/cloudcode/plugins/$(basename "$plugin")"
    done
  fi

  # ~/.ssh/config: my personal ssh config travels with private dotfiles
  # so I don't lose it across machines. Mode 0644 is fine (no secrets).
  if [[ -f "$PRIVATE_DIR/configs/ssh/config" ]]; then
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    backup_and_link "$PRIVATE_DIR/configs/ssh/config" "$HOME/.ssh/config"
  fi

  # ~/.zshrc.d/ drop-ins from dotfiles-private. Each file is sourced by
  # ~/.zshrc's `for _f in ~/.zshrc.d/*.sh` loop. Self-gating (e.g.
  # g3-mac.sh returns early on non-Darwin) so they're safe everywhere.
  if [[ -d "$PRIVATE_DIR/configs/shell" ]]; then
    mkdir -p "$HOME/.zshrc.d"
    for sh in "$PRIVATE_DIR"/configs/shell/*.sh; do
      [[ -f "$sh" ]] || continue
      backup_and_link "$sh" "$HOME/.zshrc.d/$(basename "$sh")"
    done
  fi

  # ~/.zshenv.d/ drop-ins. ~/.zshenv (loader) is sourced for ALL zsh
  # invocations including non-interactive ssh — that's why this exists
  # separately from ~/.zshrc.d. Anything that needs to be on PATH for
  # `ssh host 'cmd'` belongs in zshenv.d, not zshrc.d.
  if [[ -d "$PRIVATE_DIR/configs/zshenv.d" ]]; then
    mkdir -p "$HOME/.zshenv.d"
    for sh in "$PRIVATE_DIR"/configs/zshenv.d/*.sh; do
      [[ -f "$sh" ]] || continue
      backup_and_link "$sh" "$HOME/.zshenv.d/$(basename "$sh")"
    done
  fi

  # Hand off to the private installer for any operator-only follow-ups.
  if [[ -x "$PRIVATE_DIR/install.sh" ]]; then
    echo
    echo "▶️  Running $PRIVATE_DIR/install.sh"
    "$PRIVATE_DIR/install.sh"
  fi
fi

echo
echo "✅ Done. Reload your shell (or run: exec zsh -l)"
