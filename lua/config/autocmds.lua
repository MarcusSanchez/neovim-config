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
  return orig_diagnostic_set(ns, bufnr, vim.tbl_filter(function(d)
    return not is_shadow(d)
  end, diagnostics), opts)
end

-- when :q closes the last real window, take the snacks explorer sidebar down
-- with it (instead of leaving it behind as the last window keeping nvim open)
vim.api.nvim_create_autocmd("QuitPre", {
  callback = function()
    local explorer = package.loaded["snacks"] and Snacks.picker.get({ source = "explorer" })[1]
    if not explorer or explorer.closed then
      return
    end
    -- count non-floating windows that don't belong to a snacks picker; when
    -- the window being :q'd is the only one, the explorer goes too
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
      explorer:close()
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
