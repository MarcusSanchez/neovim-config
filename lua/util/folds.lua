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

function M.save(buf, win)
  if not real_file(buf) then
    return
  end
  local folds = closed_folds(win or 0)
  local file = state_file(buf)
  if #folds == 0 then
    vim.fn.delete(file)
    return
  end
  vim.fn.mkdir(dir, "p")
  vim.fn.writefile({ vim.json.encode(folds) }, file)
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

function M.load(buf, win)
  if not real_file(buf) then
    return
  end
  local file = state_file(buf)
  if vim.fn.filereadable(file) ~= 1 then
    return
  end
  local ok, folds = pcall(vim.json.decode, table.concat(vim.fn.readfile(file), "\n"))
  if not ok or type(folds) ~= "table" then
    return
  end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  vim.api.nvim_win_call(win or 0, function()
    for _, fold in ipairs(folds) do
      local at = locate(fold, lines)
      if at then
        close_exact(at, at + fold.stop - fold.start)
      end
    end
  end)
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
end

return M
