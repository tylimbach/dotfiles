# Zellij Configuration

Keybind scheme designed to avoid conflicts with:
- Terminal word navigation (Alt+arrows, Alt+f/b/d)
- Neovim keybinds (Alt+j/k for line movement)
- Ghostty and other terminal emulators

## Philosophy

- `default_mode = "locked"` - zellij doesn't intercept keys by default
- Alt-based keybinds for zellij actions
- One-shot actions from locked mode
- Modal toggles (same key enters and exits mode)

## Keybinds

### Global (work from ALL modes including locked)

| Bind | Action |
|------|--------|
| Alt+1-9 | Jump to tab 1-9 |
| Alt+n | New pane |
| Alt+w | Toggle floating panes |
| Alt+z | Maximize pane (fullscreen) |
| Alt+e | Toggle pane embed/floating |
| Alt+[/] | Previous/next swap layout |
| Alt+,/. | Focus previous/next pane |
| Alt+; | Session manager (switch sessions) |
| Alt+/ | Sessionizer (project picker) |
| Alt+x | Toggle pane frames |
| Alt+q | Quit zellij |

### Lock Toggle

| Bind | Action |
|------|--------|
| Alt+g | Toggle lock (works everywhere) |

### Modal Toggles (same key enters AND exits to locked)

| Bind | Mode |
|------|------|
| Alt+t | Tab mode |
| Alt+p | Pane mode |
| Alt+r | Resize mode |
| Alt+m | Move mode |
| Alt+s | Scroll/Search mode |
| Alt+o | Session mode |

### Inside Modes

All modes support:
- `h/j/k/l` or arrow keys for navigation
- `Esc` or `Enter` to return to locked
- `Alt+g` to return to locked

### Tmux Compatibility

`Ctrl+b` enters tmux mode for muscle memory.

## Installation

```bash
# Link config
mkdir -p ~/.config/zellij/layouts
ln -sf ~/dev/dotfiles/zellij/config.kdl ~/.config/zellij/config.kdl
ln -sf ~/dev/dotfiles/zellij/layouts/dev.kdl ~/.config/zellij/layouts/dev.kdl

# Install sessionizer plugin
mkdir -p ~/.config/zellij/plugins
curl -sL https://github.com/laperlej/zellij-sessionizer/releases/latest/download/zellij-sessionizer.wasm \
  -o ~/.config/zellij/plugins/zellij-sessionizer.wasm
```
