-- Multiple cursors on Neovim's own (|multicursor|, 0.13+), driven the way
-- the multicursor.nvim plugin was: Alt-Shift-l/n leave a cursor behind and
-- move on to the next/previous match of the word under the cursor (or of
-- the Visual selection, which then stays selected at each cursor through
-- `gn`), s/b skip a match, h lets the last one go; Ctrl-j/k leave a cursor
-- and step to the line above/below. The cursors are Vim's: extmarks in the
-- "nvim.multicursor" namespace that replay the primary cursor's edits, so
-- its own keys — Q, q= follow mode, [C ]C, CTRL-L, gQ, g CTRL-A — compose
-- with these. Placing one here is a plain "1Q"; 'follow' mode goes on
-- after, so the cursors move together, as the plugin's did.
local M = {}
local api = vim.api

local function ns()
  return api.nvim_create_namespace("nvim.multicursor")
end

--- The cursors standing in a buffer, in buffer order: { id, row, col }
--- (0-based), the primary cursor not among them.
function M.cursors(buf)
  return api.nvim_buf_get_extmarks(buf or 0, ns(), 0, -1, {})
end

function M.active(buf)
  return #api.nvim_buf_get_extmarks(buf or 0, ns(), 0, -1, { limit = 1 }) > 0
end

--- The cursor at a (1-based line, 0-based column) position, if one stands there.
---@return integer? extmark id
local function cursor_at(buf, lnum, col)
  local at = api.nvim_buf_get_extmarks(buf, ns(), { lnum - 1, col }, { lnum - 1, col }, {})
  return at[1] and at[1][1]
end

---@class util.multicursor.Placed a cursor these keys left behind, newest last
---@field buf integer
---@field id integer extmark id
local placed = {} ---@type util.multicursor.Placed[]

local function in_visual()
  return api.nvim_get_mode().mode:match("^[vV\22]") ~= nil
end

--- Leave Visual mode with the cursor at the selection's start: where the
--- match being gathered begins.
local function to_selection_start()
  local v, cur = vim.fn.getpos("v"), vim.fn.getpos(".")
  local first = (v[2] < cur[2] or (v[2] == cur[2] and v[3] <= cur[3])) and v or cur
  vim.cmd("normal! \27")
  api.nvim_win_set_cursor(0, { first[2], first[3] - 1 })
end

--- Select the match at the cursor again (the primary's `gn`, fed after the
--- mapping so Visual mode stays — and replays at every cursor, selecting
--- each one's own match when an edit follows).
local function reselect()
  api.nvim_feedkeys("gn", "n", false)
end

--- What is being gathered: in Visual mode the selection, exactly; else the
--- word under the cursor, whole. It becomes the search pattern too, so
--- 'hlsearch' shows the matches left and `gn` selects them.
---@return string? pattern, boolean visual
local function pattern()
  local mode = api.nvim_get_mode().mode
  if mode:match("^[vV\22]") then
    local text = table.concat(vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode }), "\n")
    if text == "" then
      return nil, true
    end
    return "\\V" .. vim.fn.escape(text, "\\"):gsub("\n", "\\n"), true
  end
  local word = vim.fn.expand("<cword>")
  if word == "" then
    return nil, false
  end
  return ("\\V\\<%s\\>"):format(vim.fn.escape(word, "\\")), false
end

--- In Normal mode the primary onto the start of the match it's on (or the
--- next one on its line): the cursor placed stands at the match, as the
--- others will, and a backward search doesn't find this same word.
local function to_match_start(pat)
  local cur = api.nvim_win_get_cursor(0)
  local line, at = api.nvim_buf_get_lines(0, cur[1] - 1, cur[1], false)[1], 0
  for _ = 1, #line do
    local _, s, e = unpack(vim.fn.matchstrpos(line, pat, at))
    if s == -1 then
      return
    end
    if cur[2] < e then
      api.nvim_win_set_cursor(0, { cur[1], s })
      return
    end
    at = e
  end
end

--- The cursors move with the primary — but not while these functions
--- move it about: in 'follow' mode the primary landing on a cursor trades
--- places with it (as `]C` does), which would scramble the set as a
--- search passes over them. So off first, on again once done.
local function unfollow()
  vim.bo.follow = false
end
local function follow()
  vim.bo.follow = true
end

--- A cursor at the primary's position (Vim's "1Q"), remembered for `undo`.
local function place(buf)
  local cur = api.nvim_win_get_cursor(0)
  if cursor_at(buf, cur[1], cur[2]) then
    return
  end
  vim.cmd("normal! 1Q")
  local id = cursor_at(buf, cur[1], cur[2])
  if id then
    placed[#placed + 1] = { buf = buf, id = id }
  end
end

--- The primary onto the next (dir 1) or previous (-1) match without a
--- cursor on it, wrapping; false, and no move, when every match has one.
local function to_match(buf, pat, dir)
  local from = api.nvim_win_get_cursor(0)
  local first ---@type integer[]? the first match seen: back there, the matches are exhausted
  for _ = 1, 100000 do
    local pos = vim.fn.searchpos(pat, dir > 0 and "w" or "bw")
    if pos[1] == 0 or (first and pos[1] == first[1] and pos[2] == first[2]) then
      break
    end
    first = first or pos
    if not cursor_at(buf, pos[1], pos[2] - 1) and not (pos[1] == from[1] and pos[2] - 1 == from[2]) then
      return true
    end
  end
  api.nvim_win_set_cursor(0, from)
  return false
end

--- Leave a cursor here and move on to the next (dir 1) / previous (-1)
--- match of the word under the cursor or the selection.
function M.add(dir)
  local pat, visual = pattern()
  if not pat then
    return
  end
  local buf = api.nvim_get_current_buf()
  unfollow()
  if visual then
    to_selection_start()
  else
    to_match_start(pat)
  end
  vim.fn.setreg("/", pat)
  vim.v.hlsearch = 1
  place(buf)
  to_match(buf, pat, dir)
  follow()
  if visual then
    reselect()
  end
end

--- Move on to the next / previous match without leaving a cursor here.
function M.skip(dir)
  local pat, visual = pattern()
  if not pat then
    return
  end
  local buf = api.nvim_get_current_buf()
  unfollow()
  if visual then
    to_selection_start()
  else
    to_match_start(pat)
  end
  vim.fn.setreg("/", pat)
  vim.v.hlsearch = 1
  to_match(buf, pat, dir)
  follow()
  if visual then
    reselect()
  end
end

--- Let the last cursor go: the primary goes back to it and it is removed.
--- Cursors placed otherwise (Q, zq) come off newest-in-buffer-order first.
function M.undo()
  local buf = api.nvim_get_current_buf()
  local visual = in_visual()
  unfollow()
  local target ---@type integer[]? 0-based position
  while #placed > 0 do
    local last = table.remove(placed)
    if last.buf == buf then
      local pos = api.nvim_buf_get_extmark_by_id(buf, ns(), last.id, {})
      if pos[1] then
        api.nvim_buf_del_extmark(buf, ns(), last.id)
        target = pos
        break
      end
    end
  end
  if not target then
    local all = M.cursors(buf)
    local last = all[#all]
    if not last then
      return
    end
    api.nvim_buf_del_extmark(buf, ns(), last[1])
    target = { last[2], last[3] }
  end
  if visual then
    vim.cmd("normal! \27")
  end
  api.nvim_win_set_cursor(0, { target[1] + 1, target[2] })
  follow()
  if visual then
    reselect()
  end
end

--- Leave a cursor here and step to the line above (dir -1) or below (1),
--- [count] times; with `skip`, just step.
function M.line(dir, skip)
  local buf = api.nvim_get_current_buf()
  unfollow()
  if in_visual() then
    vim.cmd("normal! \27")
  end
  for _ = 1, vim.v.count1 do
    if not skip then
      place(buf)
    end
    vim.cmd("normal! " .. (dir < 0 and "k" or "j"))
  end
  follow()
end

--- Run `move` (a motion of the config's own, in Lua — which Neovim can't
--- replay at the other cursors, only resolved keys cascade) at every
--- cursor, each moving to where it lands, then at the primary. Cursors
--- landing on the same spot merge.
function M.each(move)
  local buf = api.nvim_get_current_buf()
  unfollow()
  local primary = api.nvim_win_get_cursor(0)
  local view = vim.fn.winsaveview()
  local taken = {} ---@type table<string, boolean>
  for _, m in ipairs(M.cursors(buf)) do
    api.nvim_win_set_cursor(0, { m[2] + 1, m[3] })
    move()
    local c = api.nvim_win_get_cursor(0)
    local key = c[1] .. ":" .. c[2]
    if taken[key] then
      api.nvim_buf_del_extmark(buf, ns(), m[1])
    else
      taken[key] = true
      api.nvim_buf_set_extmark(buf, ns(), c[1] - 1, c[2], { id = m[1] })
    end
  end
  api.nvim_win_set_cursor(0, primary)
  vim.fn.winrestview(view)
  move()
  local c = api.nvim_win_get_cursor(0)
  local onto = cursor_at(buf, c[1], c[2])
  if onto then
    api.nvim_buf_del_extmark(buf, ns(), onto) -- the primary is that cursor now
  end
  follow()
end

--- No cursors in the buffer (Vim's CTRL-L does the same).
function M.clear(buf)
  buf = buf or api.nvim_get_current_buf()
  api.nvim_buf_clear_namespace(buf, ns(), 0, -1)
  placed = vim.tbl_filter(function(p)
    return p.buf ~= buf
  end, placed)
end

return M
