-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here
--
local function is_lsp_attached()
  local clients = vim.lsp.get_active_clients()
  for _, client in ipairs(clients) do
    if client.name == "csharp_ls" then
      return true
    end
  end
  return false
end

local function find_solution_files(path)
  local scan = require("plenary.scandir")
  local solution_files = scan.scan_dir(path, {
    hidden = false, -- Set to true if you want to include hidden directories
    only_dirs = false, -- We are looking for files, not directories
    depth = 1, -- Adjust the depth for how deep you want to search
    search_pattern = "%.sln$", -- Regex pattern to match '.sln' files
  })
  return solution_files
end

local function setup_lsp_with_solution(solution_name)
  local config = {
    cmd = { "csharp-ls" },
    filetypes = { "cs" },
    root_dir = function(fname)
      local util = require("lspconfig.util")
      return util.root_pattern(solution_name .. ".sln")(fname) or util.root_pattern("*.csproj")(fname)
    end,
    settings = {
      csharp = {
        solution = solution_name .. ".sln",
      },
    },
  }
  require("lspconfig").csharp_ls.setup(config)

  vim.defer_fn(function()
    vim.cmd("LspStart")
  end, 300)
end

local function select_solution_file_and_setup_lsp()
  if not is_lsp_attached() then
    local solutions = find_solution_files(vim.fn.getcwd()) -- Get solutions in the current working directory
    if #solutions == 0 then
      print("No solution files found.")
      return
    end

    vim.ui.select(solutions, {
      prompt = "Select a solution file:",
      format_item = function(item)
        return vim.fn.fnamemodify(item, ":t") -- Return only the filename, not the full path
      end,
    }, function(choice)
      if not choice then
        return
      end
      local solution_name = vim.fn.fnamemodify(choice, ":t:r") -- Removes the path and extension
      setup_lsp_with_solution(solution_name)
    end)
  end
end

-- Function to dynamically configure csharp_ls
local function setup_csharp_ls()
  if not is_lsp_attached() then -- Check if the LSP is not already attached
    local solution_name = vim.fn.input("Enter Solution Name: ", "", "file")
    local config = {
      cmd = { "csharp-ls" },
      filetypes = { "cs" },
      root_dir = function(fname)
        local util = require("lspconfig.util")
        return util.root_pattern(solution_name)(fname) or util.root_pattern("*.csproj")(fname)
      end,
      settings = {
        csharp = {
          solution = solution_name,
        },
      },
    }
    require("lspconfig").csharp_ls.setup(config)
    -- Manually start the client for the current buffer
    vim.defer_fn(function()
      vim.cmd("LspStart")
    end, 300)
  end
end

-- Autocommand to setup csharp_ls for .cs files
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { "*.cs" },
  callback = select_solution_file_and_setup_lsp,
})
--[[
local original_lsp_start = vim.lsp.start_client

local function pre_lsp_start()
  local user_solution_name = vim.fn.input("Enter Solution Name: ")
  local util = require("lspconfig.util")

  require("lspconfig").csharp_ls.setup({
    cmd = { "csharp-ls" },
    filetypes = { "cs" },
    root_dir = function(fname)
      return util.root_pattern("*" .. user_solution_name)(fname)
        or util.root_pattern("*" .. user_solution_name .. ".csproj")(fname)
    end,
    single_file_support = true,
    init_options = {
      AutomaticWorkspaceInit = true,
    },
    settings = {
      csharp = {
        solution = "user_solution_name",
     e},
    },
  })
end

vim.lsp.start_client = function(config)
  -- Get the current buffer number
  local bufnr = vim.api.nvim_get_current_buf()
  -- Check the filetype of the buffer
  local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")

  -- Apply custom function only for 'cs' filetype
  if filetype == "cs" then
    pre_lsp_start()
  end

  -- Call the original LspStart function
  return original_lsp_start(config)
end

local function augroup(name)
  return vim.api.nvim_create_augroup("lazyvim_" .. name, { clear = true })
end

--]]
--[[
vim.api.nvim_create_autocmd({ "FileType" }, {
  group = augroup("csharp_lsp_setup"),
  pattern = {
    "cs",
  },
  callback = function(_)
    setup_csharp_ls()
  end,
})
--]]
