ZSH_DISABLE_COMPFIX=true
export ZSH="/Users/mattkorwel/.oh-my-zsh"
ZSH_THEME="spaceship"
plugins=(git)

function gadd(){
    message="$*"
    git ci -am "${message}" && git push -u origin HEAD
}

funciton gfresh(){
    branch="$*"
    git co . && git co main && git pull && git co -b ${branch}
}

funciton gswitch(){
    branch="$*"
    git co . && git co main && git pull && git co ${branch}
}

export DEV_USER=makorwel

alias k="kubectl"
alias a="script/apply"
alias dr="k delete --ignore-not-found --grace-period=0 --force -R -f rendered"
alias dpvc="k delete pvc --all"
alias dpv="k delete pv --all"
alias ddb="az mysql db delete -g $DEV_USER -s $DEV_USER -n github_enterprise -y && az mysql db delete -g $DEV_USER -s $DEV_USER -n launch_deployer -y && az mysql db delete -g $DEV_USER -s $DEV_USER -n launch_credz -y && az mysql db delete -g $DEV_USER -s $DEV_USER -n actions_workflow_payloads -y"
alias cleandev="dr && dpvc && dpv && ddb"
[[ /usr/local/bin/kubectl ]] && source <(kubectl completion zsh)


export PATH="$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH"
