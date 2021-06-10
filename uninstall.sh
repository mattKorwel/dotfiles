#!/bin/bash
sudo rm "$(which starship)"
rm -rf $HOME/.oh-my-zsh
rm -rf $HOME/.zsh*
sudo apt remove --purge -y zsh
sudo apt autoremove -y