return {
  {
    "Decodetalkers/csharpls-extended-lsp.nvim",
  },
  {
    "Hoffs/omnisharp-extended-lsp.nvim",
  },
  -- roslyn
  {
    "seblj/roslyn.nvim",
    name = "roslyn2",
    config = {
      exe = "roslyn C:/Program Files/Microsoft.CodeAnalysis.LanguageServer/content/LanguageServer/win-x64/Microsoft.CodeAnalysis.LanguageServer.dll",
      filewatching = false,
    },
    enabled = false,
  },
  --[[
  {
    "jmederosalvarado/roslyn.nvim",
    name = "roslyn2",
    config = {
      exe = "roslyn C:/Program Files/Microsoft.CodeAnalysis.LanguageServer/content/LanguageServer/win-x64/Microsoft.CodeAnalysis.LanguageServer.dll",
      filewatching = false,
    },
  },
  --]]

  -- add pyright to lspconfig
  {
    "neovim/nvim-lspconfig",
    ---@class PluginLspOpts
    opts = {
      ---@type lspconfig.options
      servers = {
        -- pyright will be automatically installed with mason and loaded with lspconfig
        rust_analyzer = {
          config = function()
            local util = require("lspconfig.util")
            local async = require("lspconfig.async")

            local function reload_workspace(bufnr)
              bufnr = util.validate_bufnr(bufnr)
              local clients = util.get_lsp_clients({ bufnr = bufnr, name = "rust_analyzer" })
              for _, client in ipairs(clients) do
                vim.notify("Reloading Cargo Workspace")
                client.request("rust-analyzer/reloadWorkspace", nil, function(err)
                  if err then
                    error(tostring(err))
                  end
                  vim.notify("Cargo workspace reloaded")
                end, 0)
              end
            end

            local function is_library(fname)
              local user_home = util.path.sanitize(vim.env.HOME)
              local cargo_home = os.getenv("CARGO_HOME") or util.path.join(user_home, ".cargo")
              local registry = util.path.join(cargo_home, "registry", "src")
              local git_registry = util.path.join(cargo_home, "git", "checkouts")

              local rustup_home = os.getenv("RUSTUP_HOME") or util.path.join(user_home, ".rustup")
              local toolchains = util.path.join(rustup_home, "toolchains")

              for _, item in ipairs({ toolchains, registry, git_registry }) do
                if util.path.is_descendant(item, fname) then
                  local clients = util.get_lsp_clients({ name = "rust_analyzer" })
                  return #clients > 0 and clients[#clients].config.root_dir or nil
                end
              end
            end

            return {
              default_config = {
                cmd = { "rust-analyzer" },
                filetypes = { "rust" },
                single_file_support = true,
                root_dir = function(fname)
                  local reuse_active = is_library(fname)
                  if reuse_active then
                    return reuse_active
                  end

                  local cargo_crate_dir = util.root_pattern("Cargo.toml")(fname)
                  local cargo_workspace_root

                  if cargo_crate_dir ~= nil then
                    local cmd = {
                      "cargo",
                      "metadata",
                      "--no-deps",
                      "--format-version",
                      "1",
                      "--manifest-path",
                      util.path.join(cargo_crate_dir, "Cargo.toml"),
                    }

                    local result = async.run_command(cmd)

                    if result and result[1] then
                      result = vim.json.decode(table.concat(result, ""))
                      if result["workspace_root"] then
                        cargo_workspace_root = util.path.sanitize(result["workspace_root"])
                      end
                    end
                  end

                  return cargo_workspace_root
                    or cargo_crate_dir
                    or util.root_pattern("rust-project.json")(fname)
                    or util.find_git_ancestor(fname)
                end,
                capabilities = {
                  experimental = {
                    serverStatusNotification = true,
                  },
                },
                settings = {
                  cargo = {
                    allFeatures = true,
                    loadOutDirsFromCheck = true,
                    runBuildScripts = true,
                  },
                  procMacro = {
                    enable = true,
                  },
                  completion = {
                    postfix = {
                      enable = true,
                    },
                  },
                  checkOnSave = {
                    command = "clippy",
                  },
                  inlayHints = {
                    locationLinks = false,
                  },
                },
              },
              commands = {
                CargoReload = {
                  function()
                    reload_workspace(0)
                  end,
                  description = "Reload current cargo workspace",
                },
              },
              docs = {
                description = [[
          https://github.com/rust-lang/rust-analyzer

          rust-analyzer (aka rls 2.0), a language server for Rust


          See [docs](https://github.com/rust-lang/rust-analyzer/blob/master/docs/user/generated_config.adoc) for extra settings. The settings can be used like this:
          ```lua
          require'lspconfig'.rust_analyzer.setup{
            settings = {
              ['rust-analyzer'] = {
                diagnostics = {
                  enable = false;
                }
              }
            }
          }
          ```
              ]],
                default_config = {
                  root_dir = [[root_pattern("Cargo.toml", "rust-project.json")]],
                },
              },
            }
          end,
        },
        pyright = {},
        jsonls = {},
        lua_ls = {},
        omnisharp = {
          enabled = false,
          mason = false,
          cmd = { "C:/Program Files/omnisharp-win-x64/Omnisharp.exe" },
          root_dir = function(fname)
            local util = require("lspconfig.util")
            return util.root_pattern("*.csproj")(fname)
            -- or util.root_pattern("*.sln")(fname)
          end,
          handlers = {
            ["textDocument/definition"] = function(...)
              require("omnisharp_extended").definition_handler(...)
            end,
            ["textDocument/typeDefinition"] = function(...)
              require("omnisharp_extended").type_definition_handler(...)
            end,
            ["textDocument/referenes"] = function(...)
              require("omnisharp_extended").references_handler(...)
            end,
            ["textDocument/implementation"] = function(...)
              require("omnisharp_extended").implementation_handler(...)
            end,
          },
          single_file_support = true,
          enable_roslyn_analyzers = false,
          enable_editorconfig_support = true,
        },
        csharp_ls = {
          enabled = false,
          mason = false,
          root_dir = function(fname)
            local util = require("lspconfig.util")
            return util.root_pattern("*Beedrill.Client.sln")(fname) or util.root_pattern("*.csproj")(fname)
          end,
          single_file_support = true,
          cmd = { "csharp-ls" },
          filtypes = { "cs" },
          init_options = {
            AutomaticWorkspaceInit = true,
          },
          handlers = {
            ["textDocument/definition"] = function(...)
              require("csharpls_extended").handler(...)
            end,
            ["textDocument/typeDefinition"] = function(...)
              require("csharpls_extended").handler(...)
            end,
          },
          settings = {
            csharp = {
              solution = "Beedrill.Client.sln",
            },
          },
        },
        --[[
        roslyn = {
          config = function()
            require("roslyn").setup({
              exe = "roslyn C:/Program Files/Microsoft.CodeAnalysis.LanguageServer/content/LanguageServer/win-x64/Microsoft.CodeAnalysis.LanguageServer.dll",
              filewatching = true,
            })
          end,
          mason = false,
        },
        --]]
      },
      inlay_hints = { enabled = false },
    },
  },
}
