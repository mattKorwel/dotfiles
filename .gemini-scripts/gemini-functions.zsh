# --- Worktree-based Project Management ---

# Helper to find where a branch is checked out
function _get_wt_path() {
  local branch=$1
  # Use porcelain to find the worktree path for a specific branch
  # It looks for the 'branch refs/heads/BRANCH' line and grabs the 'worktree' path 2 lines above
  git worktree list --porcelain | grep -B 2 "branch refs/heads/$branch" | grep "^worktree " | cut -d ' ' -f 2-
}

function rswitch() {
  local branch=$1
  local base_dir="$HOME/dev/main"
  local target_dir="$HOME/dev/$branch"

  if [[ -z "$branch" ]]; then
    echo "📂 Usage: rswitch <branch>"
    return 1
  fi

  # 1. Ensure base repo exists
  if [[ ! -d "$base_dir" ]]; then
    echo "🌱 Initializing base repository in $base_dir..."
    mkdir -p "$HOME/dev"
    gh repo clone google-gemini/gemini-cli "$base_dir"
  fi

  # 2. If switching to main, just go to base
  if [[ "$branch" == "main" ]]; then
    cd "$base_dir" && git pull
    return
  fi

  # 3. Check if branch is already checked out ANYWHERE
  cd "$base_dir"
  local existing_wt=$(_get_wt_path "$branch")
  if [[ -n "$existing_wt" ]]; then
    echo "📍 Branch '$branch' is already checked out at: $existing_wt"
    cd "$existing_wt"
    return
  fi

  # 4. Create worktree if directory doesn't exist
  if [[ ! -d "$target_dir" ]]; then
    echo "🌿 Creating worktree for $branch..."
    git fetch origin

    # Check if branch exists locally first
    if git show-ref --verify --quiet "refs/heads/$branch"; then
      git worktree add "$target_dir" "$branch"
    # Then check if it exists on origin
    elif git ls-remote --exit-code --heads origin "$branch" &>/dev/null; then
      git worktree add -b "$branch" "$target_dir" "origin/$branch"
    else
      # Create new branch from origin/main
      git worktree add -b "$branch" "$target_dir" origin/main
    fi
  fi

  cd "$target_dir"
}

function rcleanup() {
  local branch=$1
  local target_dir="$HOME/dev/$branch"
  
  if [[ "$branch" == "main" ]]; then
      echo "❌ Cannot remove the base repository (main)."
      return 1
  fi

  if [[ -d "$target_dir" ]]; then
      echo "🔥 Removing worktree: $branch"
      cd "$HOME/dev/main"
      git worktree remove "$target_dir" --force
      rm -rf "$target_dir"
  fi
}

function review() {
  local pr_number=$1
  local branch_name=$2
  if [[ -z "$pr_number" ]]; then
    echo "Usage: review <pr_number> [branch_name]"
    return 1
  fi

  local base_dir="$HOME/dev/main"
  cd "$base_dir"
  
  if [[ -z "$branch_name" ]]; then
    branch_name=$(gh pr view $pr_number --json headRefName -q .headRefName 2>/dev/null)
    [[ -z "$branch_name" ]] && branch_name="pr-$pr_number"
  fi
  
  local target_dir="$HOME/dev/$branch_name"
  echo "📡 Provisioning worktree for PR #$pr_number..."
  git fetch origin "pull/$pr_number/head:refs/pull/$pr_number/head"
  [[ -d "$target_dir" ]] || git worktree add "$target_dir" "refs/pull/$pr_number/head"
  cd "$target_dir"

  # Run the Node-based parallel worker
  npx tsx "$HOME/dev/main/.gemini/skills/deep-review/scripts/worker.ts" "$pr_number"

  # Final interactive handoff
  gnightly "PR #$pr_number verification is complete. Please read the logs in .gemini/logs/review-$pr_number/ and provide your final assessment."
}

function npx-gemini() {
    npx --yes clear-npx-cache && npx --yes --loglevel=silly https://github.com/google-gemini/gemini-cli#${1:-main}
}

alias git-clean-branches="git co . && git co main && git branch | grep -v '^[ *]*main$' | xargs git branch -D"

# Gemini CLI Version Manager (High Performance)
function gstable() { ~/.gcli/stable/node_modules/.bin/gemini "$@"; }
function gnightly() { ~/.gcli/nightly/node_modules/.bin/gemini "$@"; }
function gpreview() { ~/.gcli/preview/node_modules/.bin/gemini "$@"; }
function gemini() { gnightly "$@"; }

# Update all versions at once
function gupdate-all() {
  echo "Updating Gemini CLI versions..."
  npm install --prefix ~/.gcli/stable @google/gemini-cli@latest
  npm install --prefix ~/.gcli/nightly @google/gemini-cli@nightly
  npm install --prefix ~/.gcli/preview @google/gemini-cli@preview
  echo "Done! Use gstable, gnightly, or gpreview."
}

# --- Remote Workstation Helpers ---

# Run command on remote in the corresponding project folder
function rrun() {
  local current_dir=$(basename "$PWD")
  echo "🚀 Running '$@' on remote: ~/dev/$current_dir"
  ssh cli "cd ~/dev/$current_dir && $@"
}

# Run command on remote in the background with logging
function rbg() {
  local current_dir=$(basename "$PWD")
  local log_file="/tmp/remote_task_$(date +%s).log"
  echo "📡 Offloading to cli: ~/dev/$current_dir"
  echo "📝 Log file on remote: $log_file"
  ssh cli "mkdir -p ~/dev/$current_dir && cd ~/dev/$current_dir && ($@) > $log_file 2>&1" &
}

# Tail the most recent remote background log
function rtail() {
  ssh cli "ls -t /tmp/remote_task_*.log | head -n 1 | xargs tail -f"
}

# Smart rpush: Provisons remote via rswitch and syncs only uncommitted changes
function rpush() {
  local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [[ -z "$branch" ]]; then
    echo "❌ Not a git repository."
    return 1
  fi

  local remote_dir="~/dev/$branch"

  echo "🔍 Checking remote state for branch: $branch..."
  ssh cli "zsh -ic '[[ -d $remote_dir ]] || rswitch $branch'"

  echo "📦 Syncing uncommitted changes to cli:$remote_dir..."
  # Sync modified, untracked, and deleted files
  git ls-files --others --modified --deleted --exclude-standard | rsync -avz --progress --exclude=".gemini/settings.json" --files-from=- . cli:$remote_dir/
  echo "✅ Sync complete."
}

# Jump to remote project using tmux for persistence
function go-remote() {
  if [[ -z "$1" ]]; then
    echo "📂 Usage: go-remote <branch-name>"
    return 1
  fi

  local branch="$1"
  local session_name="${branch//./_}"

  echo "🚀 Connecting to session '$session_name' on cli..."

  ssh -t cli "tmux attach-session -t $session_name 2>/dev/null || tmux new-session -s $session_name -n '$branch' 'zsh -ic \"rswitch $branch && gemini; zsh\"'"
}
alias gr='go-remote'

function rreview() {
  local pr_number=$1
  if [[ -z "$pr_number" ]]; then
    echo "Usage: rreview <pr_number>"
    return 1
  fi
  
  # Delegate local automation to the portable Node orchestrator
  npx tsx "$HOME/dev/main/.gemini/skills/deep-review/scripts/review.ts" "$pr_number"
}

function async-review() {
  ~/scripts/async-review.sh "$@"
}

function check-async-review() {
  ~/scripts/check-async-review.sh "$@"
}

function gswitch() {
   local branch="$1"
   if [[ -z "$branch" ]]; then
       echo "Usage: gswitch <branch>"
       return 1
   fi

   # If we are already on the branch, just pull
   if [[ "$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" == "$branch" ]]; then
       git pull
       return
   fi

   # 1. Check if branch is already checked out in SOME worktree
   local worktree_path=$(_get_wt_path "$branch")
   if [[ -n "$worktree_path" ]]; then
       echo "📍 Branch '$branch' is already active in worktree: $worktree_path"
       cd "$worktree_path"
       return
   fi

   # 2. Check if branch exists at all (local or remote)
   if git show-ref --quiet "$branch" || git ls-remote --exit-code --heads origin "$branch" &>/dev/null; then
       # Branch exists, just check it out (Git handles tracking automatically)
       git co . && git co "$branch"
   else
       # Branch doesn't exist, create it
       echo "🌱 Creating new branch '$branch' from HEAD..."
       git co . && git co -b "$branch"
   fi
}

# Remote Browser Wrapper
if [[ -n "$SSH_CLIENT" || -n "$SSH_TTY" ]]; then
  function open() {
    for arg in "$@"; do
      if [[ "$arg" == http* ]]; then
        printf "\e]1337;OpenURL=%s\a" "$arg"
        echo -e "If the link didn't open automatically, Cmd-Click here: \e]8;;%s\a%s\e]8;;\a" "$arg" "$arg"
      else
        command open "$arg"
      fi
    done
  }
  export BROWSER="open"
fi

function pr() {
  local remote=""
  local pr_number=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --remote)
        remote="$2"
        shift 2
        ;;
      *)
        pr_number="$1"
        shift
        ;;
    esac
  done

  if [[ -z "$pr_number" ]]; then
    echo "📂 Usage: pr [--remote <hostname>] <pr_number>"
    return 1
  fi

  # 1. Query gh for the branch name.
  local base_dir="$HOME/dev/main"
  local branch_name=$(cd "$base_dir" && gh pr view "$pr_number" --json headRefName -q .headRefName 2>/dev/null)

  if [[ -z "$branch_name" ]]; then
    echo "❌ Could not find branch for PR #$pr_number"
    return 1
  fi

  if [[ -n "$remote" ]]; then
    echo "🚀 Provisioning remote worktree for branch '$branch_name' (PR #$pr_number) on $remote..."
    ssh -t "$remote" "zsh -ic \"rswitch $branch_name && gemini; zsh\""
  else
    # 2. Switch to the worktree using existing rswitch function.
    echo "🚀 Provisioning worktree for branch '$branch_name' (PR #$pr_number)..."
    rswitch "$branch_name"

    # 3. Run gemini in the current window.
    gemini
  fi
}

function go() {
  local target="$1"
  local remote=""

  # Handle --remote flag if provided
  if [[ "$1" == "--remote" ]]; then
    remote="$2"
    target="$3"
  fi

  if [[ -z "$target" ]]; then
    echo "📂 Usage: go [--remote <hostname>] <branch-name|pr-number>"
    return 1
  fi

  # 1. Detect if target is a PR number (all digits)
  if [[ "$target" =~ ^[0-9]+$ ]]; then
    local pr_number="$target"
    echo "🔍 Querying PR #$pr_number..."
    local branch_name=$(cd "$HOME/dev/main" && gh pr view "$pr_number" --json headRefName -q .headRefName 2>/dev/null)

    if [[ -z "$branch_name" ]]; then
      echo "❌ Could not find branch for PR #$pr_number"
      return 1
    fi
    target="$branch_name"
  fi

  # 2. Handoff to existing logic
  if [[ -n "$remote" ]]; then
    echo "🚀 Provisioning remote worktree for branch '$target' on $remote..."
    ssh -t "$remote" "zsh -ic \"rswitch $target && gemini; zsh\""
  else
    echo "🚀 Switching to branch '$target'..."
    rswitch "$target"
    gemini
  fi
}

gh-fail-summary() {
  # Get the latest run ID for the current branch
  local run_id=$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')

  if [ -z "$run_id" ]; then
    echo "No recent runs found for this branch."
    return 1
  fi

  echo "Checking failures for Run ID: $run_id..."
  
  # List all failed jobs with their IDs and Names
  gh run view "$run_id" --json jobs --jq '
    .jobs[] | 
    select(.conclusion=="failure") | 
    "❌ Job: \(.name)\n   Log: \(.url)\n   ID:  \(.databaseId)\n"'
}

# CI Monitor (Node-based)
function gmonitor() {
  node ~/dev/dotfiles/.gemini-scripts/ci-monitor.mjs "$@"
}

# CI Monitor + Auto-Test

# CI Monitor + Auto-Test/Lint

# CI Monitor + Auto-Test/Lint

# CI Monitor + Auto-Test/Lint
function gcheck() {
  local tmp_out=$(mktemp)
  node ~/dev/dotfiles/.gemini-scripts/ci-monitor.mjs "$@" | tee $tmp_out
  
  # Robustly extract commands by looking for the line AFTER the emoji
  local lint_cmd=$(grep -A 1 "🚀 Run this to verify lint fixes:" $tmp_out | tail -n 1 | grep "npm")
  local test_cmd=$(grep -A 1 "🚀 Run this to verify fixes:" $tmp_out | tail -n 1 | grep "npm")

  if [ -n "$test_cmd" ] || [ -n "$lint_cmd" ]; then
    echo -e "\n📦 CI Failures detected. Running local verification...\n"
    
    if [ -n "$lint_cmd" ]; then
      echo "Running Lint: $lint_cmd"
      eval "$lint_cmd"
    fi
    
    if [ -n "$test_cmd" ]; then
      echo "Running Tests: $test_cmd"
      eval "$test_cmd"
    fi
  fi
  rm "$tmp_out"
}



