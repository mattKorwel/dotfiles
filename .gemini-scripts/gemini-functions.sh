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

# --- Gemini CLI Shortcuts ---

# Gemini CLI Prompt Shorthand
function g() {
  gemini -p "if exists read summary.md. then address: $*. when done append any relevant context to summary.md"
}

# Direct Gemini API Call (Flash Lite Preview)
# Usage: gapi <prompt>
function gapi() {
  local prompt="$*"
  if [[ -z "$prompt" ]]; then
    echo "Usage: gapi <prompt>"
    return 1
  fi

  local api_key="${GEMINI_API_KEY:-}"
  if [[ -z "$api_key" && -f ~/.env ]]; then
    api_key=$(grep "^GEMINI_API_KEY=" ~/.env | head -n 1 | cut -d'=' -f2- | tr -d '"' | tr -d "'")
  fi

  if [[ -z "$api_key" ]]; then
    echo "Error: GEMINI_API_KEY not found in environment or ~/.env"
    return 1
  fi

  # Payload construction
  local json_payload
  json_payload=$(printf '{"contents": [{"parts":[{"text": "%s"}]}]}' "$prompt")

  curl -s -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite-preview:generateContent?key=$api_key" \
       -H "Content-Type: application/json" \
       -d "$json_payload"
}

# Gemini CLI: managed entirely by mise (npm:@google/gemini-cli=nightly
# in ~/.config/mise/config.toml). Use plain `gemini` from the prompt.
#
# The per-channel `gnightly` / `gstable` / `gpreview` functions and the
# `gupdate-all` multi-channel installer were removed 2026-05-11. They
# wrote to ~/.gcli/{nightly,stable,preview}/ (~660MB across 4 dupe
# installs) and were never used (zero history hits in 64K lines).
# To restore: see git history for the removal commit.
# Prunes all git worktrees except the main one for a given repo path.
# Uses 'git-common-dir' to ensure we find the owner repo.
# Usage: gcleanup-worktrees [repo_path] [--force]
function gcleanup-worktrees() {
  local target_dir="${1:-.}"
  local force=false
  
  if [[ "$1" == "--force" ]] || [[ "$2" == "--force" ]]; then
    force=true
    if [[ "$1" == "--force" ]]; then target_dir="${2:-.}"; fi
  fi

  # Resolve absolute path for the target
  local abs_target=$(cd "$target_dir" &>/dev/null && pwd)
  if [[ -z "$abs_target" ]]; then
    echo "❌ Error: Directory '$target_dir' not found."
    return 1
  fi

  if ! git -C "$abs_target" rev-parse --is-inside-work-tree &>/dev/null; then
    echo "❌ Error: '$abs_target' is not a git repository."
    return 1
  fi

  # Identify the "Main" directory that owns the worktrees
  local common_dir=$(git -C "$abs_target" rev-parse --git-common-dir)
  local main_dir
  if [[ "$common_dir" == ".git" ]]; then
    main_dir=$(git -C "$abs_target" rev-parse --show-toplevel)
  else
    # In a worktree, common-dir is something like /path/to/main/.git/worktrees/name
    main_dir=$(cd "$abs_target" && cd "$common_dir/../.." && pwd)
  fi

  echo "🧹 Pruning sibling worktrees for: $main_dir"
  
  # Get all worktree paths from the source of truth
  local worktrees=($(git -C "$main_dir" worktree list --porcelain | grep "^worktree " | cut -d' ' -f2))
  
  local count=0
  for wt in "${worktrees[@]}"; do
    # Skip the main working tree
    if [[ "$wt" == "$main_dir" ]]; then continue; fi
    
    echo "🔥 Removing: $wt"
    if [[ "$force" == true ]]; then
      git -C "$main_dir" worktree remove "$wt" --force
    else
      git -C "$main_dir" worktree remove "$wt"
    fi
    ((count++))
  done

  echo "✅ Complete. $count worktrees removed."
}


