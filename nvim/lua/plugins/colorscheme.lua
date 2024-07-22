vim.o.bg = "light"

return {
  -- lush used by zenbones
  { "rktjmp/lush.nvim" },

  { "ellisonleao/gruvbox.nvim" },

  { "rose-pine/neovim" },

  { "zenbones-theme/zenbones.nvim" },

  -- Configure LazyVim to load gruvbox
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "zenbones",
    },
  },
}
