#!/bin/bash

# git config
git config --global alias.co=checkout
git config --global alias.br=branch
git config --global alias.ci=commit
git config --global alias.st=status
git config --global user.email=mattkorwel@github.com
git config --global user.name=matt korwel
git config --global remote.origin.prune=true
git config --global pull.rebase=true
git config --global credential.helper=osxkeychain
git config --global github.user=mattKorwel
git config --global push.default=simple
git config --global url.git@github.com:.insteadof=https://github.com/
# git completion
curl -fLo ~/.zsh/git-completion.zsh --create-dirs https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.zsh

# links
ln -s ~/.dotfiles/.zshrc ~/

# zsh 
if [ "$SHELL" != "/usr/bin/zsh" ]; then
    sudo apt install -y zsh
    zsh
fi;
