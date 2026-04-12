# Project Context: Matt Korwel's Dotfiles

## 🎯 System Overview
- **OS**: Windows 11 (Primary) / macOS (Planned Cross-Platform).
- **Dotfiles Root**: `C:\dev\dotfiles`.
- **Primary Shell**: PowerShell 7+ (pwsh).
- **Keyboard**: ZSA Voyager (Configured to utilize `Alt` as the primary WM modifier).

## 🛠 Tooling Stack
- **Runtimes**: `mise` (node, npm, etc).
- **Shell UX**: `starship` (prompt), `zoxide` (navigation), `fzf` (fuzzy finding).
- **Tiling WM**: `komorebi` + `AutoHotkey v2` (hotkeys).
- **Browsers**: Zen Browser (Primary).

## 🔗 Symlink Map (Managed via `install.ps1`)
| Source (in `C:\dev\dotfiles`) | Destination |
| :--- | :--- |
| `Microsoft.PowerShell_profile.ps1` | `$PROFILE` |
| `terminal-settings.json` | `$env:LOCALAPPDATA\...\settings.json` |
| `.config/mise/config.toml` | `$env:APPDATA\mise\config.toml` |
| `.gemini/settings.json` | `$HOME\.gemini\settings.json` |
| `.config/komorebi/` | `$HOME\.config\komorebi` |

## 🪟 Window Management Logic (Komorebi + AHK)
- **Config Path**: `$env:KOMOREBI_CONFIG_HOME` points to `$HOME\.config\komorebi`.
- **Config Files**: `komorebi.json` (static config), `komorebi.ahk` (keybindings), `applications.json` (app rules).
- **Monitor**: 3840x2160 (BenQ).
- **Layouts**:
  - **Default (Grid)**: 3x2 grid, 25% | 50% | 25% columns, equal rows, max 2 rows per column.
  - **Center Stage (Alt+F)**: UltrawideVerticalStack, 25% | 50% | 25% columns, focused window promoted to big center tile.
  - **Monocle (Alt+M)**: Single window with side (768px) + bottom (648px) padding for centered ergonomics.
- **Workspaces**:
  1. `Dev`: Grid layout (primary workspace).
  2. `Social`: Grid layout.
- **Borders**: 6px, light blue (`#64B4FF`) active, dark gray (`#424242`) inactive.
- **Keybindings (`komorebi.ahk`)**:
  - **Layouts**: `Alt+F` Center Stage toggle, `Alt+M` Monocle toggle.
  - **Focus**: `Alt+I/K/J/L` (up/down/left/right).
  - **Move**: `Alt+Shift+I/K/J/L` (up/down/left/right).
  - **Windows**: `Alt+T` toggle float, `Alt+S` toggle stack, `Alt+[/]` cycle stack.
  - **Workspaces**: `Alt+1/2` focus, `Alt+Shift+1/2` move window.
  - **Launchers**: `Alt+Enter` PowerShell, `Alt+B` Zen Browser.
  - **Admin**: `Alt+Shift+R` reload, `Alt+Shift+Q` stop.

## 📝 Recent Architectural Decisions (ADR)
- **ADR 001: Portable Config Home**: Used `KOMOREBI_CONFIG_HOME` to keep WM configs inside the dotfiles tree instead of the user root, facilitating easier git versioning.
- **ADR 002: Shell-Based WM Control**: Added `start-wm` and `stop-wm` to the PowerShell profile to manage the `komorebi` and `whkd` lifecycle cleanly.
- **ADR 003: Robust PSReadLine**: Updated profile with environment detection to prevent prediction/Vi-mode errors in non-interactive or non-VT shells.

## 🚀 Pending / Next Steps
- [ ] Test cross-platform parity for `komorebi-for-mac`.
- [ ] Fine-tune app-specific rules in `applications.json` for Zen/Slack/WhatsApp.
