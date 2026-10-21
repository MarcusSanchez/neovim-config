-- Flash on a closed fold. The caret (util/foldcursor.lua) has the fold
-- line stand in for the fold; here flash's matches on one are the drawn
-- line's too: a match in the hidden text is no match, one on a drawn
-- character is labelled on the fold line where that character is, and a
-- jump to it puts the caret there with the fold still closed. (Flash by
-- itself labels one match per fold at its first column and opens the
-- whole fold on the jump.) Covers `s` and the f/F/t/T/;/, motions flash
-- owns, and any other mode on flash's default matcher.
local M = {}
local api = vim.api

local foldtext = require("util.foldtext")

---@class util.flashfolds.Drawn a closed fold as flash sees it
---@field start integer
---@field stop integer
---@field cells util.foldtext.Cell[]

--- The closed fold at a buffer line of the window, as drawn; nil when the
--- line is visible.
---@return util.flashfolds.Drawn?
local function fold_at(win, buf, lnum)
  local start, stop
  api.nvim_win_call(win, function()
    start = vim.fn.foldclosed(lnum)
    stop = vim.fn.foldclosedend(lnum)
  end)
  if start == -1 then
    return
  end
  return { start = start, stop = stop, cells = foldtext.cells(foldtext.build(buf, start, stop)) }
end

--- The cell standing for buffer position (lnum, col), if one is drawn.
---@param cells util.foldtext.Cell[]
---@return integer?
local function cell_for(cells, lnum, col)
  for i, c in ipairs(cells) do
    if c.lnum == lnum and c.col == col then
      return i
    end
  end
end

--- Flash's default matcher with every closed fold seen as its drawn line:
--- a match on a drawn character keeps its cell (`cell`) and the fold it's
--- drawn for (`drawn`); one in the hidden text is dropped.
---@param win integer
---@param state Flash.State
---@param opts? {from?: Pos, to?: Pos}
---@return Flash.Match[]
function M.matcher(win, state, opts)
  local search = require("flash.search").new(win, state)
  local buf = api.nvim_win_get_buf(win)
  local folds = {} ---@type table<integer, util.flashfolds.Drawn|false> by first line
  local out = {}
  for _, m in ipairs(search:get(opts)) do
    local lnum = m.pos[1]
    local start = api.nvim_win_call(win, function()
      return vim.fn.foldclosed(lnum)
    end)
    if start == -1 then
      out[#out + 1] = m
    else
      if folds[start] == nil then
        folds[start] = fold_at(win, buf, lnum) or false
      end
      local f = folds[start]
      local cell = f and cell_for(f.cells, lnum, m.pos[2])
      if cell then
        m.cell, m.drawn = cell, f
        out[#out + 1] = m
      end
    end
  end
  return out
end

--- Flash's default labeler, with every match on a drawn character getting
--- a label of its own (flash labels one match per closed fold).
---@param matches Flash.Match[]
---@param state Flash.State
function M.labeler(matches, state)
  for _, m in ipairs(matches) do
    if m.cell then
      m.fold = nil
    end
  end
  state._fold_labeler = state._fold_labeler or require("flash.labeler").new(state):labeler()
  state._fold_labeler(matches, state)
end

--- Flash's label text (`label.format`): none for a match on a drawn
--- character — its label is drawn into the fold line instead, where an
--- extmark can't put it.
---@param opts Flash.Format
function M.format(opts)
  if opts.match.cell then
    return {}
  end
  return { { opts.match.label, opts.hl_group } }
end

-- the labels on fold lines ---------------------------------------------------------

--- window -> fold start -> cell -> { text, highlight }
local labels = {} ---@type table<integer, table<integer, table<integer, string[]>>>
--- the fold lines carrying labels, to redraw when they go
local carrying = {} ---@type { win: integer, start: integer, stop: integer }[]

local function redraw(win, start, stop)
  if api.nvim_win_is_valid(win) then
    pcall(api.nvim__redraw, { win = win, range = { start - 1, stop }, valid = false })
  end
end

--- The labels flash gave the matches on drawn characters, onto their fold
--- lines: where flash puts them — after the match (`label.after`, the
--- cell past its last one) or before it — but in cells.
---@param state Flash.State
function M.publish(state)
  M.unpublish()
  local groups = state.opts.highlight.groups
  local after = state.opts.label.after
  after = after == true and { 0, 1 } or after
  local before = state.opts.label.before
  before = before == true and { 0, -1 } or before
  local target = state.target
  for _, m in ipairs(state.results) do
    if m.cell and m.label and m.label ~= "" then
      local hl = groups.label
      if target and target.pos == m.pos and target.pos == target.end_pos then
        hl = groups.current
      end
      local function put(cell)
        cell = math.max(1, math.min(cell, #m.drawn.cells + 1))
        labels[m.win] = labels[m.win] or {}
        local per = labels[m.win][m.drawn.start] or {}
        labels[m.win][m.drawn.start] = per
        per[cell] = { m.label, hl }
      end
      if after then
        put((cell_for(m.drawn.cells, m.end_pos[1], m.end_pos[2]) or m.cell) + after[2])
      end
      if before then
        put(m.cell + before[2])
      end
      carrying[#carrying + 1] = { win = m.win, start = m.drawn.start, stop = m.drawn.stop }
      redraw(m.win, m.drawn.start, m.drawn.stop)
    end
  end
end

function M.unpublish()
  labels = {}
  for _, c in ipairs(carrying) do
    redraw(c.win, c.start, c.stop)
  end
  carrying = {}
end

--- The labels on a fold line, for util/foldtext.lua.
---@return table<integer, string[]>?
function M.labels(win, _, start)
  local w = labels[win]
  return w and w[start]
end

-- the jump -----------------------------------------------------------------------

--- Flash's jump, to a match on a drawn character: the caret there, the
--- fold kept closed. Any other jump — into hidden text, in visual or
--- operator-pending mode, with a range or offset — is flash's own.
local function jump(orig, match, state, opts)
  if api.nvim_get_mode().mode ~= "n" or state.opts.jump.pos ~= "start" or state.opts.jump.offset then
    return orig(match, state, opts)
  end
  local f = fold_at(match.win, api.nvim_win_get_buf(match.win), match.pos[1])
  if not (f and cell_for(f.cells, match.pos[1], match.pos[2])) then
    return orig(match, state, opts)
  end
  require("util.foldcursor").jump(match.win, match.pos[1], match.pos[2])
end

local installed = false

--- Hook into flash: labels onto fold lines after it draws (and off when
--- it clears), the jump through the caret. The matcher, labeler and
--- label format are set through flash's options (plugins/flash.lua).
function M.setup()
  if installed then
    return
  end
  installed = true
  foldtext.labels = M.labels
  local Highlight, Jump = require("flash.highlight"), require("flash.jump")
  local update, clear, _jump = Highlight.update, Highlight.clear, Jump._jump
  Highlight.update = function(state)
    update(state)
    M.publish(state)
  end
  Highlight.clear = function(ns)
    clear(ns)
    M.unpublish()
  end
  Jump._jump = function(match, state, opts)
    return jump(_jump, match, state, opts)
  end
end

return M
