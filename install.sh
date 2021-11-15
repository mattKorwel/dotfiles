#!/bin/bash

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
git config --global commit.gpgsign true

# git completion
curl -fLo ~/.zsh/git-completion.zsh --create-dirs https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.zsh

# links
# delete existing .zshrc if it already exists
if [[ -n "${HOME}/.zshrc" ]]; then
  rm "${HOME}/.zshrc"
fi

if [[ -d "${HOME}/.oh-my-zsh" ]]; then
  rm -rf "${HOME}/.oh-my-zsh"  
fi

# links
ln -sf /workspaces/.codespaces/.persistedshare/dotfiles/.zshrc ~/
mkdir -p ~/.starship && ln -sf /workspaces/.codespaces/.persistedshare/dotfiles/config.toml ~/.starship

# zsh 
if [ "$SHELL" != "/usr/bin/zsh" ]; then
    sudo apt install -y zsh
    sh -c "$(curl -fsSL https://starship.rs/install.sh)" -- --platform unknown-linux-musl --yes
    sh -c " KEEP_ZSHRC=yes CHSH=no RUNZSH=no ZSH=$HOME/.oh-my-zsh $(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi
