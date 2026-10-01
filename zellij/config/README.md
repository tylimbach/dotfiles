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
| Alt+Tab | Flip between the last two tabs |
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

## Agents: `zw`

`bin/zw` gives each git worktree its own tab and agent, within one session
per project. Worktrees sit next to the main checkout as `../<repo>-NAME` on
`agent/NAME`, branched from the main checkout's current branch.

| Command | Does |
|------|--------|
| `zw new NAME [--codex] [ARGS]` | Worktree + tab: the agent full-size, a hidden shell there (Alt+w) |
| `zw new NAME -c` | Reopen an existing worktree (zw's or Claude Code's `.claude/worktrees/NAME`), resuming its last session |
| `zw go NAME` | Focus NAME's tab |
| `zw ls` | Worktrees: branch, commits ahead, uncommitted files |
| `zw land [CHECK...]` | From a worktree: rebase, run CHECK, fast-forward the active branch |
| `zw done NAME` | Once landed: close the tab, remove the worktree and branch |

Agent hooks mark each tab: `●` working, `?` needs you, `✓` finished.
Claude Code (`~/.claude/settings.json`): `zw status working` on
UserPromptSubmit and PostToolUse, `input` on Notification
(`permission_prompt|elicitation_dialog`), `done` on Stop, `clear` on
SessionEnd. Codex (`~/.codex/config.toml`): `notify = ["zw", "status", "done"]`.

## Installation

Each machine has its own `config.kdl`, differing only in plugin paths:
`zellij/mac/config.kdl` (macOS) and `zellij/config/config.kdl` (Windows).
Keybind changes go in both.

macOS:

```bash
# Link config
mkdir -p ~/.config/zellij/layouts
ln -sf ~/dev/dotfiles/zellij/mac/config.kdl ~/.config/zellij/config.kdl
ln -sf ~/dev/dotfiles/zellij/config/layouts/dev.kdl ~/.config/zellij/layouts/dev.kdl
ln -sf ~/dev/dotfiles/zellij/bin/zw ~/.local/bin/zw

# Install sessionizer plugin
mkdir -p ~/.config/zellij/plugins
curl -sL https://github.com/laperlej/zellij-sessionizer/releases/latest/download/zellij-sessionizer.wasm \
  -o ~/.config/zellij/plugins/zellij-sessionizer.wasm
```
