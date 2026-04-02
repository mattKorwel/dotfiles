#!/usr/bin/env zsh

# Source the functions script
source /Users/mattkorwel/dev/dotfiles/first/.gemini-scripts/gemini-functions.sh

echo "--- Testing Function Loading ---"
type gnightly
type gstable
type gpreview
type gswitch
type gadd

echo "\n--- Testing gnightly function ---"
# gnightly is an alias to ~/.gcli/nightly/node_modules/.bin/gemini
# We can check if that file exists at least
if [[ -f ~/.gcli/nightly/node_modules/.bin/gemini ]]; then
  echo "gnightly executable found at ~/.gcli/nightly/node_modules/.bin/gemini"
else
  echo "gnightly executable NOT found (this might be expected if gupdate-all hasn't run)"
fi

echo "\n--- Testing gswitch function (dry-run/help) ---"
# gswitch with no arguments prints usage
gswitch

echo "\n--- Testing gswitch with a fake branch (check if it tries to create/checkout) ---"
# Since we are in a git repo, we can see if it detects it.
# We'll use a branch name that doesn't exist.
gswitch test-nonexistent-branch-xyz123
# Note: This might fail if git operations are restricted, but let's see.

echo "\n--- End of tests ---"
