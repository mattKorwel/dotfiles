#!/bin/bash
sudo apt update && sudo apt upgrade -y
sudo apt install fonts-firacode python3-dev python3-pip python3-setuptools -y
sudo pip3 install thefuck

# git config
git config --global alias.co "checkout"
git config --global alias.br "branch"
git config --global alias.ci "commit"
git config --global alias.st "status"
git config --global user.email "mattkorwel@github.com"
git config --global user.name "matt korwel"
git config --global remote.origin.prune true
git config --global pull.rebase true
git config --global github.user "mattKorwel"
git config --global push.default "simple"
git config --global url.git@github.com:.insteadof=https://github.com/

# git completion
curl -fLo ~/.zsh/git-completion.zsh --create-dirs https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.zsh

# links
ln -s -f ~/.dotfiles/.zshrc ~/
mkdir -p ~/.config && ls -s -f ~/.dotfiles/starship.toml ~/.config

# zsh 
if [ "$SHELL" != "/usr/bin/zsh" ]; then
    sudo apt install -y zsh
    sh -c "$(curl -fsSL https://starship.rs/install.sh)" -- --platform unknown-linux-musl
    sh -c " KEEP_ZSHRC=yes ZSH=$HOME/.oh-my-zsh $(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi;