# 🚀 Cross-Platform Dotfiles Setup Guide

This repo contains my cross-platform dotfiles and configs for the tools I use everywhere. This guide makes it easy to get up and running on **macOS**, **Linux**, or **Windows**.

## Tools Covered

- **Alacritty** (Terminal)
- **NuShell** (Shell)
- **Neovim** (Editor/IDE)
- **Yazi** (File Manager)
- **Zed** (Editor)
- **Zellij** (Terminal Multiplexer)

---

## 1. Alacritty

**Install:**

- **macOS:** `brew install alacritty`
- **Linux:** Use your distro's package manager (e.g. `sudo pacman -S alacritty` or `sudo apt install alacritty`)
- **Windows:** `winget install Alacritty.Alacritty` (recommended) or download from [releases](https://github.com/alacritty/alacritty/releases)
  - If `winget` is unavailable, use `scoop install alacritty`

**Config location:**

- **macOS/Linux:** `~/.config/alacritty/alacritty.toml`
- **Windows:** `%APPDATA%\alacritty\alacritty.toml`

**Setup:**

- Copy `alacritty/alacritty.toml` from this repo to your config directory.
- Themes in `alacritty/themes/` (see NuShell functions for theme switching).

---

## 2. NuShell

**Install:**

- **macOS:** `brew install nushell`
- **Linux:** `cargo install nu` or use your package manager
- **Windows:** `winget install Nushell.Nushell` (recommended)
  - If `winget` is unavailable, use `scoop install nu`

**Config location:**

- **macOS/Linux:** `~/.config/nushell/`
- **Windows:** `%APPDATA%\nushell\`

**Setup:**

- Copy all files from `nushell/` in this repo to your config directory.
- Includes aliases and functions for theme switching and tool integration.

---

## 3. Neovim

**Install:**

- **macOS:** `brew install neovim`
- **Linux:** Use your package manager (e.g. `sudo pacman -S neovim`)
- **Windows:** `winget install Neovim.Neovim` (recommended)
  - If `winget` is unavailable, use `scoop install neovim` or `choco install neovim`

**Config location:**

- **macOS/Linux:** `~/.config/nvim/`
- **Windows:** `%LOCALAPPDATA%\nvim\`

**Setup:**

- Clone this repo or copy the `nvim/` folder to your config directory.
- Start Neovim and plugins will auto-install via `lazy.nvim`.

---

## 4. Yazi

**Install:**

- **macOS:** `brew install yazi`
- **Linux:** `cargo install yazi-fm`
- **Windows:** `winget install yazi` (recommended)
  - If `winget` is unavailable, use `scoop install yazi`

**Config location:**

- **macOS/Linux:** `~/.config/yazi/`
- **Windows:** `%APPDATA%\yazi\`

**Setup:**

- Copy `yazi/yazi.toml` and `yazi/theme.toml` to your config directory.

---

## 5. Zed

**Install:**

- Download from [zed.dev](https://zed.dev/) (available for macOS, Linux, Windows)

**Config location:**

- **macOS/Linux:** `~/.config/zed/`
- **Windows:** `%APPDATA%\zed\`

**Setup:**

- Copy `zed/settings.json` and `zed/keymap.json` to your config directory.

---

## 6. Zellij

**Install:**

- **macOS:** `brew install zellij`
- **Linux:** `cargo install --locked zellij`
- **Windows:** `winget install zellij` (recommended)
  - If `winget` is unavailable, use `scoop install zellij`

**Config location:**

- **macOS/Linux:** `~/.config/zellij/config.kdl`
- **Windows:** `%APPDATA%\zellij\config.kdl`

**Setup:**

- Copy `zellij/config.kdl` to your config directory.

---

## Copying Configs (Summary Table)

| Tool      | macOS/Linux Config Dir | Windows Config Dir       | Copy from Repo             |
| --------- | ---------------------- | ------------------------ | -------------------------- |
| Alacritty | `~/.config/alacritty/` | `%APPDATA%\\alacritty\\` | `alacritty/alacritty.toml` |
| NuShell   | `~/.config/nushell/`   | `%APPDATA%\\nushell\\`   | `nushell/*`                |
| Neovim    | `~/.config/nvim/`      | `%LOCALAPPDATA%\\nvim\\` | `nvim/*`                   |
| Yazi      | `~/.config/yazi/`      | `%APPDATA%\\yazi\\`      | `yazi/*`                   |
| Zed       | `~/.config/zed/`       | `%APPDATA%\\zed\\`       | `zed/settings.json`        |
| Zellij    | `~/.config/zellij/`    | `%APPDATA%\\zellij\\`    | `zellij/config.kdl`        |

_For Windows, prefer `winget` for installing tools. If unavailable, use `scoop` as a fallback._

---

## Theme Switching

- Use NuShell functions in `nushell/config.nu` to switch themes for Alacritty and Zellij (`aladark`, `alalight`).
- Themes for Alacritty are in `alacritty/themes/`.

---

**Tip:** For all tools, create the config directory if it doesn't exist. On Windows, `%APPDATA%` is usually `C:\Users\<User>\AppData\Roaming`.

---

**Backup and niche configs** (Komorebi, Neovide, VSCode, WindowsTerminal, etc.) are also present in this repo but not covered here.

---
