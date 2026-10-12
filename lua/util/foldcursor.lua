-- A caret on a closed fold, the way JetBrains has one.
--
-- Vim draws the cursor at the first column of a closed fold and gives
-- `h`/`l`/`w`/`b`/`e` the hidden first line to move over. Here, on a closed
-- fold, those motions (and `^` `_` `$`) walk the fold line as it's drawn —
-- `fn send( ... ) -> Result<(), Error> {` — one character at a time, and
-- the real cursor is placed on the buffer position that character stands
-- for (the fold's last line for `Result`), so hover, diagnostics and
-- go-to-definition act on what the caret is on. Stepping onto the ` ... `
-- opens the fold where the hidden text begins. The caret is drawn by
-- util/foldtext.lua; Vim's own cursor stays in the first column.
local M = {}
local api = vim.api

---@class util.foldcursor.State the caret in a window
---@field buf integer
---@field start integer first line of the closed fold
---@field cell integer index into the fold line's cells
---@field lnum integer buffer position the cell stands for…
---@field col integer …and the real cursor was placed on
---@field tick integer changedtick then

local states = {} ---@type table<integer, util.foldcursor.State>

--- The caret cell to draw in the fold starting at `start` of the window,
--- if the caret is still there: the text unchanged, the real cursor still
--- where the caret put it.
---@return integer?
function M.cell_at(win, buf, start)
  local st = states[win]
  if not st or st.buf ~= buf or st.start ~= start then
    return
  end
  local cur = api.nvim_win_get_cursor(win)
  if api.nvim_buf_get_changedtick(buf) ~= st.tick or cur[1] ~= st.lnum or cur[2] ~= st.col then
    states[win] = nil
    return
  end
  return st.cell
end

local foldtext = require("util.foldtext")

--- The fold line's cells (util/foldtext.lua) for the closed fold.
local function cells_of(buf, start, stop)
  return foldtext.cells(foldtext.build(buf, start, stop))
end

--- The caret's cell: the one it was left on, else the cell standing for
--- the real cursor's position (or the last one before it on that line),
--- else the first.
local function current_cell(win, buf, start, cells)
  local known = M.cell_at(win, buf, start)
  if known then
    return known
  end
  local cur = api.nvim_win_get_cursor(win)
  local best = 1
  for i, c in ipairs(cells) do
    if c.lnum == cur[1] and c.col <= cur[2] then
      best = i
    end
  end
  return best
end

local function visible(c)
  return c.lnum ~= nil
end

--- Nearest visible cell at or after/before index i, stepping by dir.
local function nearest(cells, i, dir)
  while cells[i] and not visible(cells[i]) do
    i = i + dir
  end
  return cells[i] and i or nil
end

local scratch ---@type integer? a buffer the word motions run in

--- Where a word motion (`run`, acting on the current window) lands from
--- byte `col` of the fold line, run on that line with its neighbours
--- above and below: the resulting line (1 = the line above the fold, 2 =
--- the fold line, 3 = the line below) and byte column.
local function word_motion(buf, run, text, col, above, below)
  if not (scratch and api.nvim_buf_is_valid(scratch)) then
    scratch = api.nvim_create_buf(false, true)
    vim.bo[scratch].bufhidden = "hide"
  end
  api.nvim_buf_set_lines(scratch, 0, -1, false, { above, text, below })
  vim.bo[scratch].iskeyword = vim.bo[buf].iskeyword
  local c = api.nvim_buf_call(scratch, function()
    api.nvim_win_set_cursor(0, { 2, col })
    run()
    return api.nvim_win_get_cursor(0)
  end)
  return c[1], c[2]
end

--- Open the closed fold at the cursor and put the cursor where the hidden
--- text begins (`dir` 1: the line after the cell `from` stands for) or
--- ends (`dir` -1: the line before it).
local function open_into(win, from, dir)
  api.nvim_win_call(win, function()
    vim.cmd("normal! zo")
    local lnum = from.lnum + dir
    local line = vim.fn.getline(lnum)
    local col = dir > 0 and #line:match("^%s*") or math.max(#line - 1, 0)
    api.nvim_win_set_cursor(win, { lnum, col })
  end)
end

--- Run a motion with the pending count: as it is unless the cursor is on
--- a closed fold, where it walks the fold line. `h` `l` `^` `_` `$` step
--- the line's cells; any other key is a word motion, run by `run` (Vim's
--- own `normal!` motion without one) over the drawn line.
---@param key string
---@param run? fun() performs the motion in the current window
function M.motion(key, run)
  local count = vim.v.count
  run = run or function()
    vim.cmd("normal! " .. (count > 0 and count or "") .. key)
  end
  local win, buf = api.nvim_get_current_win(), api.nvim_get_current_buf()
  local lnum = api.nvim_win_get_cursor(win)[1]
  local start = vim.fn.foldclosed(lnum)
  if start == -1 then
    run()
    return
  end
  count = math.max(count, 1)
  local stop = vim.fn.foldclosedend(lnum)
  local cells = cells_of(buf, start, stop)
  if #cells == 0 then
    return
  end
  local at = current_cell(win, buf, start, cells)
  local target ---@type integer? cell to land on
  local leave ---@type { [1]: integer, [2]: integer }? buffer position to leave the fold for
  if key == "l" then
    target = math.min(at + count, #cells)
  elseif key == "h" then
    target = math.max(at - count, 1)
  elseif key == "$" then
    target = nearest(cells, #cells, -1)
  elseif key == "^" or key == "_" then
    target = 1
    while cells[target] and cells[target].ch:match("^%s$") do
      target = target + 1
    end
    target = nearest(cells, target, 1)
  else -- a word motion over the drawn line
    local text, col = "", 0
    for i, c in ipairs(cells) do
      if i == at then
        col = #text
      end
      text = text .. c.ch
    end
    local above = start > 1 and vim.fn.getline(start - 1) or ""
    local below = stop < vim.fn.line("$") and vim.fn.getline(stop + 1) or ""
    local line, newcol = word_motion(buf, run, text, col, above, below)
    if line == 2 then
      target = vim.fn.charidx(text, newcol) + 1
    elseif line == 1 and start > 1 then
      leave = { start - 1, newcol }
    elseif line == 3 and stop < vim.fn.line("$") then
      leave = { stop + 1, newcol }
    else
      return
    end
  end
  if leave then
    api.nvim_win_set_cursor(win, leave)
    return
  end
  if not target then
    return
  end
  local cell = cells[target]
  if not visible(cell) then
    -- onto the ` ... `: open the fold where the hidden text starts
    local dir = target >= at and 1 or -1
    local edge = nearest(cells, target, -dir)
    if edge then
      open_into(win, cells[edge], dir)
    else
      vim.cmd("normal! zo")
    end
    return
  end
  api.nvim_win_set_cursor(win, { cell.lnum, cell.col })
  states[win] = {
    buf = buf,
    start = start,
    cell = target,
    lnum = cell.lnum,
    col = cell.col,
    tick = api.nvim_buf_get_changedtick(buf),
  }
  pcall(api.nvim__redraw, { win = win, range = { start - 1, stop }, valid = false })
end

function M.setup()
  vim.opt.foldopen:remove("hor") -- the caret walks the fold line instead
  api.nvim_set_hl(0, "FoldCursor", { reverse = true, default = true })
  api.nvim_create_autocmd("WinClosed", {
    group = api.nvim_create_augroup("fold_cursor", { clear = true }),
    callback = function(ev)
      states[tonumber(ev.match)] = nil
    end,
  })
end

return M
