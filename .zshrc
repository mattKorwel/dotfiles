export ZSH="${HOME}/.oh-my-zsh"
# The following lines were added by compinstall

zstyle ':completion:*' completer _expand _complete _ignored _correct _approximate
zstyle ':completion:*' matcher-list '' 'm:{[:lower:]}={[:upper:]}' 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' 'r:|[._-]=** r:|=** l:|=*'
zstyle :compinstall filename "${HOME}/.zshrc"

autoload -Uz compinit
compinit

# End of lines added by compinstall
# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=100000
bindkey -e
# End of lines configured by zsh-newuser-install

plugins=(
    git
    docker
    thefuck
    helm
    rbenv
    golang
    zsh-syntax-highlighting
    zsh-autosuggestions
)

source $ZSH/oh-my-zsh.sh

function gadd(){
    message="$*"
    git ci -am "${message}" && git push -u origin HEAD
}

funciton gfresh(){
    branch="$*"
    git co . && git co master && git pull && git co -b ${branch}
}

funciton gswitch(){
    branch="$*"
    git co . && git co master && git pull && git co ${branch}
}

export DEV_USER=makorwel
export GPG_TTY=$(tty)

alias brt="bin/rails test $@"

export STARSHIP_CONFIG=~/.starship/config.toml
eval "$(starship init zsh)"
