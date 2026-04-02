### GitHub dev server dotfiles

```shell
cd ~
git clone git@github.com:mattkorwel/dotfiles .dotfiles
.dotfiles/install.sh
```

```pwsh
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/mkorwel/dotfiles/main/setup.ps1'))
```
