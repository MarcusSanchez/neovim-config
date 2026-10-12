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
---@field stop integer its last line
---@field cell integer index into the fold line's cells
---@field lnum integer buffer position the cell stands for…
---@field col integer …and the real cursor was placed on
---@field tick integer changedtick then

local states = {} ---@type table<integer, util.foldcursor.State>

--- Set to a function to see the caret's decisions (tests/probing).
---@type fun(msg: string)?
M.trace = nil
local function trace(msg)
  if M.trace then
    M.trace(msg)
  end
end

local foldtext = require("util.foldtext")

--- The fold line's cells (util/foldtext.lua) for the closed fold.
local function cells_of(buf, start, stop)
  return foldtext.cells(foldtext.build(buf, start, stop))
end

--- The caret cell to draw in the fold starting at `start` of the window,
--- if the caret is still there: the real cursor still where the caret
--- put it, and that cell still standing for that position.
---@return integer?
function M.cell_at(win, buf, start)
  local st = states[win]
  if not st or st.buf ~= buf or st.start ~= start then
    return
  end
  local cur = api.nvim_win_get_cursor(win)
  if cur[1] ~= st.lnum or cur[2] ~= st.col then
    trace(("cell_at: dropped (cursor %d:%d vs %d:%d)"):format(cur[1], cur[2], st.lnum, st.col))
    states[win] = nil
    return
  end
  local tick = api.nvim_buf_get_changedtick(buf)
  if tick ~= st.tick then
    -- the text changed (or only the tick: a save's pre-save edits): the
    -- caret stays if its cell still stands for the cursor's position
    local stop = api.nvim_win_call(win, function()
      return vim.fn.foldclosedend(st.start)
    end)
    local cell = stop ~= -1 and cells_of(buf, st.start, stop)[st.cell]
    if not (cell and cell.lnum == st.lnum and cell.col == st.col) then
      trace(("cell_at: dropped (tick %d vs %d, cell moved)"):format(tick, st.tick))
      states[win] = nil
      return
    end
    st.stop, st.tick = stop, tick
  end
  return st.cell
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

--- A cell drawn as part of the hidden text: the ` ... ` itself, or the
--- closer drawn dim behind it (the `}` of `func main() { ... }`).
local function dim(c)
  return not visible(c) or c.hl == "FoldEllipsis"
end

--- Nearest visible cell at or after/before index i, stepping by dir.
local function nearest(cells, i, dir)
  while cells[i] and not visible(cells[i]) do
    i = i + dir
  end
  return cells[i] and i or nil
end

local scratch ---@type integer? a buffer the word motions run in

---@class util.foldcursor.Drawn a closed fold as the word motions see it
---@field start integer
---@field stop integer
---@field text string the fold line
---@field cells util.foldtext.Cell[]

--- The buffer with each of the closed folds replaced by its drawn line,
--- and the line mappings both ways (`to_copy` gives the copy's line for
--- a buffer line, `from_copy` a buffer line or the fold drawn there).
---@param folds util.foldcursor.Drawn[] sorted by start
local function copy_with(buf, folds)
  local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
  local copy, at = {}, 1
  for _, f in ipairs(folds) do
    vim.list_extend(copy, lines, at, f.start - 1)
    copy[#copy + 1] = f.text
    at = f.stop + 1
  end
  vim.list_extend(copy, lines, at, #lines)
  local function to_copy(lnum)
    local off = 0
    for _, f in ipairs(folds) do
      if lnum > f.stop then
        off = off + f.stop - f.start
      elseif lnum >= f.start then
        return f.start - off
      end
    end
    return lnum - off
  end
  local function from_copy(lnum)
    local off = 0
    for _, f in ipairs(folds) do
      if lnum == f.start - off then
        return nil, f
      elseif lnum > f.start - off then
        off = off + f.stop - f.start
      end
    end
    return lnum + off
  end
  return copy, to_copy, from_copy
end

--- Run a word motion (`run`, acting on the current window) in the copy,
--- from buffer position (lnum, col) — or the fold line's byte `col` when
--- lnum is a drawn fold's — and return where it lands, in the copy's
--- lines.
local function run_in_copy(buf, run, copy, lnum, col)
  if not (scratch and api.nvim_buf_is_valid(scratch)) then
    scratch = api.nvim_create_buf(false, true)
    vim.bo[scratch].bufhidden = "hide"
  end
  api.nvim_buf_set_lines(scratch, 0, -1, false, copy)
  vim.bo[scratch].iskeyword = vim.bo[buf].iskeyword
  local c = api.nvim_buf_call(scratch, function()
    api.nvim_win_set_cursor(0, { lnum, col })
    run()
    return api.nvim_win_get_cursor(0)
  end)
  return c[1], c[2]
end

local function drawn(buf, start, stop)
  local cells = cells_of(buf, start, stop)
  local text = ""
  for _, c in ipairs(cells) do
    text = text .. c.ch
  end
  return { start = start, stop = stop, text = text, cells = cells }
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

--- The fold line ends in hidden text (` ... `, or a dim closer): going
--- to its end opens that last run and puts the cursor at the end of the
--- fold's last line.
local function open_end(win, buf, start, stop, cells)
  local last = #cells
  while last > 1 and visible(cells[last]) do
    last = last - 1 -- back from a dim closer onto the dots
  end
  api.nvim_win_set_cursor(win, { start, 0 })
  open_segment(win, buf, start, stop, cells, last, -1)
  local line = vim.fn.getline(stop)
  api.nvim_win_set_cursor(win, { stop, math.max(#line - 1, 0) })
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

--- The caret onto cell `target`: the real cursor goes to the position it
--- stands for, keeping `curswant` (the column a later `j`/`k` heads for)
--- at the drawn column rather than that position's.
local function place(win, buf, start, stop, cells, target, curswant)
  local cell = cells[target]
  trace(("place: cell %d at %d:%d"):format(target, cell.lnum, cell.col))
  api.nvim_win_set_cursor(win, { cell.lnum, cell.col })
  api.nvim_win_call(win, function()
    vim.fn.winrestview({ curswant = curswant or target - 1 })
  end)
  states[win] = {
    buf = buf,
    start = start,
    stop = stop,
    cell = target,
    lnum = cell.lnum,
    col = cell.col,
    tick = api.nvim_buf_get_changedtick(buf),
  }
  hide_cursor(win)
  pcall(api.nvim__redraw, { win = win, range = { start - 1, stop }, valid = false })
end

--- Whether 'whichwrap' lets the key cross a line boundary.
local function wraps(key)
  return vim.o.whichwrap:find(key, 1, true) ~= nil
end

--- `h`/`l` wrapping onto buffer line `lnum` ('whichwrap'): onto a closed
--- fold, the caret on its last (`edge` -1) or first (1) drawn character;
--- onto an open line, its last or first character.
local function land(win, buf, lnum, edge)
  local fs = vim.fn.foldclosed(lnum)
  if fs ~= -1 then
    local fe = vim.fn.foldclosedend(lnum)
    local cells = cells_of(buf, fs, fe)
    if edge < 0 and #cells > 0 and dim(cells[#cells]) then
      -- the line ends in hidden text (`import ...`, `{ ... }`): stepping
      -- back onto it is stepping into the fold, which opens at its end
      open_end(win, buf, fs, fe, cells)
      return
    end
    local target = edge < 0 and nearest(cells, #cells, -1) or nearest(cells, 1, 1)
    if target then
      place(win, buf, fs, fe, cells, target)
    end
    return
  end
  local line = vim.fn.getline(lnum)
  api.nvim_win_set_cursor(win, { lnum, edge < 0 and math.max(#line - 1, 0) or 0 })
end

--- A word motion, from a fold line (`start`…: its cells and the caret's
--- cell `at`) or from an open line (none of those): run over the buffer
--- as drawn — every closed fold it lands in is its one drawn line, so a
--- motion from below a folded function onto it lands on the fold line's
--- last word, with the caret, and never inside the fold.
local function word(win, buf, start, stop, cells, at, run)
  local folds = {} ---@type util.foldcursor.Drawn[]
  local origin = api.nvim_win_get_cursor(win)
  if start then
    local f = drawn(buf, start, stop)
    f.cells = cells
    folds[1] = f
    local col = 0
    for i = 1, at - 1 do
      col = col + #cells[i].ch
    end
    origin = { start, col }
  end
  for _ = 1, 8 do
    local line, col
    local landed ---@type util.foldcursor.Drawn?
    if #folds == 0 then
      run()
      line, col = unpack(api.nvim_win_get_cursor(win))
    else
      table.sort(folds, function(x, y)
        return x.start < y.start
      end)
      local copy, to_copy, from_copy = copy_with(buf, folds)
      local from = to_copy(origin[1])
      local cl, cc = run_in_copy(buf, run, copy, from, origin[2])
      line, landed = from_copy(cl)
      col = cc
    end
    if landed then
      local target = vim.fn.charidx(landed.text, col) + 1
      if visible(landed.cells[target]) then
        place(win, buf, landed.start, landed.stop, landed.cells, target)
      else
        -- onto a ` ... `: from the right of it when the caret was on this
        -- fold's line past it, or the motion came from below the fold
        local dir = 1
        if start == landed.start then
          dir = target >= at and 1 or -1
        elseif origin[1] > landed.stop then
          dir = -1
        end
        api.nvim_win_set_cursor(win, { landed.start, 0 })
        open_segment(win, buf, landed.start, landed.stop, landed.cells, target, dir)
      end
      return
    end
    local closed = vim.fn.foldclosed(line)
    if closed == -1 then
      api.nvim_win_set_cursor(win, { line, col })
      return
    end
    folds[#folds + 1] = drawn(buf, closed, vim.fn.foldclosedend(line)) -- redo, with it drawn
  end
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
  local stepping = key == "h" or key == "l" or key == "$" or key == "^" or key == "_"
  if start == -1 then
    if stepping then
      run()
      -- h/l wrapped onto a closed fold ('whichwrap'): its last or first
      -- drawn character, not a hidden line
      local c = api.nvim_win_get_cursor(win)
      if (key == "h" or key == "l") and vim.fn.foldclosed(c[1]) ~= -1 then
        land(win, buf, c[1], key == "h" and -1 or 1)
      end
    else
      word(win, buf, nil, nil, nil, nil, run)
    end
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
  if key == "l" then
    if at + count > #cells and wraps("l") and stop < vim.fn.line("$") then
      return land(win, buf, stop + 1, 1) -- off the end: the line below
    end
    target = math.min(at + count, #cells)
  elseif key == "h" then
    if at - count < 1 and wraps("h") and start > 1 then
      return land(win, buf, start - 1, -1) -- off the start: the line above
    end
    target = math.max(at - count, 1)
  elseif key == "$" then
    if dim(cells[#cells]) then
      return open_end(win, buf, start, stop, cells) -- the end is in the fold
    end
    target = #cells
  elseif key == "^" or key == "_" then
    target = 1
    while cells[target] and cells[target].ch:match("^%s$") do
      target = target + 1
    end
    target = nearest(cells, target, 1)
  else
    word(win, buf, start, stop, cells, at, run)
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
  place(win, buf, start, stop, cells, target)
end

--- Arriving on a closed fold from another line (`j`, `k`, a jump): the
--- caret takes the column the cursor was heading for, as on any line,
--- the nearest drawn character to its left if that falls in a ` ... `.
--- Nothing opens.
local function arrive()
  trace("arrive: mode " .. api.nvim_get_mode().mode)
  if api.nvim_get_mode().mode ~= "n" then
    return
  end
  local win, buf = api.nvim_get_current_win(), api.nvim_get_current_buf()
  local cur = api.nvim_win_get_cursor(win)
  local start = vim.fn.foldclosed(cur[1])
  if start == -1 or M.cell_at(win, buf, start) then
    return
  end
  local stop = vim.fn.foldclosedend(cur[1])
  local cells = cells_of(buf, start, stop)
  if #cells == 0 then
    return
  end
  if cur[1] > start then
    -- below the fold's first line only the caret's own placements put the
    -- cursor (Esc moving it back a column after an insert there): the
    -- cell standing for that position, when there is one
    for i, c in ipairs(cells) do
      if c.lnum == cur[1] and c.col == cur[2] then
        place(win, buf, start, stop, cells, i)
        return
      end
    end
  end
  local want = vim.fn.winsaveview().curswant + 1
  local target = nearest(cells, math.min(want, #cells), -1) or nearest(cells, 1, 1)
  if target then
    place(win, buf, start, stop, cells, target, want - 1)
  end
end

--- The caret onto the cell standing for the real cursor's position (or
--- the last one before it on that line) in the closed fold there.
local function caret_at_cursor(win, buf)
  local lnum = api.nvim_win_get_cursor(win)[1]
  local start = vim.fn.foldclosed(lnum)
  if start == -1 then
    return
  end
  local stop = vim.fn.foldclosedend(lnum)
  local cells = cells_of(buf, start, stop)
  if #cells > 0 then
    place(win, buf, start, stop, cells, current_cell(win, buf, start, cells))
  end
end

--- x / X / r on a caret: the character it stands for is deleted (the
--- count of them to the right / left, within the drawn text of that
--- line) or replaced, the fold stays closed and the caret stays. Off a
--- caret they are Vim's own.
function M.edit(key)
  local count = vim.v.count1
  local win, buf = api.nvim_get_current_win(), api.nvim_get_current_buf()
  local lnum = api.nvim_win_get_cursor(win)[1]
  local start = vim.fn.foldclosed(lnum)
  local ch
  if key == "r" then
    ch = vim.fn.getcharstr()
    if ch == "\27" then
      return
    end
  end
  if start == -1 then
    vim.cmd("normal! " .. count .. key .. (ch or ""))
    return
  end
  local stop = vim.fn.foldclosedend(lnum)
  local cells = cells_of(buf, start, stop)
  local at = current_cell(win, buf, start, cells)
  local cell = cells[at]
  if not (cell and visible(cell)) then
    return
  end
  local function same_line(i)
    return cells[i] and visible(cells[i]) and cells[i].lnum == cell.lnum
  end
  local first, last = at, at
  if key == "x" then
    while last - first + 1 < count and same_line(last + 1) do
      last = last + 1
    end
  elseif key == "X" then
    if not same_line(at - 1) then
      return
    end
    first, last = at - 1, at - 1
    while last - first + 1 < count and same_line(first - 1) do
      first = first - 1
    end
  end
  local from, to = cells[first].col, cells[last].col + #cells[last].ch
  local row = cell.lnum - 1
  api.nvim_buf_set_text(buf, row, from, row, to, { key == "r" and ch:rep(last - first + 1) or "" })
  cells = cells_of(buf, start, stop)
  local target = nearest(cells, math.min(first, #cells), -1)
  if target then
    place(win, buf, start, stop, cells, target)
  end
end

---@class util.foldcursor.Reclose folds opened at the cursor for insert or visual mode, to close again after
---@field buf integer
---@field folds { [1]: integer, [2]: integer }[] outermost first, as opened
---@field lines integer the buffer's line count then (the folds' ends move with it)

-- Insert mode opens the folds under the cursor (Vim does, on entering
-- it), and v opens them to show the selection; what the caret was on
-- closes again when that mode ends, with the caret back where the
-- cursor is. The folds are opened one level at a time so each is known
-- and can be put back exactly, innermost first — closing the outer one
-- alone can't be done while its inner folds are open.
local reclose = {} ---@type table<integer, util.foldcursor.Reclose> after insert mode
local reclose_visual = {} ---@type table<integer, util.foldcursor.Reclose> after visual mode

--- Open the closed folds at the cursor level by level; the folds opened,
--- outermost first, or nil when the line wasn't folded.
---@return util.foldcursor.Reclose?
local function reveal(win, buf)
  local lnum = api.nvim_win_get_cursor(win)[1]
  if vim.fn.foldclosed(lnum) == -1 then
    return
  end
  local r = { buf = buf, folds = {}, lines = api.nvim_buf_line_count(buf) }
  api.nvim_win_call(win, function()
    for _ = 1, 20 do
      local start = vim.fn.foldclosed(lnum)
      if start == -1 then
        break
      end
      r.folds[#r.folds + 1] = { start, vim.fn.foldclosedend(lnum) }
      vim.cmd(("silent! %dfoldopen"):format(lnum))
    end
  end)
  return r
end

--- Close the folds again once Vim is idle: the keys a mapping still has
--- queued (the config's stay-put Esc jumps to the `^ mark, and
--- 'foldopen' has "mark") would reopen them if closed right away.
local function reclose_later(win, buf, r)
  api.nvim_create_autocmd("SafeState", {
    once = true,
    callback = function()
      if not (api.nvim_win_is_valid(win) and api.nvim_win_get_buf(win) == buf) then
        return
      end
      local delta = api.nvim_buf_line_count(buf) - r.lines
      local FR, folds = require("util.foldranges"), require("util.folds")
      api.nvim_win_call(win, function()
        for i = #r.folds, 1, -1 do
          local s, e = FR.fold(buf, win, r.folds[i][1] - 1, r.folds[i][2] + delta - 1)
          trace(("re-close: %d..%d -> %s..%s"):format(r.folds[i][1], r.folds[i][2] + delta, tostring(s), tostring(e)))
          if s then
            folds.close_exact(s, e)
          end
        end
      end)
      caret_at_cursor(win, buf)
    end,
  })
end

--- v on a closed fold: the folds hiding the cursor's line open (the
--- caret's character is where the selection starts) and visual mode
--- starts there, since a selection can't be drawn on a fold line. The
--- folds close again when visual mode ends (`viwy` is a blink).
function M.visual()
  local win, buf = api.nvim_get_current_win(), api.nvim_get_current_buf()
  reclose_visual[win] = reveal(win, buf)
  vim.cmd("normal! v")
end

--- Visual mode ended: back in normal mode the folds close again; into
--- insert mode (`c`) they close when that ends.
local function visual_ended()
  local win = api.nvim_get_current_win()
  local r = reclose_visual[win]
  if not r then
    return
  end
  local mode = api.nvim_get_mode().mode
  if mode:match("^i") then
    reclose_visual[win] = nil
    reclose[win] = r
  elseif mode:match("^n") then
    reclose_visual[win] = nil
    reclose_later(win, api.nvim_get_current_buf(), r)
  end
end

--- Entering insert mode on a closed fold: the folds at the cursor open
--- here, level by level, before Vim opens them all at once.
local function insert_enter()
  local win, buf = api.nvim_get_current_win(), api.nvim_get_current_buf()
  reclose[win] = reveal(win, buf) or reclose[win]
end

local function insert_leave()
  local win, buf = api.nvim_get_current_win(), api.nvim_get_current_buf()
  local r = reclose[win]
  reclose[win] = nil
  if r and r.buf == buf then
    reclose_later(win, buf, r)
  end
end

--- The caret for the cursor's position, when it's on a closed fold (after
--- ,d closed one around it).
function M.refresh()
  caret_at_cursor(api.nvim_get_current_win(), api.nvim_get_current_buf())
end

--- The caret's record for a window, for tests: nil, or where it was
--- placed and the changedtick then (validated by cell_at()).
function M.state(win)
  return states[win]
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
  api.nvim_create_autocmd("InsertEnter", { group = group, callback = insert_enter })
  api.nvim_create_autocmd("InsertLeave", { group = group, callback = insert_leave })
  api.nvim_create_autocmd("ModeChanged", { group = group, pattern = "[vV\x16]*:*", callback = visual_ended })
  api.nvim_create_autocmd({ "CursorMoved", "TextChanged", "InsertEnter", "WinLeave", "BufLeave", "ModeChanged" }, {
    group = group,
    callback = function(ev)
      if shown_as and not on_caret() then
        show_cursor()
      end
      if ev.event == "CursorMoved" then
        arrive()
      end
    end,
  })
end

return M
