# Editor configuration
export EDITOR=nvim
export VISUAL=nvim

# Dotfiles bin
export PATH="$HOME/dev/dotfiles/bin:$PATH"

# Word navigation with Option/Alt + Arrow keys
# These bindings work across most terminals (Ghostty, Alacritty, WezTerm, iTerm2)
# Forward word
bindkey "^[[1;3C" forward-word       # Alt+Right (standard)
bindkey "^[f" forward-word           # Alt+F (escape sequence fallback)
bindkey "^[^[[C" forward-word        # Esc+Right (some terminals)
# Backward word
bindkey "^[[1;3D" backward-word      # Alt+Left (standard)
bindkey "^[b" backward-word          # Alt+B (escape sequence fallback)
bindkey "^[^[[D" backward-word       # Esc+Left (some terminals)
# Delete word forward/backward
bindkey "^[[1;3H" backward-kill-word # Alt+Backspace (some terminals)
bindkey "^[^?" backward-kill-word    # Alt+Backspace (escape sequence)
bindkey "^[d" kill-word              # Alt+D (delete word forward)

# History settings
HISTFILE="${ZDOTDIR:-$HOME}/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt hist_ignore_all_dups

# Completion
autoload -Uz compinit vcs_info add-zsh-hook
compinit

# Plugins (install via git clone into $ZDOTDIR/plugins/)
# git clone https://github.com/zsh-users/zsh-autosuggestions $ZDOTDIR/plugins/zsh-autosuggestions
# git clone https://github.com/zsh-users/zsh-syntax-highlighting $ZDOTDIR/plugins/zsh-syntax-highlighting
if [ -f "${ZDOTDIR:-$HOME/.config/zsh}/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    source "${ZDOTDIR:-$HOME/.config/zsh}/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# Syntax highlighting must be loaded last
if [ -f "${ZDOTDIR:-$HOME/.config/zsh}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
    source "${ZDOTDIR:-$HOME/.config/zsh}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

# Git info for prompt
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git*' formats '(%b)'

# Prompt
_prompt_precmd() {
    vcs_info
    local ts="%D{%H:%M:%S}"
    PS1="%F{green}${ts}%f %F{cyan}%n%f@%F{blue}%m%f %F{yellow}%~%f ${vcs_info_msg_0_}
$ "
}

add-zsh-hook precmd _prompt_precmd

# ============================================================
# Zellij helpers (manual rename functions)
# ============================================================
if [[ -n $ZELLIJ ]]; then
    # Manual rename functions
    function zpr() { zellij action rename-pane "$1"; }
    function ztr() { zellij action rename-tab "$1"; }
fi
