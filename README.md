# Matt Korwel's Dotfiles 🚀

Portable, robust, and modular dotfiles for Windows (PowerShell/Komorebi), macOS (AeroSpace/Zsh), and Linux/WSL.

## 🛠 Features
- **Cross-Platform**: Consistent experience across Windows, macOS, and Linux.
- **Modern Tooling**: Managed via `mise` (node, python, go, etc.), `starship` prompt, and `zoxide`.
- **Window Management**: Configs for `komorebi` (Win) and `AeroSpace` (Mac).
- **Fast Installation**: One-liner bootstrap for new machines.

## 🚀 Installation

### Zero-Start (No Git?)
If you don't even have `git` yet, you can bootstrap everything with this one-liner. It will install `git`, clone the repo, and run the installer:

```bash
/bin/bash -c "$(curl -fsSL -H 'Cache-Control: no-cache' https://github.com/mattkorwel/dotfiles/raw/main/install.sh)"
```

### Standard Setup
If you already have `git`, clone and run the installer:

```bash
git clone https://github.com/mattkorwel/dotfiles.git ~/dev/dotfiles
cd ~/dev/dotfiles
./install.sh
```

### Authentication & Extensions
During installation, you will be prompted to log in to the GitHub CLI. Once authenticated, the script will offer to clone your private extensions repository (`dotfiles-private`) if it exists. This allows you to securely manage corporate or sensitive configurations without exposing them in this public repository.

## 🪟 Windows Setup
For Windows machines, use the PowerShell installer:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
./install.ps1
```

## 🎯 Architecture

Three repos, one installer:

- **`dotfiles`** (this one, public) — shell rc / starship / mise / aerospace / tmux / git config. The single `install.sh` here is the entry point for everything.
- **`dotfiles-private`** (private) — corp-host shell-init (`shell-init.sh` sourced at every shell start) + cloudcode config (`configs/cloudcode/`).
- **`ori`** + **`.agents`** vault — the agentic context CLI and its content store (cloned + symlinked by `install.sh` if you say yes).

`dotfiles/install.sh` does it all: clones the public repo, links shell + tool configs, installs zsh plugins + completions, runs `mise install`, prompts to clone the private dotfiles, prompts to clone & build ori, prompts to clone the .agents vault, then auto-wires ori into cloudcode (`ori mcp install`) and installs the vault git pre-commit hook (`ori vault install-hook`). Re-run any time; every step is idempotent.

For the design behind ori + the .agents vault, see [`~/dev/.agents/projects/distributed-arch/phase-1/`](https://github.com/mattkorwel/.agents/tree/main/projects/distributed-arch/phase-1) (private).
