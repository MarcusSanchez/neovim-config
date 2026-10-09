-- Folds persist across sessions, like IntelliJ — but only when they'd still
-- cover the same code. Each closed fold is saved with a fingerprint of the
-- text it hides; on reopen it's closed again only if that exact text is
-- still there, at the same lines or wherever it moved to. Edited or gone,
-- the fold stays open rather than hiding the wrong lines.
--
-- State lives in stdpath("state")/folds/, one JSON file per path.
local M = {}

local dir = vim.fn.stdpath("state") .. "/folds"

local function real_file(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  return vim.bo[buf].buftype == "" and name ~= "" and vim.fn.filereadable(name) == 1
end

--- A window whose fold state is the user's: not a float, not a snacks
--- picker preview (snacks loads the real file buffer into its preview, so
--- browsing past a file in a picker must never count as "no folds closed").
local function real_window(win)
  return vim.api.nvim_win_is_valid(win)
    and vim.api.nvim_win_get_config(win).relative == ""
    and vim.w[win].snacks_win == nil
    and vim.wo[win].foldenable
end

-- windows whose saved folds have been applied; a window still waiting on
-- fold structure must not write state (it would record "nothing closed")
local ready = {} ---@type table<integer, boolean>
-- windows still inside treesitter's settling period after a restore, with
-- the folds to keep re-applying until it ends
local settling = {} ---@type table<integer, { folds: util.folds.Fold[], until_ms: integer }>
-- the current restore cycle per window; a new BufWinEnter starts a new one
-- and the old cycle's timers see a different token and stop
local cycles = {} ---@type table<integer, table>

local function state_file(buf)
  return dir .. "/" .. vim.api.nvim_buf_get_name(buf):gsub("[/\\:]", "%%") .. ".json"
end

---@class util.folds.Fold
---@field start integer 1-based first line
---@field stop integer 1-based last line
---@field head string first line's text (for relocation)
---@field hash string sha256 of the folded lines

--- Closed folds in the window, outermost first.
---@return util.folds.Fold[]
local function closed_folds(win)
  local folds = {}
  vim.api.nvim_win_call(win, function()
    local last, line = vim.fn.line("$"), 1
    while line <= last do
      local start = vim.fn.foldclosed(line)
      if start ~= -1 then
        local stop = vim.fn.foldclosedend(line)
        local lines = vim.api.nvim_buf_get_lines(0, start - 1, stop, false)
        folds[#folds + 1] =
          { start = start, stop = stop, head = lines[1], hash = vim.fn.sha256(table.concat(lines, "\n")) }
        line = stop + 1
      else
        line = line + 1
      end
    end
  end)
  return folds
end

--- Where the fold's text now lives: its saved lines if unchanged, else the
--- first place the same text occurs, else nil.
---@param fold util.folds.Fold
---@return integer? start
local function locate(fold, lines)
  local span = fold.stop - fold.start
  local function matches(at)
    if at < 1 or at + span > #lines then
      return false
    end
    return vim.fn.sha256(table.concat(lines, "\n", at, at + span)) == fold.hash
  end
  if matches(fold.start) then
    return fold.start
  end
  for at, text in ipairs(lines) do
    if text == fold.head and matches(at) then
      return at
    end
  end
end

--- Close the fold spanning exactly start..stop; leave things open if the
--- fold structure there no longer matches.
local function close_exact(start, stop)
  local function closed()
    return vim.fn.foldclosed(start) == start and vim.fn.foldclosedend(start) == stop
  end
  if closed() then
    return true -- re-applying: foldclose on a closed fold would close its parent
  end
  for _ = 1, 20 do -- one nesting level per foldclose
    if vim.fn.foldlevel(start) == 0 then
      return false
    end
    vim.cmd(("silent! %dfoldclose"):format(start))
    if closed() then
      return true
    end
    local s, e = vim.fn.foldclosed(start), vim.fn.foldclosedend(start)
    if s ~= -1 and (s < start or e > stop) then
      vim.cmd(("silent! %d,%dfoldopen"):format(s, e)) -- overshot: undo it
      return false
    end
    if s == -1 then
      return false
    end
  end
  return false
end

--- Apply the saved folds that can be applied now. Returns the ones that
--- couldn't be because the window has no fold structure there yet.
---@param folds util.folds.Fold[]
---@return util.folds.Fold[] pending
local function apply(buf, win, folds)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local pending = {}
  vim.api.nvim_win_call(win, function()
    for _, fold in ipairs(folds) do
      local at = locate(fold, lines)
      if at then
        if vim.fn.foldlevel(at) == 0 then
          pending[#pending + 1] = fold
        else
          close_exact(at, at + fold.stop - fold.start)
        end
      end
    end
  end)
  return pending
end

function M.save(buf, win)
  win = win or vim.api.nvim_get_current_win()
  if not real_file(buf) or not real_window(win) or not ready[win] then
    return
  end
  -- leaving mid-settle: make sure a fold treesitter just reopened on us is
  -- back before reading the window's state
  local st = settling[win]
  if st and vim.uv.now() < st.until_ms then
    apply(buf, win, st.folds)
  end
  local folds = closed_folds(win)
  local file = state_file(buf)
  if #folds == 0 then
    vim.fn.delete(file)
    return
  end
  vim.fn.mkdir(dir, "p")
  vim.fn.writefile({ vim.json.encode(folds) }, file)
end

function M.load(buf, win)
  win = win or vim.api.nvim_get_current_win()
  ready[win], settling[win] = nil, nil
  local token = {}
  cycles[win] = token
  if not real_file(buf) or not real_window(win) then
    return
  end
  local file = state_file(buf)
  local folds = {}
  if vim.fn.filereadable(file) == 1 then
    local ok, saved = pcall(vim.json.decode, table.concat(vim.fn.readfile(file), "\n"))
    folds = ok and type(saved) == "table" and saved or {}
  end
  -- treesitter fold levels arrive asynchronously after the buffer opens
  -- (indent folds are there at once), and its first passes can rebuild the
  -- window's folds and reopen whatever was just closed. So: retry until the
  -- fold structure exists where a saved fold goes, then keep re-applying for
  -- a settling period, and only then consider this window's state the
  -- user's own (saveable).
  local delay, deadline = 50, vim.uv.now() + 10000
  local function attempt()
    if cycles[win] ~= token or not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_buf(win) ~= buf then
      return
    end
    local pending = apply(buf, win, folds)
    local now = vim.uv.now()
    if #pending == 0 and not settling[win] then
      ready[win] = true
      settling[win] = { folds = folds, until_ms = now + 2500 }
    end
    if settling[win] then
      if now >= settling[win].until_ms then
        settling[win] = nil
        return
      end
      vim.defer_fn(attempt, 250)
    elseif now < deadline then
      vim.defer_fn(attempt, delay)
      delay = math.min(delay * 2, 500)
    else
      ready[win] = true -- fold structure never came; the user's state rules
    end
  end
  attempt()
end

function M.setup()
  local group = vim.api.nvim_create_augroup("remember_folds", { clear = true })
  vim.api.nvim_create_autocmd({ "BufWinLeave", "BufWritePost" }, {
    group = group,
    callback = function(ev)
      M.save(ev.buf, vim.fn.bufwinid(ev.buf))
    end,
  })
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    callback = function(ev)
      M.load(ev.buf)
    end,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(ev)
      local win = tonumber(ev.match)
      ready[win], settling[win], cycles[win] = nil, nil, nil
    end,
  })
end

return M
