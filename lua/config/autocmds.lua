-- Autocmds are loaded at startup when files are given, on VeryLazy for a
-- bare `nvim`. LazyVim's defaults:
-- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Feature logic lives in lua/util/; this file only wires it to events.

local autocmd = vim.api.nvim_create_autocmd
local function augroup(name)
  return vim.api.nvim_create_augroup("marcus_" .. name, { clear = true })
end

--------------------------------------------------------------------------------
-- Diagnostics
--------------------------------------------------------------------------------

-- protobuf: only errors get an underline too — for buf's diagnostics
-- only (the config is scoped to the client's namespace)
autocmd("LspAttach", {
  group = augroup("proto_diagnostics"),
  pattern = "*.proto",
  callback = function(args)
    vim.diagnostic.config({
      underline = { severity = { min = vim.diagnostic.severity.ERROR } },
    }, vim.lsp.diagnostic.get_namespace(args.data.client_id))
  end,
})

-- gopls' shadowed-variable diagnostics are redundant with the semantic
-- token colour; drop them
require("util.diagnostics").setup()

--------------------------------------------------------------------------------
-- Windows & buffers
--------------------------------------------------------------------------------

-- :q on the last real window quits nvim outright instead of leaving the
-- explorer sidebar behind
autocmd("QuitPre", {
  group = augroup("quit_with_explorer"),
  callback = function()
    require("util.explorer").on_quit_pre()
  end,
})

-- write on leaving insert mode, and 300ms after a normal-mode edit; never
-- formats
require("util.autosave").setup({ delay = 300 })

-- keep 'scrolloff' blank rows below the last line of the buffer
require("util.scroll").setup()

-- folds: the language server's ranges feed the fold expression, closed
-- folds survive closing the file and restarting nvim, and a search doesn't
-- unfold what it passes through
require("util.foldranges").setup()
require("util.folds").setup()
require("util.searchfolds").setup()
require("util.foldcursor").setup()

-- a bare `nvim` in a project with a session restores it instead of the
-- dashboard. Scheduled: this file runs inside LazyVim's VeryLazy handler,
-- before keymaps.lua, and the restored buffers' LSPs must find the LspAttach
-- maps defined there.
require("util.session").setup()
vim.schedule(function()
  require("util.session").restore()
end)

--------------------------------------------------------------------------------
-- Filetypes
--------------------------------------------------------------------------------

-- plain text is for notes and scratch: no spell-check squiggles. (LazyVim's
-- lazyvim_wrap_spell turns spell on for text/markdown/gitcommit; wrap stays.)
-- Those squiggles are vim's spell checker, not diagnostics — which is why
-- ,g / ge have nothing to act on there.
autocmd("FileType", {
  group = augroup("text_no_spell"),
  pattern = "text",
  callback = function()
    vim.opt_local.spell = false
  end,
})

autocmd("FileType", {
  group = augroup("go_indent"),
  pattern = "go",
  callback = function()
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
    vim.opt_local.expandtab = true
  end,
})
