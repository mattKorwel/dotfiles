# Installation on a Fresh Machine 🚀

Follow these steps to set up your robust dual-repo dotfiles on any new Linux or macOS machine.

### 0. Zero-Start (No Git?)
If you don't even have `git` yet, you can bootstrap everything with this one-liner. It will install `git`, clone the repo, and run the installer:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/mattkorwel/dotfiles/main/install.sh)"
```

*(Note: This requires your repo to be public first!)*

### 1. Clone the Public Base
First, clone your public dotfiles repository:

```bash
git clone https://github.com/mattkorwel/dotfiles.git ~/dev/dotfiles
cd ~/dev/dotfiles
```

### 2. Run the Installer
Execute the installation script. This will install core tools (zsh, starship, mise, etc.) and set up symlinks:

```bash
./install.sh
```

### 3. Authenticate & Sync Private Extensions
During the installation, you will be prompted to log in to the GitHub CLI. Once authenticated, the script will ask:

> ❓ Would you like to clone your private dotfiles extensions? (y/n)

Type **'y'**. This will:
1. Clone `mattkorwel/dotfiles-private` to `~/dev/dotfiles-private`.
2. Automatically enable your private hooks (Google functions, Levi profile, etc.) via the existing `.zshrc`/`.bashrc` logic.

### 4. Finalize
Restart your shell to apply all changes:
```bash
exec zsh
```

---
**Note for Windows**: Continue to use `install.ps1`. The PowerShell profile now also includes a hook to load `~/dev/dotfiles-private/bootstrap.ps1` if present.
