---
id: machine_setup
aliases:
  - machine_setup
tags: []
---

My personal guide for setting up or migrating to a new machine with all my dev tools and environment.

# machine_setup

fonts

- [x] OperatorMono
- [ ] A Nerd Font

manual apps

- [x] UniGetUI
- [ ] clumsy
- [ ] LuaRocks

winget install (latest unless specified):

- [x] FireFox Dev Edition
- [x] Git
- [x] PowerToys
- [x] Alacritty Terminal
- [x] NuShell
- [x] ripgrep
- [x] fd
- [x] curl
- [x] fzf
- [x] wget
- [x] llvm
- [ ] resvg (manual)
- [ ] unzip
- [x] 7z
- [ ] gzip
- [x] d2
- [x] CMake
- [x] Python
- [x] uv
- [x] NodeJs
- [x] LuaJIT
- [x] lazygit
- [x] neovim
- [x] rustup
- [x] JetBrains ToolBox
- [x] Zed
- [x] Visual Studio 26
- [x] opencode
- [ ] jq

npm install

- [ ] mcphub

  npm install -g mcp-hub@latest

WSL2

cargo

    rustup default stable
    rustup component add rust-analyzer
    cargo install --locked tree-sitter-cli

Visual Studio Installer

- [x] dotfiles
- [x] nvim
- [ ] rad
  - Configure Git for rad: https://wiki.wolve.com/pages/viewpage.action?pageId=23037163&spaceKey=URAD&title=First%2BDay%2BChecklist
    git config --global alias.pl "pull -r"
    git config --global alias.backup "!git branch \$(git rev-parse --abbrev-ref HEAD)\_backup"
    git config --global alias.s "status"
    git config --global alias.hist "log --pretty=format:'%h %ad | %s%d [%an]' --graph --date=short"
    git config --global alias.my "log --pretty=format:'%h %ad | %s%d' --graph --date=short --author=tlimbach@wolve.com"
- [ ] md
- [ ] rustopolis

Copy files

- [x] wolverine/
- [x] Worms/
- [ ] notes or vault

System Settings

- [x] enable dev mode and sudo
- [ ] check power settings
- [ ] setup dev drive
