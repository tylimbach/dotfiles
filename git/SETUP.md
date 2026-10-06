# Git + delta setup

Steps for an agent setting up a new machine. Each step is safe to rerun.

1. Install delta: `brew install git-delta` (macOS), `winget install dandavison.delta` (Windows).
2. Include the shared config from this repo in the machine's global config:

       git config --global --get-all include.path | grep -qxF '~/dev/dotfiles/git/gitconfig' \
           || git config --global --add include.path '~/dev/dotfiles/git/gitconfig'

   Machine-specific settings (user, credentials, `core.autocrlf`, `safe.directory`) stay in
   `~/.gitconfig`. Remove any `[delta]`, `[diff]`, `[merge]`, `[interactive]` or `core.pager`
   entries there that duplicate `gitconfig`.
3. Check that `~/.zshrc` links to `zsh/.zshrc` (`./install.sh`). Its `dark`/`light` functions
   export `DELTA_FEATURES=+gruvbox-<theme>`, which picks delta's light or dark preset.
4. Neovim's `:Review` (delta diff in a terminal buffer, `gF` to jump to a hunk) lives in the
   nvim repo, `lua/plugins/mini.lua`. It needs `zsh` and `delta` on PATH.

Verify: in a repo with changes, `git diff` renders through delta in the terminal's theme, and
`DELTA_FEATURES=+gruvbox-light delta --show-config | grep syntax-theme` shows `gruvbox (Light)`.
