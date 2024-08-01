return {
  -- roslyn lsp wrapper for csharp
  {
    "seblj/roslyn.nvim",
    name = "roslyn",
    opts = {
      config = {},
      exe = {
        "dotnet",
        "C:/Program Files/Microsoft.CodeAnalysis.LanguageServer/content/LanguageServer/win-x64/Microsoft.CodeAnalysis.LanguageServer.dll",
      },
      filewatching = true, -- try disabling if slow
    },
  },

  -- overriden lsp configs
  {
    "neovim/nvim-lspconfig",
    ---@class PluginLspOpts
    opts = {
      ---@type lspconfig.options
      servers = {
        omnisharp = {
          -- disable omnisharp lsp lazy extras adds, we use roslyn
          enabled = false,
          mason = false,
        },
      },
      inlay_hints = { enabled = false },
    },
  },
}
