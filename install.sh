#!/usr/bin/env bash
# Links this repo's shell and agent-workflow configs into place, on macOS,
# Linux, WSL and Windows (Git Bash/MSYS2 zsh). Safe to rerun: a link
# already right is left alone, and a real file in the way is moved aside
# to NAME.pre-dotfiles first. Claude Code's own settings are not linked:
# see README.md, "Claude Code agent workflow".
#
#   ./install.sh
set -uo pipefail
DOT=$(cd "$(dirname "$0")" && pwd)

if   [[ -n "${WSL_DISTRO_NAME:-}" ]]; then OS=wsl
elif [[ "$OSTYPE" == msys* || "$OSTYPE" == cygwin* || -n "${MSYSTEM:-}" ]]; then OS=mingw
elif [[ "$OSTYPE" == darwin* ]]; then OS=macos
else OS=linux
fi
# Real Windows symlinks, not copies (needs Developer Mode).
[[ $OS == mingw ]] && export MSYS=winsymlinks:nativestrict

link() {
    local from=$DOT/$1 to=$2
    mkdir -p "$(dirname "$to")"
    if [[ -L "$to" && "$(readlink "$to")" == "$from" ]]; then
        return
    fi
    if [[ -e "$to" || -L "$to" ]]; then
        mv "$to" "$to.pre-dotfiles" && echo "moved aside: $to.pre-dotfiles"
    fi
    ln -s "$from" "$to" && echo "linked: $to"
}

link zsh/.zshrc "$HOME/.zshrc"
link zellij/bin/zw "$HOME/.local/bin/zw"
link claude/statusline-command.sh "$HOME/.claude/statusline-command.sh"
for agent in claude/agents/*.md; do link "$agent" "$HOME/.claude/agents/${agent##*/}"; done
case $OS in
    macos)
        link zellij/mac/config.kdl "$HOME/.config/zellij/config.kdl"
        link sccache/config "$HOME/Library/Application Support/Mozilla.sccache/config"
        ;;
    linux|wsl)
        link zellij/mac/config.kdl "$HOME/.config/zellij/config.kdl"
        link sccache/config "$HOME/.config/sccache/config"
        ;;
    mingw)
        link zellij/config/config.kdl "$APPDATA/zellij/config/config.kdl"
        link sccache/config "$APPDATA/Mozilla/sccache/config/config"
        ;;
esac

# What the workflow runs, and what its hooks call.
for tool in git zellij just jq claude; do
    command -v "$tool" >/dev/null || echo "missing: $tool"
done
# zw is Python; Windows' python3 can be the Store's stub, which only opens the Store.
python3 -c '' 2>/dev/null || echo "missing: a working python3 (Windows: turn off the python3 App execution alias)"
[[ ":$PATH:" == *":$HOME/.local/bin:"* ]] || echo "add ~/.local/bin to PATH (for zw)"
echo "Machine-only shell lines go in ~/.zshrc.local."
