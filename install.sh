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
# trying to normalize set up with codespaces. wip
#git config --global url."git@github.com:".insteadOf https://github.com/
#git config --global commit.gpgsign true
#git config --global user.signingkey 6F8BED0E756DCFAF

# git completion
curl -fLo ~/.zsh/git-completion.zsh --create-dirs https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.zsh

#kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl


# links
# delete existing .zshrc if it already exists
if [[ -n "${HOME}/.zshrc" ]]; then
  rm "${HOME}/.zshrc"
fi

# links
ln -s /workspaces/.codespaces/.persistedshare/dotfiles/.zshrc ~/
mkdir -p ~/.config && ls -s -f ~/.dotfiles/starship.toml ~/.config

# zsh 
if [ "$SHELL" != "/usr/bin/zsh" ]; then
    sudo apt install -y zsh
    sh -c "$(curl -fsSL https://starship.rs/install.sh)" -- --platform unknown-linux-musl --yes
    sh -c " KEEP_ZSHRC=yes CHSH=no RUNZSH=no ZSH=$HOME/.oh-my-zsh $(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

    ZSH_AS="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
    rm -rf ${ZSH_AS} && git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_AS}

    ZSH_SH="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
    rm -rf ${ZSH_SH} && git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_SH}
    
    chsh $(which zsh)
fi
