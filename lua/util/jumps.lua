-- Jumps glide: a half-page scroll, `gg`, `G` run as usual, then the view
-- eases from where it was to where the jump landed, over a few frames.
-- Only these jumps animate — `j`/`k` and everything else move as Vim
-- does — and a key typed mid-glide lands the view at once, so holding a
-- key never queues animations. The frames fire no CursorMoved or
-- WinScrolled; the final view does, like the plain jump would.
local M = {}
local api, uv = vim.api, vim.uv

local DURATION, STEP = 160, 15 -- ms: the glide, and the time between frames

---@class util.jumps.Glide
---@field win integer
---@field from vim.fn.winsaveview.ret
---@field to vim.fn.winsaveview.ret
---@field timer uv.uv_timer_t
---@field started integer uv.now at the first frame

local glide ---@type util.jumps.Glide?
M.frames = 0 -- frames drawn, for tests

local function ease(t) -- ease-out cubic: fast first, settling at the end
  return 1 - (1 - t) ^ 3
end

--- The glide's final view, now; nothing more to draw.
local function land()
  local g = glide
  if not g then
    return
  end
  glide = nil
  g.timer:stop()
  g.timer:close()
  if api.nvim_win_is_valid(g.win) then
    api.nvim_win_call(g.win, function()
      vim.fn.winrestview(g.to)
    end)
  end
end

--- One frame: the view part of the way from `from` to `to`, the cursor
--- kept inside it (clear of 'scrolloff', so Vim doesn't shift the view
--- back), with no events for the intermediate state.
local function frame()
  local g = glide
  if not g or not api.nvim_win_is_valid(g.win) then
    return land()
  end
  -- a key typed mid-glide: land now, so what it does starts from there
  if vim.fn.getchar(1) ~= 0 then
    return land()
  end
  local t = math.min(1, (uv.now() - g.started) / DURATION)
  if t >= 1 then
    return land()
  end
  local topline = math.floor(g.from.topline + (g.to.topline - g.from.topline) * ease(t) + 0.5)
  local so = vim.wo[g.win].scrolloff >= 0 and vim.wo[g.win].scrolloff or vim.o.scrolloff
  local rows = api.nvim_win_get_height(g.win)
  local lnum = math.max(topline + so, math.min(g.to.lnum, topline + rows - 1 - so))
  M.frames = M.frames + 1
  local ignored = vim.o.eventignore
  vim.o.eventignore = ignored == "" and "CursorMoved,WinScrolled" or (ignored .. ",CursorMoved,WinScrolled")
  api.nvim_win_call(g.win, function()
    vim.fn.winrestview({ topline = topline, lnum = lnum, col = g.to.col, leftcol = g.to.leftcol })
  end)
  vim.o.eventignore = ignored
  vim.cmd("redraw")
end

--- Run a jump (`normal!` keys, the pending count kept) and glide the
--- view to where it lands; a jump that doesn't scroll just happens.
function M.animated(keys)
  land() -- a glide still running lands first: the new jump starts from its end
  local win = api.nvim_get_current_win()
  local from = vim.fn.winsaveview()
  local count = vim.v.count
  vim.cmd("normal! " .. (count > 0 and count or "") .. keys)
  local to = vim.fn.winsaveview()
  if to.topline == from.topline or vim.g.animate_jumps == false then
    return
  end
  -- back to the start for the first frame; the frames bring the view along
  vim.fn.winrestview(from)
  local timer = assert(uv.new_timer())
  glide = { win = win, from = from, to = to, timer = timer, started = uv.now() }
  timer:start(0, STEP, vim.schedule_wrap(frame))
end

--- Whether a glide is in flight, for tests.
function M.active()
  return glide ~= nil
end

return M
