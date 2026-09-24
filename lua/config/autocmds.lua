-- Autocmds are loaded on the VeryLazy event. LazyVim's defaults:
-- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Feature logic lives in lua/util/; this file only wires it to events.

local autocmd = vim.api.nvim_create_autocmd
local function augroup(name)
  return vim.api.nvim_create_augroup("marcus_" .. name, { clear = true })
end

--------------------------------------------------------------------------------
-- Diagnostics
--------------------------------------------------------------------------------

-- protobuf: only errors get an underline too. NOTE: vim.diagnostic.config is
-- global, so once a .proto buffer has attached this applies everywhere for
-- the rest of the session.
autocmd("LspAttach", {
  group = augroup("proto_diagnostics"),
  pattern = "*.proto",
  callback = function()
    vim.diagnostic.config({
      underline = { severity = { min = vim.diagnostic.severity.ERROR } },
    })
  end,
})

-- shadowed variables in Go are already painted a distinct color via the
-- @lsp.typemod.variable.shadowing.go semantic token (catppuccin.lua), so the
-- `shadow` analyzer's info diagnostic (blue squiggle + sign) is redundant —
-- drop it before it renders
local function is_shadow(d)
  return d.source == "shadow"
    or d.code == "shadow"
    or (d.message and d.message:find("shadows declaration", 1, true) ~= nil)
end

local orig_diagnostic_set = vim.diagnostic.set
---@diagnostic disable-next-line: duplicate-set-field
vim.diagnostic.set = function(ns, bufnr, diagnostics, opts)
  return orig_diagnostic_set(
    ns,
    bufnr,
    vim.tbl_filter(function(d)
      return not is_shadow(d)
    end, diagnostics),
    opts
  )
end

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
