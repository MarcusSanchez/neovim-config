-- Cursor popups: the gk hover (noice), the ge diagnostics float, and the
-- <Esc> that dismisses them. They share the CursorPopup/CursorPopupBorder
-- highlight groups (catppuccin.lua) with the snacks pickers.
local M = {}

M.winhighlight = "Normal:CursorPopup,FloatBorder:CursorPopupBorder"

--- Open the diagnostics for the cursor line in a float styled like the hover.
function M.diagnostics()
  local _, win = vim.diagnostic.open_float({ border = "rounded" })
  if win then
    vim.wo[win].winhighlight = M.winhighlight
  end
end

--- Close any open hover / signature docs (noice keeps them up until the
--- cursor moves) and any LSP floating preview on this tab (ge, native
--- hover) — wherever <Esc> is pressed, including from inside the float
--- after a second ge focused it.
function M.dismiss()
  if package.loaded["noice"] then
    local docs = require("noice.lsp.docs")
    for _, message in pairs(docs._messages) do
      if message:win() then
        docs.hide(message)
      end
    end
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    -- open_floating_preview tags its window with the buffer it belongs to
    if vim.api.nvim_win_get_config(win).relative ~= "" and vim.w[win].lsp_floating_bufnr then
      vim.api.nvim_win_close(win, true)
    end
  end
end

--- Normal-mode <Esc>: LazyVim's clear-hlsearch + snippet-stop, plus dismiss.
--- Expression mapping — returns the key to feed.
function M.escape()
  vim.cmd("noh")
  LazyVim.cmp.actions.snippet_stop()
  M.dismiss()
  return "<Esc>"
end

return M
