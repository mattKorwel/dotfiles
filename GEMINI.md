# Project Context: Matt Korwel's Dotfiles

## 🎯 System Overview
- **OS**: Windows 11 (Primary) / macOS (Planned Cross-Platform).
- **Dotfiles Root**: `C:\dev\dotfiles`.
- **Primary Shell**: PowerShell 7+ (pwsh).
- **Keyboard**: ZSA Voyager (Configured to utilize `Alt` as the primary WM modifier).

## 🛠 Tooling Stack
- **Runtimes**: `mise` (node, npm, etc).
- **Shell UX**: `starship` (prompt), `zoxide` (navigation), `fzf` (fuzzy finding).
- **Tiling WM**: `komorebi` (Windows) / `AeroSpace` (macOS).
- **Browsers**: Zen Browser (Primary).

## 🔗 Symlink Map (Managed via `install.ps1` / `install.sh`)
| Source (in `~/dotfiles`) | Destination |
| :--- | :--- |
| `Microsoft.PowerShell_profile.ps1` | `$PROFILE` |
| `terminal-settings.json` | `$env:LOCALAPPDATA\...\settings.json` |
| `.config/mise/config.toml` | `~/.config/mise/config.toml` |
| `.gemini/settings.json` | `~/.gemini/settings.json` |
| `.config/komorebi/` | `~/.config/komorebi` |
| `.aerospace.toml` | `~/.aerospace.toml` |

## 🪟 Window Management Logic (Komorebi + AHK / AeroSpace)

### Windows (Komorebi + AHK)
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
  - **Focus**: `Alt+I/K/J/L` (up/down/left/right).
  - **Move**: `Alt+Shift+I/K/J/L` (up/down/left/right).
  - **Windows**: `Alt+T` toggle float, `Alt+S` toggle_stack, `Alt+[/]` cycle stack.
  - **Workspaces**: `Alt+6/7/8/9` focus, `Alt+Shift+6/7/8/9` move window, `Alt+N/P` cycle, `Alt+Tab` back-and-forth.
  - **Launchers**: `Alt+Enter` PowerShell, `Alt+B` Zen Browser.
  - **Close**: `Alt+Y`.
  - **Admin**: `Alt+Shift+R` reload, `Alt+Shift+Q` stop.

### macOS (AeroSpace)
- **Config Path**: `~/.aerospace.toml`.
- **Monitor**: BenQ RD320U (Main), Built-in Retina Display (Secondary).
- **Workspaces**:
  - `Dev`: Assigned to BenQ (Alt+6).
  - `Communications`: Assigned to Built-in Display (Alt+7).
  - `Personal`: Assigned to Built-in Display (Alt+8).
- **Keybindings**:
  - **Focus**: `Alt+I/K/J/L` (up/down/left/right).
  - **Move**: `Alt+Shift+I/K/J/L` (up/down/left/right).
  - **Monitors**: `Alt+.` / `Alt+,` focus next/prev, `Alt+Shift+.` / `Alt+Shift+,` move window.
  - **Layouts**: `Alt+F` fullscreen, `Alt+S` accordion, `Alt+T` float, `Alt+[` / `Alt+]` cycle stack focus.
  - **Workspaces**: `Alt+1-5` (Generic), `Alt+6-8` (Dev, Communications, Personal).
  - **Launchers**: `Alt+Enter` iTerm, `Alt+B` Google Chrome.
  - **Close**: `Alt+Y`.
  - **Admin**: `Alt+Shift+R` reload, `Alt+Shift+;` service mode.

## 🔧 Management
- **Voyager Universal Protocol**: Uses GUI (Win/Cmd) based shortcuts for cross-platform parity.
  - `GUI+Shift+4`: Selection Screenshot (Native Mac / Remapped on Win).
  - `GUI+Shift+D`: Dictation (Native Win / Remapped on Mac).
  - `GUI+C/V/X`: Universal Copy/Paste/Cut.
- **Windows (Komorebi)**:
  - **Check if running**: `tasklist | findstr komorebi` and `tasklist | findstr AutoHotkey`
  - **Kill everything**: `komorebic.exe stop` then `taskkill /IM AutoHotkey64.exe /F`
  - **Start everything**: `start-wm` (or `komorebic.exe start` then `Start-Process "$env:KOMOREBI_CONFIG_HOME\komorebi.ahk"`)
- **macOS (AeroSpace)**:
  - **Reload**: `aerospace reload-config` or `Alt+Shift+R`.
  - **Check windows**: `aerospace list-windows --all`.

## 📝 Recent Architectural Decisions (ADR)
- **ADR 001: Portable Config Home**: Used `KOMOREBI_CONFIG_HOME` to keep WM configs inside the dotfiles tree instead of the user root, facilitating easier git versioning.
- **ADR 002: Shell-Based WM Control**: Added `start-wm` and `stop-wm` to the PowerShell profile to manage the `komorebi` and `whkd` lifecycle cleanly.
- **ADR 003: Robust PSReadLine**: Updated profile with environment detection to prevent prediction/Vi-mode errors in non-interactive or non-VT shells.
- **ADR 004: Cross-Platform Tiling**: Adopted AeroSpace on macOS to achieve parity with Komorebi on Windows using a similar cardinal navigation and workspace logic.

## 🚀 Pending / Next Steps
- [x] Test cross-platform parity for `komorebi-for-mac` (Fulfilled via AeroSpace).
- [ ] Fine-tune app-specific rules in `applications.json` for Zen/Slack/WhatsApp.
