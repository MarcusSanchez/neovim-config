-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
--
-- only show virtual text for level error diagnostics, not warnings or info
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    vim.diagnostic.config({
      virtual_text = {
        severity = { min = vim.diagnostic.severity.ERROR },
      },
    })
  end,
})

vim.api.nvim_create_autocmd("LspAttach", {
  pattern = { "*.proto" },
  callback = function(args)
    vim.diagnostic.config({
      virtual_text = {
        severity = {
          min = vim.diagnostic.severity.ERROR,
        },
      },
      underline = {
        severity = {
          min = vim.diagnostic.severity.ERROR,
        },
      },
    })
  end,
})
