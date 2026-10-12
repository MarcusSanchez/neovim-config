-- A search doesn't unfold what it passes through.
--
-- Vim's 'foldopen' includes "search", so every match a search lands on
-- opens its fold for good; a few `n` presses leave the file unfolded.
-- Here a search motion that lands inside a closed fold opens that fold
-- only while the cursor is in it: step out and it closes again, unless
-- the text inside was edited meanwhile. Folds the search merely passed
-- over never open at all.
local M = {}

---@class util.searchfolds.Visit the folds a search motion opened in a window
---@field buf integer
---@field folds { start: integer, stop: integer }[] outermost first, as opened
---@field tick integer changedtick when they were opened

local visits = {} ---@type table<integer, util.searchfolds.Visit>

--- After a search motion: the closed folds the cursor landed in, if any,
--- open for the visit — one level at a time, so each is known and can be
--- put back exactly (opening all at once would leave inner folds open
--- behind a re-closed outer one).
local function reveal()
  local win = vim.api.nvim_get_current_win()
  local lnum = vim.api.nvim_win_get_cursor(win)[1]
  if vim.fn.foldclosed(lnum) == -1 then
    return
  end
  local v = { buf = vim.api.nvim_get_current_buf(), folds = {}, tick = vim.api.nvim_buf_get_changedtick(0) }
  for _ = 1, 20 do -- one nesting level per zo
    local start = vim.fn.foldclosed(lnum)
    if start == -1 then
      break
    end
    v.folds[#v.folds + 1] = { start = start, stop = vim.fn.foldclosedend(lnum) }
    vim.cmd("silent! normal! zo")
  end
  visits[win] = v
end

--- On every cursor move: a visited fold the cursor has left closes again,
--- innermost first, unless the text was edited meanwhile.
local function leave()
  local win = vim.api.nvim_get_current_win()
  local v = visits[win]
  if not v then
    return
  end
  local lnum = vim.api.nvim_win_get_cursor(win)[1]
  local outer = v.folds[1]
  if vim.api.nvim_get_current_buf() == v.buf and lnum >= outer.start and lnum <= outer.stop then
    return
  end
  visits[win] = nil
  if vim.api.nvim_get_current_buf() == v.buf and vim.api.nvim_buf_get_changedtick(0) == v.tick then
    local close = require("util.folds").close_exact
    for i = #v.folds, 1, -1 do
      close(v.folds[i].start, v.folds[i].stop)
    end
  end
end

--- The folds a search opened for the current visit in the window, if the
--- text is unchanged since: they count as closed (util/folds.lua saves
--- them that way).
---@return { start: integer, stop: integer }[]
function M.visiting(win)
  local v = visits[win]
  if not v or vim.api.nvim_win_get_buf(win) ~= v.buf or vim.api.nvim_buf_get_changedtick(v.buf) ~= v.tick then
    return {}
  end
  return v.folds
end

--- Run a search motion (`n`, `N`, `*`, `#`…) and reveal where it lands.
--- `n` and `N` follow the search direction like LazyVim's defaults.
function M.motion(key)
  if key == "n" or key == "N" then
    key = (vim.v.searchforward == 1) == (key == "n") and "n" or "N"
  end
  local ok, err = pcall(vim.cmd, ("normal! %d%s"):format(vim.v.count1, key))
  if not ok then
    vim.notify((tostring(err):gsub("^.-:E%d+: ", "")), vim.log.levels.WARN, { title = "Search" })
    return
  end
  leave() -- the fold the previous match was in, if this one left it
  reveal()
end

function M.setup()
  vim.opt.foldopen:remove("search")
  local group = vim.api.nvim_create_augroup("search_folds", { clear = true })
  vim.api.nvim_create_autocmd("CmdlineLeave", {
    group = group,
    pattern = { "/", "\\?" },
    callback = function()
      if not vim.v.event.abort then
        vim.schedule(reveal) -- the jump happens after this event
      end
    end,
  })
  vim.api.nvim_create_autocmd("CursorMoved", { group = group, callback = leave })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(ev)
      visits[tonumber(ev.match)] = nil
    end,
  })
end

return M
