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
--- cursor moves) and the buffer's floating preview (ge, native hover).
function M.dismiss()
  if package.loaded["noice"] then
    local docs = require("noice.lsp.docs")
    for _, message in pairs(docs._messages) do
      if message:win() then
        docs.hide(message)
      end
    end
  end
  local float = vim.b.lsp_floating_preview
  if float and vim.api.nvim_win_is_valid(float) then
    vim.api.nvim_win_close(float, true)
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
