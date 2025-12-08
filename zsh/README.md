# Zsh Configuration

Portable zsh configuration with:
- Alt/Option word navigation (works with Ghostty, Alacritty, WezTerm, iTerm2)
- Minimal prompt with git branch, timestamp, and user@host
- Zellij integration for auto-naming panes/tabs

## Installation

```bash
# Set ZDOTDIR to use this config location
echo 'export ZDOTDIR="$HOME/.config/zsh"' >> ~/.zshenv

# Symlink or copy
ln -s ~/dev/dotfiles/zsh/.zshrc ~/.config/zsh/.zshrc

# Install plugins
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.config/zsh/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.config/zsh/plugins/zsh-syntax-highlighting
```

## Zellij Integration

When running inside zellij, panes and tabs are automatically named based on:
- SSH session: `user@hostname`
- Home directory: `~`
- Git repository: repo name
- Otherwise: current directory name

Names update on directory change only (cached for low latency).

### Manual overrides
- `zpr "name"` - rename current pane
- `ztr "name"` - rename current tab

## Keybinds

| Bind | Action |
|------|--------|
| Alt+Left | Backward word |
| Alt+Right | Forward word |
| Alt+Backspace | Delete word backward |
| Alt+D | Delete word forward |
