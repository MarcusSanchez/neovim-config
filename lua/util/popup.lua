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

--- The markdown link under the cursor on the current line, else the one
--- nearest to it: `[label](target)`, target like file:///path#L12 or a
--- plain path with optional #L<row>.
---@return { file: string, row: integer? }?
local function link_at_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  local best, best_dist
  local from = 1
  while true do
    local s, e, target = line:find("%[[^%]]-%]%((%S-)%)", from)
    if not s then
      break
    end
    local dist = col < s and s - col or (col > e and col - e or 0)
    if not best or dist < best_dist then
      best, best_dist = target, dist
    end
    from = e + 1
  end
  if not best then
    return
  end
  local file, row = best:match("^(.-)#L(%d+)$")
  file = file or best
  file = file:gsub("^file://", "")
  file = vim.uri_decode and vim.uri_decode(file) or file
  return { file = file, row = tonumber(row) }
end

--- gd inside the gk hover: jump to the link under (or nearest) the cursor —
--- the "Go to [Type](file:///...#L12)" footers zls/rust-analyzer emit — and
--- close the hover. Pushes the tagstack so gh comes back.
function M.follow_link()
  local link = link_at_cursor()
  if not link or vim.fn.filereadable(link.file) ~= 1 then
    return vim.notify("No file link under the cursor", vim.log.levels.WARN, { title = "Goto Definition" })
  end
  -- close the hover we're standing in right now (noice hides its windows on
  -- its own schedule) so the file never opens inside the float, then the rest
  local win = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_config(win).relative ~= "" then
    pcall(vim.api.nvim_win_close, win, true)
  end
  M.dismiss()
  -- back in the source window now that the float is gone
  local from = vim.fn.getpos(".")
  from[1] = vim.api.nvim_get_current_buf()
  vim.fn.settagstack(0, { items = { { tagname = vim.fn.fnamemodify(link.file, ":t"), from = from } } }, "t")
  vim.cmd.edit(vim.fn.fnameescape(link.file))
  if link.row then
    vim.api.nvim_win_set_cursor(0, { math.min(link.row, vim.api.nvim_buf_line_count(0)), 0 })
    vim.cmd("normal! zz")
  end
end

--- Normal-mode <Esc>: LazyVim's clear-hlsearch + snippet-stop, plus dismiss.
--- Expression mapping — returns the key to feed. Windows can't be closed
--- while an expression mapping evaluates (E565 textlock), so the dismissal
--- is deferred until the key has been processed.
function M.escape()
  vim.cmd("noh")
  LazyVim.cmp.actions.snippet_stop()
  vim.schedule(M.dismiss)
  return "<Esc>"
end

return M
