# Editor
export EDITOR=nvim
export VISUAL=nvim

# ============================================================
# Key bindings
# ============================================================
# Emacs-style editing (EDITOR=nvim would otherwise default to vi-mode)
bindkey -e
bindkey '^?'     backward-delete-char   # DEL
bindkey '^H'     backward-delete-char   # BS

# Alt+Arrow word navigation (Alacritty, WezTerm, Windows Terminal, etc.)
bindkey "^[[1;3C" forward-word          # Alt+Right
bindkey "^[f"     forward-word          # Alt+F
bindkey "^[[1;3D" backward-word         # Alt+Left
bindkey "^[b"     backward-word         # Alt+B

# Alt+Backspace / Alt+Delete word kill
bindkey "^[^?"    backward-kill-word
bindkey "^[\x7f"  backward-kill-word
bindkey "\e\x7f"  backward-kill-word
bindkey "^[d"     kill-word
bindkey "^[[3;3~" kill-word
bindkey "\e[3;3~" kill-word

# ============================================================
# History
# ============================================================
HISTFILE="${ZDOTDIR:-$HOME}/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt hist_ignore_all_dups share_history

# ============================================================
# Platform detection — $OSTYPE/$MSYSTEM are builtins, no subprocess
# ============================================================
_OS="unknown"
if   [[ -n "$WSL_DISTRO_NAME" ]];                              then _OS="wsl"
elif [[ "$OSTYPE" == msys* || "$OSTYPE" == cygwin* || -n "$MSYSTEM" ]]; then _OS="mingw"
elif [[ "$OSTYPE" == darwin* ]];                               then _OS="macos"
elif [[ "$OSTYPE" == linux* ]];                                then _OS="linux"
fi

# ============================================================
# Completion
# ============================================================
autoload -Uz compinit
zmodload zsh/complist

# Drop generated completions here (created once manually):
#   rustup completions zsh        > ~/.zsh/completions/_rustup
#   rustup completions zsh cargo  > ~/.zsh/completions/_cargo
#   gh completion -s zsh          > ~/.zsh/completions/_gh
_comp_dir="${ZDOTDIR:-$HOME}/.zsh/completions"
[[ -d "$_comp_dir" ]] || mkdir -p "$_comp_dir"
fpath=("$_comp_dir" $fpath)

# -C skips the security check and uses the cached dump (fast).
# To force a full rebuild: rm ~/.zcompdump && exec zsh
compinit -C

zstyle ':completion:*' menu select          # arrow-key navigable menu
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'  # case-insensitive

# ============================================================
# Plugins
# ============================================================
[[ -f "${ZDOTDIR:-$HOME/.config/zsh}/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && \
    source "${ZDOTDIR:-$HOME/.config/zsh}/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"

# ============================================================
# PATH
# ============================================================
# Homebrew
if [[ "$_OS" == "macos" && -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# Cargo / Rustup (mingw gets these via Windows PATH)
[[ "$_OS" != "mingw" && -d "$HOME/.cargo/bin" ]] && \
    export PATH="$HOME/.cargo/bin:$PATH"
[[ "$_OS" != "mingw" && -d /home/linuxbrew/.linuxbrew/opt/rustup/bin ]] && \
    export PATH="/home/linuxbrew/.linuxbrew/opt/rustup/bin:$PATH"

# ============================================================
# FZF
# ============================================================
if [[ "$_OS" == "mingw" ]]; then
    # Cache the init script — process substitution is slow on Windows.
    # Delete ~/.zsh/fzf-init.zsh to regenerate after a fzf upgrade.
    _fzf_init="${ZDOTDIR:-$HOME}/.zsh/fzf-init.zsh"
    if command -v fzf &>/dev/null; then
        [[ ! -f "$_fzf_init" ]] && fzf --zsh > "$_fzf_init" 2>/dev/null
        [[ -f "$_fzf_init" ]] && source "$_fzf_init"
    fi
else
    [[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh
fi

# ============================================================
# Prompt (with git branch)
# ============================================================
_git_branch_info() {
    local git_cmd="git"
    [[ "$_OS" == "wsl" && "$PWD" == /mnt/[a-z]/* ]] && git_cmd="git.exe"
    # Fast path: avoid spawning git when not in a repo
    [[ -e .git ]] || $git_cmd rev-parse --git-dir &>/dev/null 2>&1 || return
    local branch
    branch=$($git_cmd rev-parse --abbrev-ref HEAD 2>/dev/null)
    [[ -n "$branch" ]] && echo "($branch) "
}

autoload -Uz add-zsh-hook
_prompt_precmd() {
    local git_info=$(_git_branch_info)
    local os_indicator=""
    [[ "$_OS" == "wsl" ]] && os_indicator="%F{magenta}[WSL]%f "
    PS1="${os_indicator}%F{green}%D{%H:%M:%S}%f %F{cyan}%n%f@%F{blue}%m%f %F{yellow}%~%f ${git_info}
$ "
}
add-zsh-hook precmd _prompt_precmd

# ============================================================
# Zellij helpers
# ============================================================
if [[ -n "$ZELLIJ" ]]; then
    function zpr() { zellij action rename-pane "$1"; }
    function ztr() { zellij action rename-tab "$1"; }
fi

# ============================================================
# refresh — pull fresh Windows registry PATH into current shell
# ============================================================
# Run after installing tools that add themselves to the Windows PATH
# (e.g. ollama, winget packages). reg.exe reads the registry directly
# in ~50ms; no PowerShell startup overhead.
refresh() {
    if [[ "$_OS" == "mingw" ]] && command -v cygpath &>/dev/null; then
        local sys_path user_path win_path posix_path
        sys_path=$(reg.exe query \
            "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" \
            /v PATH 2>/dev/null | sed -n 's/.*REG_[A-Z_]*[[:space:]]*//p' | tr -d '\r\n')
        user_path=$(reg.exe query "HKCU\Environment" /v PATH 2>/dev/null \
            | sed -n 's/.*REG_[A-Z_]*[[:space:]]*//p' | tr -d '\r\n')
        win_path="${sys_path};${user_path}"
        posix_path=$(cygpath -up "$win_path" 2>/dev/null)
        if [[ -n "$posix_path" ]]; then
            local -aU merged
            merged=(${(s[:])posix_path} ${(s[:])PATH})
            export PATH="${(j[:])merged}"
        fi
    fi
    hash -r
    echo "PATH refreshed"
}

# ============================================================
# Theme switching (Gruvbox dark / light)
# ============================================================
case "$_OS" in
    wsl)   ALACRITTY_CONFIG="/mnt/c/Users/tlimbach/AppData/Roaming/alacritty" ;;
    mingw) ALACRITTY_CONFIG="$APPDATA/alacritty" ;;
    *)     ALACRITTY_CONFIG="$HOME/.config/alacritty" ;;
esac

_load_ls_colors() {
    [[ "$_OS" != "wsl" ]] && return
    command -v dircolors &>/dev/null || return
    local f="$HOME/.dircolors.${1:-dark}"
    [[ -f "$f" ]] || f="$HOME/.dircolors"
    [[ -f "$f" ]] && eval "$(dircolors -b "$f")"
}

dark() {
    [[ -f "$ALACRITTY_CONFIG/themes/gruvbox_dark.toml" ]] && \
        cp "$ALACRITTY_CONFIG/themes/gruvbox_dark.toml" "$ALACRITTY_CONFIG/alacritty.toml"
    export NVIM_THEME="dark"; _load_ls_colors dark
}

light() {
    [[ -f "$ALACRITTY_CONFIG/themes/gruvbox_light.toml" ]] && \
        cp "$ALACRITTY_CONFIG/themes/gruvbox_light.toml" "$ALACRITTY_CONFIG/alacritty.toml"
    export NVIM_THEME="light"; _load_ls_colors light
}

# Detect theme at startup
if [[ -f "$ALACRITTY_CONFIG/alacritty.toml" ]]; then
    _t=$(sed -n 's/^NVIM_THEME *= *"\([^"]*\)".*/\1/p' "$ALACRITTY_CONFIG/alacritty.toml" 2>/dev/null | head -1)
    export NVIM_THEME="${_t:-dark}"; unset _t
else
    export NVIM_THEME="dark"
fi
_load_ls_colors "$NVIM_THEME"

# ============================================================
# Misc
# ============================================================
[[ "$_OS" == "wsl" ]] && hash -d "w"="/mnt/c/Users/tlimbach"
[[ "$_OS" == "wsl" || "$_OS" == "linux" ]] && alias ls='ls --color=auto'
[[ "$_OS" == "wsl" ]] && compdef nvim.exe=nvim 2>/dev/null
