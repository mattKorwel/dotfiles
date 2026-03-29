# --- Git & Workspace Shortcuts ---

# Helper to find where a branch is checked out
function _get_wt_path() {
  local branch=$1
  git worktree list --porcelain | grep -B 2 "branch refs/heads/$branch" | grep "^worktree " | cut -d ' ' -f 2-
}

function gswitch() {
   local branch="$1"
   if [[ -z "$branch" ]]; then
       echo "Usage: gswitch <branch>"
       return 1
   fi
   if [[ "$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" == "$branch" ]]; then
       git pull
       return
   fi
   local worktree_path=$(_get_wt_path "$branch")
   if [[ -n "$worktree_path" ]]; then
       echo "📍 Branch '$branch' is already active in worktree: $worktree_path"
       cd "$worktree_path"
       return
   fi
   if git show-ref --quiet "$branch" || git ls-remote --exit-code --heads origin "$branch" &>/dev/null; then
       git co . && git co "$branch"
   else
       echo "🌱 Creating new branch '$branch' from HEAD..."
       git co . && git co -b "$branch"
   fi
}

function gadd() {
   git ci -am "$*" && git push -u origin HEAD
}

# --- Gemini CLI Version Manager (High Performance) ---

# Isolated aliases for specific channels
function gnightly() { ~/.gcli/nightly/node_modules/.bin/gemini "$@"; }
function gstable() { ~/.gcli/stable/node_modules/.bin/gemini "$@"; }
function gpreview() { ~/.gcli/preview/node_modules/.bin/gemini "$@"; }

# NOTE: The main 'gemini' command is managed by mise in ~/.config/mise/config.toml
# to ensure it works across zsh/bash subshells without alias issues.

# Update all versions at once
function gupdate-all() {
  echo "Updating Gemini CLI versions..."
  mkdir -p ~/.gcli/main ~/.gcli/nightly ~/.gcli/stable ~/.gcli/preview
  
  echo "📡 Refreshing 'gemini' (GitHub main branch)..."
  npm install --prefix ~/.gcli/main https://github.com/google-gemini/gemini-cli#main
  
  echo "📡 Refreshing 'gnightly' (npm @nightly)..."
  npm install --prefix ~/.gcli/nightly @google/gemini-cli@nightly
  
  echo "📡 Refreshing 'gstable' (npm @latest)..."
  npm install --prefix ~/.gcli/stable @google/gemini-cli@latest
  
  echo "📡 Refreshing 'gpreview' (npm @preview)..."
  npm install --prefix ~/.gcli/preview @google/gemini-cli@preview
  
  # Ensure mise reshim is called to pick up potential binary changes
  mise reshim
  
  echo "\n✅ All versions updated! Use 'gemini', 'gnightly', 'gstable', or 'gpreview'."
}
