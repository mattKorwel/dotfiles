#!/bin/bash
rm "$(which starship )" 2> /dev/null
rm -rf $HOME/.oh-my-zsh 2> /dev/null
rm -rf $HOME/.zsh*  2> /dev/null
sudo apt remove --purge -y zsh
sudo apt autoremove -y