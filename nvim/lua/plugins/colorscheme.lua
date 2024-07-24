vim.o.bg = "light"

return {
  -- lush used by zenbones
  { "rktjmp/lush.nvim", lazy = true },

  { "ellisonleao/gruvbox.nvim", lazy = true },

  { "rose-pine/neovim", lazy = true },

  { "zenbones-theme/zenbones.nvim", lazy = true },

  {
    dir = "../../colors/gruvbones.lua",
    config = function()
      require("colors.gruvbones")
    end,
    lazy = true,
  },
  {
    dir = "../../colors/mybones.lua",
    config = function()
      require("colors.mybones")
    end,
    lazy = true,
  },

  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "mybones",
    },
  },
}
