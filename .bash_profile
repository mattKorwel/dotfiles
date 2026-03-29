# Gemini CLI bin for cross-shell compatibility
export PATH="$HOME/.gcli/main/node_modules/.bin:$PATH"

# Load .bashrc if it exists
if [ -f ~/.bashrc ]; then
  . ~/.bashrc
fi

# Existing content
# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/mattkorwel/Downloads/google-cloud-sdk/path.bash.inc' ]; then . '/Users/mattkorwel/Downloads/google-cloud-sdk/path.bash.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/mattkorwel/Downloads/google-cloud-sdk/completion.bash.inc' ]; then . '/Users/mattkorwel/Downloads/google-cloud-sdk/completion.bash.inc'; fi

eval "$(/opt/homebrew/bin/brew shellenv)"

export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion
. "$HOME/.cargo/env"
