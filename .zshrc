# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"
# The following lines were added by compinstall

# Set up the prompt

autoload -Uz promptinit
promptinit

setopt histignorealldups sharehistory
################################################################################
#Autocompletions and other ZSH config
################################################################################

export GEMINI_API_KEY=""

#Autocompletion
zstyle ':completion:*' menu yes select
zstyle ':completion::complete:*' use-cache 1        #enables completion caching
zstyle ':completion::complete:*' cache-path ~/.zsh/cache

#to know the key binding for a key, run `od -c` and press the key
bindkey '^[[3~' delete-char           #enables DEL key proper behaviour
bindkey '^[[1;5C' forward-word        #[Ctrl-RightArrow] - move forward one word
bindkey '^[[1;5D' backward-word       #[Ctrl-LeftArrow] - move backward one word
bindkey  "^[[H"   beginning-of-line   #[Home] - goes at the begining of the line
bindkey  "^[[F"   end-of-line         #[End] - goes at the end of the line
bindkey '\t'   complete-word          # tab          | complete
bindkey '\t\t' autosuggest-accept       # shift + tab  | autosuggest

autoload -Uz compinit && compinit -i

HISTFILE=~/.histfile
HISTSIZE=10000
SAVEHIST=$HISTSIZE
setopt appendhistory
setopt share_history        #share history between multiple instances of zsh

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line if pasting URLs and other text is messed up.
DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable auto-setting terminal title.
 DISABLE_AUTO_TITLE="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
HIST_STAMPS="mm/dd/yyyy"

plugins=(
    git
    docker
    golang
    node
    zsh-syntax-highlighting
    zsh-autosuggestions
)

source $ZSH/oh-my-zsh.sh

function gadd() {
    message="$*"
    git ci -am "${message}" && git push -u origin HEAD
}

function gswitch() {
    branch="$*"
    local new_branch_flag=""

    # local remote_name=remotes/origin/${branch}
    # if [[ "$(git br -ra | grep ${remote_name})" == "${remote_name}" ]]; then
    #     echo "branch already exists on remote"
    #     fi

    if git ls-remote --exit-code --heads origin ${branch} &> /dev/null; then
    else
        new_branch_flag="-b"
    fi
    
    git co . && git co main && git pull && git co ${new_branch_flag} ${branch} 
}

source ~/powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/home/mattkorwel/.gloucd-cli/google-cloud-sdk/path.zsh.inc' ]; then . '/home/mattkorwel/.gloucd-cli/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/home/mattkorwel/.gloucd-cli/google-cloud-sdk/completion.zsh.inc' ]; then . '/home/mattkorwel/.gloucd-cli/google-cloud-sdk/completion.zsh.inc'; fi


# Add these lines to your ~/.bashrc or ~/.zshrc
export GOROOT=~/go
export GOPATH=~/go-workspace
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin

test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
alias ls='ls --color=auto'
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'

alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias diff='diff --color=auto'

# some more ls aliases
alias ll='ls -alF --color=always --group-directories-first'
alias la='ls -A'
alias l='ls -CF'

export LS_COLORS='di=04;93:fi=01;36:ex=01;31;40:*.txt=01;32:*.pdf=01;33'
export LS_COLORS="di=01;34:ln=01;35:so=01;32:pi=01;33:ex=31:bd=34;46\:cd=34;43:su=30;41:sg=30;46:ow=30;42:tw=30;43:fi=01;93"

function gemini() {
    local branch="main"
    local loglevel="warn"
    local do_refresh=false
    local passthrough_args=()
    local branch_found=false
    local do_local=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -l|--local)
                do_local=true
                shift
                ;;
            -r|--refresh)
                do_refresh=true
                shift
                ;;
            -v|--verbose)
                loglevel="verbose"
                shift
                ;;
            -*) # Any other flag is passed through to the app
                passthrough_args+=("$1")
                shift
                ;;
            *) # Non-flag argument
                if ! $branch_found; then
                    # First non-flag is the branch
                    branch="$1"
                    branch_found=true
                else
                    # Subsequent non-flags are passed through to the app
                    passthrough_args+=("$1")
                fi
                shift
                ;;
        esac
    done

    # Use the provided branch, or default to main
    local msg="with code from branch origin/${branch}"
    packge_location="https://github.com/google-gemini/gemini-cli#${branch}"
    if [[ "$do_local" = true ]]; then
        packge_location="./packages/cli"
        msg="with code from local file system"
    fi

    echo "Running Gemini CLI ${msg} with refresh=${do_refresh} and passing through '${passthrough_args[@]}'"

    if [[ "$do_refresh" = true ]]; then
        npx --yes clear-npx-cache
    fi
    
    # Pass all remaining arguments to the npx command.
    npx --loglevel "$loglevel" --yes ${packge_location} "${passthrough_args[@]}"
}

alias git-clean-branches="git co . && git co main && git branch | grep -v '^[ *]*main$' | xargs git branch -D"
