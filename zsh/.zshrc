# Editor configuration
export EDITOR=nvim
export VISUAL=nvim

# Word navigation with Alt/Option + Arrow keys
# Covers: Alacritty, WezTerm, Ghostty, iTerm2, Windows Terminal
# Forward word
bindkey "^[[1;3C" forward-word       # Alt+Right (standard)
bindkey "^[f" forward-word           # Alt+F (escape sequence fallback)
bindkey "^[^[[C" forward-word        # Esc+Right (some terminals)
# Backward word
bindkey "^[[1;3D" backward-word      # Alt+Left (standard)
bindkey "^[b" backward-word          # Alt+B (escape sequence fallback)
bindkey "^[^[[D" backward-word       # Esc+Left (some terminals)
# Delete word backward (Alt+Backspace)
bindkey "^[[1;3H" backward-kill-word # Alt+Backspace (some terminals)
bindkey "^[^?" backward-kill-word    # Alt+Backspace (escape sequence, 0x7f)
bindkey "^[^H" backward-kill-word    # Alt+Backspace (ctrl-h style, 0x08)
bindkey "^[\x7f" backward-kill-word  # Alt+Backspace (literal DEL)
bindkey "\e\x7f" backward-kill-word  # Alt+Backspace (escape + DEL)
# Delete word forward (Alt+Delete / Alt+D)
bindkey "^[d" kill-word              # Alt+D (delete word forward)
bindkey "^[[3;3~" kill-word          # Alt+Delete (standard)
bindkey "\e[3;3~" kill-word          # Alt+Delete (escape sequence)
bindkey "^[^[[3~" kill-word          # Esc+Delete (some terminals)

# History settings
HISTFILE="${ZDOTDIR:-$HOME}/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt hist_ignore_all_dups
setopt share_history

# Load modules & functions
zmodload zsh/complist 2>/dev/null || true
autoload -Uz compinit vcs_info add-zsh-hook

# Fast, cached completion init (important on Windows/MSYS)
COMPDUMP="${ZDOTDIR:-$HOME}/.zcompdump"
if [[ ! -f $COMPDUMP ]]; then
    compinit -d "$COMPDUMP"
else
    compinit -C -d "$COMPDUMP"
fi

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

# ============================================================
# Platform detection (run once at startup)
# ============================================================
_OS="unknown"
case "$(uname -s)" in
    Darwin)  _OS="macos" ;;
    Linux)   [[ -n "$WSL_DISTRO_NAME" ]] && _OS="wsl" || _OS="linux" ;;
    MINGW*|MSYS*) _OS="mingw" ;;
esac

# ============================================================
# Windows MSYS/MinGW PATH setup
# Windows is slow to inherit paths, so we set them explicitly
# ============================================================
if [[ "$_OS" == "mingw" ]]; then
    USER_PATH="\
/c/Users/tlimbach/.cargo/bin:\
/c/Users/tlimbach/AppData/Local/Programs/Python/Launcher:\
/c/Users/tlimbach/AppData/Local/Microsoft/WindowsApps:\
/c/Users/tlimbach/.dotnet/tools:\
/c/Users/tlimbach/AppData/Local/Microsoft/WinGet/Links:\
/c/Users/tlimbach/AppData/Local/Programs/nu/bin:\
/c/Users/tlimbach/AppData/Local/Programs/LuaJIT/bin:\
/c/Users/tlimbach/AppData/Roaming/luarocks/bin:\
/c/Users/tlimbach/AppData/Local/JetBrains/Toolbox/scripts:\
/c/Users/tlimbach/cli/resvg:\
/c/Users/tlimbach/cli/wezterm:\
/c/Users/tlimbach/AppData/Roaming/npm:\
/c/Users/tlimbach/AppData/Local/Programs/Zed/bin:\
/c/Users/tlimbach/AppData/Local/PowerToys/DSCModules"

    SYSTEM_PATH="\
/c/Program Files/Alacritty:\
/c/Program Files/Python311/Scripts:\
/c/Program Files/Python311:\
/c/Windows/system32:\
/c/Windows:\
/c/Windows/System32/Wbem:\
/c/Windows/System32/WindowsPowerShell/v1.0:\
/c/Windows/System32/OpenSSH:\
/c/Program Files/dotnet:\
/c/Program Files (x86)/Microsoft SQL Server/160/DTS/Binn:\
/c/Program Files/PuTTY:\
/c/Program Files/PowerShell/7:\
/c/Program Files/Neovim/bin:\
/c/Program Files (x86)/Windows Kits/10/Windows Performance Toolkit:\
/c/Strawberry/c/bin:\
/c/Strawberry/perl/site/bin:\
/c/Strawberry/perl/bin:\
/c/Program Files/Neovide:\
/c/Program Files/D2:\
/c/Program Files/nodejs:\
/c/Program Files/CMake/bin:\
/c/Program Files/nu/bin"

    # Git SDK must come first - git scripts prepend /mingw64/libexec/git-core
    # which has a broken `git --exec-path`, so we need /mingw64/bin before it
    GIT_SDK_PATH="/mingw64/bin:/usr/bin"

    PATH="${GIT_SDK_PATH}:${USER_PATH}:${SYSTEM_PATH}"
    export PATH
fi

# Prompt
_prompt_precmd() {
    vcs_info
    local ts="%D{%H:%M:%S}"
    local os_indicator=""
    [[ "$_OS" == "wsl" ]] && os_indicator="%F{magenta}[WSL]%f "
    PS1="${os_indicator}%F{green}${ts}%f %F{cyan}%n%f@%F{blue}%m%f %F{yellow}%~%f ${vcs_info_msg_0_}
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

# ============================================================
# Homebrew (platform-specific paths)
# ============================================================
if [[ "$_OS" == "macos" && -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# Rust/Cargo (non-mingw only; mingw sets paths explicitly above)
[[ "$_OS" != "mingw" && -d "$HOME/.cargo/bin" ]] && export PATH="$HOME/.cargo/bin:$PATH"

# Rustup via Homebrew (WSL/Linux)
[[ "$_OS" != "mingw" && -d /home/linuxbrew/.linuxbrew/opt/rustup/bin ]] && \
    export PATH="/home/linuxbrew/.linuxbrew/opt/rustup/bin:$PATH"

# FZF (platform-specific loading)
if [[ "$_OS" == "mingw" ]]; then
    # Windows: use fzf's native zsh integration
    command -v fzf &>/dev/null && source <(fzf --zsh)
else
    # Unix: use sourced files
    [[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh
fi

# ============================================================
# Theme switching (Gruvbox dark/light)
# ============================================================

# Alacritty config location varies by platform
case "$_OS" in
    wsl)   ALACRITTY_CONFIG="/mnt/c/Users/tlimbach/AppData/Roaming/alacritty" ;;
    mingw) ALACRITTY_CONFIG="$APPDATA/alacritty" ;;
    macos) ALACRITTY_CONFIG="$HOME/.config/alacritty" ;;
    *)     ALACRITTY_CONFIG="$HOME/.config/alacritty" ;;
esac

# Load LS_COLORS based on current theme (WSL only - others handle colors natively)
_load_ls_colors() {
    [[ "$_OS" != "wsl" ]] && return
    local theme="${1:-dark}"
    command -v dircolors &>/dev/null || return

    if [[ -f ~/.dircolors.$theme ]]; then
        eval "$(dircolors -b ~/.dircolors.$theme)"
    elif [[ -f ~/.dircolors ]]; then
        eval "$(dircolors -b ~/.dircolors)"
    fi
}

# Switch to dark theme
dark() {
    if [[ -f "$ALACRITTY_CONFIG/themes/gruvbox_dark.toml" ]]; then
        cp "$ALACRITTY_CONFIG/themes/gruvbox_dark.toml" "$ALACRITTY_CONFIG/alacritty.toml"
    fi
    export NVIM_THEME="dark"
    _load_ls_colors dark
    echo "Switched to gruvbox dark"
}

# Switch to light theme
light() {
    if [[ -f "$ALACRITTY_CONFIG/themes/gruvbox_light.toml" ]]; then
        cp "$ALACRITTY_CONFIG/themes/gruvbox_light.toml" "$ALACRITTY_CONFIG/alacritty.toml"
    fi
    export NVIM_THEME="light"
    _load_ls_colors light
    echo "Switched to gruvbox light"
}

# Detect current theme on shell startup and load appropriate LS_COLORS
_detect_theme() {
    if [[ -f "$ALACRITTY_CONFIG/alacritty.toml" ]]; then
        if grep -q 'background = "0x282828"' "$ALACRITTY_CONFIG/alacritty.toml" 2>/dev/null; then
            _load_ls_colors dark
            export NVIM_THEME="dark"
        else
            _load_ls_colors light
            export NVIM_THEME="light"
        fi
    else
        _load_ls_colors dark
    fi
}
_detect_theme

# ============================================================
# Aliases
# ============================================================
# WSL needs explicit color flag; macOS/mingw handle it natively
[[ "$_OS" == "wsl" || "$_OS" == "linux" ]] && alias ls='ls --color=auto'
