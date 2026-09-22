-- Keep 'scrolloff' below the cursor even at the end of the buffer (Zed's
-- scroll_beyond_last_line): vim normally lets the cursor sit on the last
-- screen rows once the final line is visible; instead scroll on so the last
-- line is followed by 'scrolloff' blank rows. Only ever scrolls forward, so
-- moving back up behaves normally.
local M = {}

--- Screen rows spanned by buffer lines from..to (closed folds count as one
--- row, wrapped lines as several).
local function rows(from, to)
  return vim.api.nvim_win_text_height(0, { start_row = from - 1, end_row = to - 1 }).all
end

function M.keep_margin_past_end()
  if vim.bo.buftype ~= "" or vim.api.nvim_win_get_config(0).relative ~= "" then
    return
  end
  local so = vim.wo.scrolloff >= 0 and vim.wo.scrolloff or vim.o.scrolloff
  if so == 0 then
    return
  end
  local cur, last = vim.fn.line("."), vim.fn.line("$")
  if cur < last and rows(cur + 1, last) >= so then
    return -- regular scrolloff already applies
  end
  -- walk up from the cursor until the rows from there to the cursor fill
  -- the window minus the margin; that line becomes the new topline
  local budget = vim.api.nvim_win_get_height(0) - so
  local want = cur
  while want > 1 do
    local prev = want - 1
    local fold = vim.fn.foldclosed(prev)
    if fold ~= -1 then
      prev = fold
    end
    if rows(prev, cur) > budget then
      break
    end
    want = prev
  end
  local view = vim.fn.winsaveview()
  if want > view.topline then
    view.topline = want
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
