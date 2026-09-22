-- Keep 'scrolloff' below the cursor even at the end of the buffer (Zed's
-- scroll_beyond_last_line): vim normally lets the cursor sit on the last
-- screen rows once the final line is visible; instead scroll on so the last
-- line is followed by 'scrolloff' blank rows. Only ever scrolls forward, so
-- moving back up behaves normally.
local M = {}

--- The buffer line one screen row below `line` (a closed fold is one row).
local function next_row(line)
  local fold_end = vim.fn.foldclosedend(line)
  return (fold_end ~= -1 and fold_end or line) + 1
end

function M.keep_margin_past_end()
  if vim.bo.buftype ~= "" or vim.api.nvim_win_get_config(0).relative ~= "" then
    return
  end
  local so = vim.wo.scrolloff >= 0 and vim.wo.scrolloff or vim.o.scrolloff
  local limit = vim.api.nvim_win_get_height(0) - so
  if so == 0 or limit < 1 then
    return
  end
  -- winline() is the cursor's real screen row, folds and wrapping included;
  -- while it sits inside the bottom margin, scroll the view down one row at
  -- a time. Vim's own scrolloff already handles this everywhere except the
  -- end of the buffer, so the loop only ever runs there.
  local cur = vim.fn.line(".")
  local view = vim.fn.winsaveview()
  while vim.fn.winline() > limit and view.topline < cur do
    view.topline = next_row(view.topline)
    vim.fn.winrestview(view)
  end
end

function M.setup()
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = vim.api.nvim_create_augroup("scrolloff_past_end", { clear = true }),
    callback = M.keep_margin_past_end,
  })
end

return M
