# Gemini CLI bin for cross-shell compatibility (non-login shells)
export PATH="$HOME/.gcli/main/node_modules/.bin:$PATH"

# Mise activation for Bash
if command -v mise &> /dev/null; then
  eval "$(mise activate bash)"
fi

# Load Gemini CLI Shortcuts & Functions
if [ -f "$HOME/.gemini-scripts/gemini-functions.sh" ]; then
  . "$HOME/.gemini-scripts/gemini-functions.sh"
fi


# Gemini Orbit Shell Integration
alias orbit='node "/Users/mattkorwel/.gemini/extensions/orbit/bundle/orbit-cli.js"'
_orbit_completions() {
  COMPREPLY=($(compgen -W "ci install-shell jettison liftoff mission pulse schematic splashdown station uplink" -- "${COMP_WORDS[1]}"))
}
complete -F _orbit_completions orbit
# End Gemini Orbit Shell Integration
