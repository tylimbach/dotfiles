-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

--[[
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.updatetime = 750
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true
vim.opt.colorcolumn = "120"
--]]

vim.opt.cursorline = false
vim.opt.termguicolors = true
