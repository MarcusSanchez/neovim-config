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

-- when :q closes the last real window, quit nvim entirely instead of leaving
-- the snacks explorer sidebar behind (closing just the explorer here isn't
-- enough — snacks re-seats it on an empty scratch buffer)
vim.api.nvim_create_autocmd("QuitPre", {
  callback = function()
    local explorer = package.loaded["snacks"] and Snacks.picker.get({ source = "explorer" })[1]
    if not explorer or explorer.closed then
      return
    end
    -- count non-floating windows that don't belong to a snacks picker; when
    -- the window being :q'd is the only one, upgrade the :q to :qa
    local real = 0
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.api.nvim_win_get_config(win).relative == "" then
        local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
        if not ft:find("^snacks_") then
          real = real + 1
        end
      end
    end
    if real <= 1 then
      -- scheduled so the original :q finishes first; if it aborts on a
      -- modified buffer, qall raises the same E37 rather than force-quitting
      vim.schedule(function()
        vim.cmd("qall")
      end)
    end
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "go",
  callback = function()
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
    vim.opt_local.expandtab = true
  end,
})

-- Autosave like Zed (`autosave.after_delay = 300ms`), but only from normal
-- mode: nothing is written while typing in insert mode; leaving insert counts
-- as a normal-mode change, so the save lands 300ms after `jj`. Like Zed,
-- these saves skip format-on-save — only an explicit :w / ,f formats — so
-- cargo check / golangci-lint / eslint get pause-triggered diagnostics
-- without the buffer being reshuffled mid-thought.
local autosave_delay = 300
local autosave_timers = {} ---@type table<integer, uv.uv_timer_t>

local function autosave(buf)
  autosave_timers[buf] = nil
  if not vim.api.nvim_buf_is_valid(buf) or not vim.bo[buf].modified then
    return
  end
  local name = vim.api.nvim_buf_get_name(buf)
  if vim.bo[buf].buftype ~= "" or name == "" or not vim.bo[buf].modifiable or vim.bo[buf].readonly then
    return
  end
  if vim.fn.filewritable(name) ~= 1 then
    return -- unsaved new file, or not ours to write
  end
  vim.api.nvim_buf_call(buf, function()
    local autoformat = vim.b[buf].autoformat
    vim.b[buf].autoformat = false
    -- silent!: a file changed on disk (E13/E211) shouldn't raise on a timer
    pcall(vim.cmd, "silent! update")
    vim.b[buf].autoformat = autoformat
  end)
end

vim.api.nvim_create_autocmd("TextChanged", {
  group = vim.api.nvim_create_augroup("autosave_after_delay", { clear = true }),
  callback = function(ev)
    local timer = autosave_timers[ev.buf]
    if timer then
      timer:stop()
      timer:close()
    end
    autosave_timers[ev.buf] = vim.defer_fn(function()
      autosave(ev.buf)
    end, autosave_delay)
  end,
})

-- keep 'scrolloff' blank rows below the last line of the buffer (Zed's
-- scroll_beyond_last_line)
require("util.scroll").setup()
