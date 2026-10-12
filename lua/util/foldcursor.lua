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

---@class util.foldcursor.Segment a ` ... ` of the fold line and what it hides
---@field from integer first cell of the drawn run
---@field to integer last cell of it
---@field first integer first hidden buffer line
---@field last integer last hidden buffer line
---@field fold_s integer the fold hiding them runs from this line…
---@field fold_e integer …to this one (the visible lines either side)

--- The fold line's hidden runs, each with the lines it stands for: the
--- lines between the visible cells either side of it (the fold's edges
--- when there's none).
---@return util.foldcursor.Segment[]
local function segments(cells, start, stop)
  local out, i = {}, 1
  while i <= #cells do
    if visible(cells[i]) then
      i = i + 1
    else
      local j = i
      while cells[j + 1] and not visible(cells[j + 1]) do
        j = j + 1
      end
      local before, after = cells[i - 1], cells[j + 1]
      out[#out + 1] = {
        from = i,
        to = j,
        first = before and before.lnum + 1 or start,
        last = after and after.lnum - 1 or stop,
        fold_s = before and before.lnum or start,
        fold_e = after and after.lnum or stop,
      }
      i = j + 1
    end
  end
  return out
end

--- Stepping onto a ` ... `: open what it hides and nothing else. The
--- closed fold opens; of the line's other hidden runs each gets its own
--- fold closed again (`fn f( ... ) -> R { ... }` onto the first dots
--- shows the parameters with the body still folded); folds inside the
--- revealed lines stay as they were. The cursor lands where the hidden
--- text begins (`dir` 1) or ends (`dir` -1).
local function open_segment(win, buf, start, stop, cells, target, dir)
  local segs = segments(cells, start, stop)
  local mine
  for _, seg in ipairs(segs) do
    if target >= seg.from and target <= seg.to then
      mine = seg
    end
  end
  if not mine then
    return
  end
  api.nvim_win_call(win, function()
    vim.cmd("normal! zo")
    -- the fold hiding this run, if still closed inside (not deeper ones)
    for _ = 1, 10 do
      local closed = vim.fn.foldclosed(mine.first)
      if closed == -1 or closed > mine.fold_s then
        break
      end
      vim.cmd(("silent! %dfoldopen"):format(mine.first))
    end
    local FR, folds = require("util.foldranges"), require("util.folds")
    for _, seg in ipairs(segs) do
      local closed = vim.fn.foldclosed(seg.first)
      if seg ~= mine and (closed == -1 or closed > seg.fold_s) then
        local s, e = FR.fold(buf, win, seg.fold_s - 1, seg.fold_e - 1)
        if s then
          folds.close_exact(s, e)
        end
      end
    end
    local lnum = dir > 0 and mine.first or mine.last
    local line = vim.fn.getline(lnum)
    local col = dir > 0 and #line:match("^%s*") or math.max(#line - 1, 0)
    api.nvim_win_set_cursor(win, { lnum, col })
  end)
end

-- Vim's own cursor sits in the fold line's first column whatever the
-- caret does; while the caret is drawn it's a beam in the line's colour.
local shown_as ---@type string? 'guicursor' before the cursor was hidden

local function hide_cursor(win)
  local function bg(group)
    local ok, hl = pcall(api.nvim_get_hl, 0, { name = group, link = false })
    return ok and hl.bg or nil
  end
  local color = (vim.wo[win].cursorline and bg("CursorLine")) or bg("Folded") or bg("Normal")
  if not color then
    return
  end
  api.nvim_set_hl(0, "FoldHiddenCursor", { fg = color, bg = color })
  if not shown_as then
    shown_as = vim.o.guicursor
    vim.o.guicursor = shown_as .. ",n:ver1-FoldHiddenCursor"
  end
end

local function show_cursor()
  if shown_as then
    vim.o.guicursor = shown_as
    shown_as = nil
  end
end

--- Whether the current window's cursor is on a caret it drew.
local function on_caret()
  local win, buf = api.nvim_get_current_win(), api.nvim_get_current_buf()
  local start = vim.fn.foldclosed(api.nvim_win_get_cursor(win)[1])
  return start ~= -1 and M.cell_at(win, buf, start) ~= nil
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
    open_segment(win, buf, start, stop, cells, target, target >= at and 1 or -1)
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
  hide_cursor(win)
  pcall(api.nvim__redraw, { win = win, range = { start - 1, stop }, valid = false })
end

--- The hidden-cursor state, for tests: the 'guicursor' value it will go
--- back to, nil while shown.
function M.hidden()
  return shown_as
end

function M.setup()
  vim.opt.foldopen:remove("hor") -- the caret walks the fold line instead
  api.nvim_set_hl(0, "FoldCursor", { reverse = true, default = true })
  local group = api.nvim_create_augroup("fold_cursor", { clear = true })
  api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(ev)
      states[tonumber(ev.match)] = nil
    end,
  })
  -- the cursor comes back as soon as the caret is gone: moved off, the
  -- text edited, the window or mode left
  api.nvim_create_autocmd({ "CursorMoved", "TextChanged", "InsertEnter", "WinLeave", "BufLeave", "ModeChanged" }, {
    group = group,
    callback = function()
      if shown_as and not on_caret() then
        show_cursor()
      end
    end,
  })
end

return M
