-- One fold expression for every buffer, IntelliJ-shaped.
--
-- Folds come from the language server's folding ranges once it has
-- answered (rust-analyzer, gopls, vtsls… know every bracket region: a
-- struct literal inside a closure, a wrapped argument list, an if/else
-- chain), from treesitter's fold queries until then or where no server
-- folds, and from indentation in files with no parser.
--
-- Server ranges are normalised first. Servers follow VS Code's convention
-- and stop a range one line short so the closing bracket stays visible
-- (`}`, `});`, `}, log)` …); IntelliJ, and the fold line
-- `func main() { ... }`, want the closer inside the fold. So a range still
-- missing a closer grows onto the next line when that line starts with one.
-- Where that line also starts another range, one of them has to give (a
-- line belongs to one fold): after `) -> R {` the parameters keep their
-- closer and the body folds with the whole function; after `} else {` the
-- block stays short and the else branch is its own fold.
local M = {}

local api = vim.api

---@class util.foldranges.State
---@field levels table<integer, { [1]: integer, [2]: string? }>? row -> level, ">"/"<"

local states = {} ---@type table<integer, util.foldranges.State>

-- normalisation ---------------------------------------------------------------

--- The line without string literals and line comments, so brackets inside
--- them don't count.
local function code(text)
  text = text:gsub('"[^"]*"', '""'):gsub("`[^`]*`", "``"):gsub("'.'", "''")
  return (text:gsub("//.*$", ""))
end

--- The closing bracket a line starts with, if any.
local function leading_closer(text)
  return text:match("^%s*([%)%]}])")
end

--- Openers minus closers over the range's lines (0-based rows), ignoring
--- closers before the first opener on the first line (`} else {`,
--- `}).catch(() => {`): positive means the range hasn't closed yet.
local function balance(lines, first, last)
  local net = 0
  for row = first, last do
    local text = code(lines[row + 1] or "")
    if row == first then
      text = text:gsub("^[^%(%[{]*", function(pre)
        return (pre:gsub("[%)%]}]", ""))
      end)
    end
    for ch in text:gmatch("[%(%[{%)%]}]") do
      net = net + ((ch == "(" or ch == "[" or ch == "{") and 1 or -1)
    end
  end
  return net
end

--- Server folding ranges, normalised so a closed fold hides its closer.
---@param ranges lsp.FoldingRange[]
---@param lines string[] the buffer's lines
---@return lsp.FoldingRange[]
function M.normalize(ranges, lines)
  local list = {}
  for _, r in ipairs(ranges) do
    if r.endLine > r.startLine then
      list[#list + 1] = { s = r.startLine, e = r.endLine, kind = r.kind }
    end
  end
  -- later starts first, so a range is final before an earlier one looks at it
  table.sort(list, function(a, b)
    if a.s ~= b.s then
      return a.s > b.s
    end
    return a.e < b.e
  end)
  local starts = {} ---@type table<integer, table[]>
  for _, r in ipairs(list) do
    starts[r.s] = starts[r.s] or {}
    table.insert(starts[r.s], r)
  end
  local merged = {}
  for _, r in ipairs(list) do
    local n = r.e + 1
    local text = lines[n + 1]
    local closer = text and leading_closer(text)
    if closer and balance(lines, r.s, r.e) > 0 then
      local others = starts[n]
      if not others then
        r.e = n -- `}`, `});`, `}, log)`, `).bar()`: the closer joins the fold
      elseif closer ~= "}" then
        -- `) -> R {`: parameters keep their closer; the body that opens on
        -- that line folds with the whole function instead
        r.e = n
        for _, b in ipairs(others) do
          b.drop = true
          merged[#merged + 1] = { s = r.s, e = b.e }
        end
      end
      -- `} else {`: the block stays a line short, the else is its own fold
    end
  end
  local out, seen = {}, {}
  local function add(s, e, kind)
    local key = s .. ":" .. e
    if e > s and not seen[key] then
      seen[key] = true
      out[#out + 1] = { startLine = s, endLine = e, kind = kind }
    end
  end
  for _, r in ipairs(list) do
    if not r.drop then
      add(r.s, r.e, r.kind)
    end
  end
  for _, m in ipairs(merged) do
    add(m.s, m.e)
  end
  -- a line can start a fold or end another, not both: the ending one gives way
  local opens = {} ---@type table<integer, true>
  for _, r in ipairs(out) do
    opens[r.startLine] = true
  end
  local final = {}
  for _, r in ipairs(out) do
    if opens[r.endLine] and r.endLine ~= r.startLine then
      r.endLine = r.endLine - 1
    end
    if r.endLine > r.startLine then
      final[#final + 1] = r
    end
  end
  table.sort(final, function(a, b)
    if a.startLine ~= b.startLine then
      return a.startLine < b.startLine
    end
    return a.endLine > b.endLine
  end)
  return final
end

--- Fold levels per row from normalised ranges, in 'foldexpr' terms.
local function levels_of(ranges)
  local levels = {}
  for _, r in ipairs(ranges) do
    for row = r.startLine, r.endLine do
      local l = levels[row] or { 0 }
      l[1] = l[1] + 1
      levels[row] = l
    end
  end
  for _, r in ipairs(ranges) do
    levels[r.endLine][2] = "<"
  end
  for _, r in ipairs(ranges) do
    levels[r.startLine][2] = ">"
  end
  return levels
end

-- the fold expression -----------------------------------------------------------

local function indent_level(lnum)
  if vim.fn.getline(lnum):match("^%s*$") then
    return "-1"
  end
  return tostring(math.floor(vim.fn.indent(lnum) / vim.fn.shiftwidth()))
end

--- 'foldexpr': server levels, else treesitter's, else indentation.
function M.foldexpr(lnum)
  lnum = lnum or vim.v.lnum
  local st = states[api.nvim_get_current_buf()]
  if st and st.levels then
    local l = st.levels[lnum - 1]
    return l and ((l[2] or "") .. l[1]) or "0"
  end
  if LazyVim.treesitter.have(nil, "folds") then
    return vim.treesitter.foldexpr(lnum)
  end
  return indent_level(lnum)
end

--- Whether the buffer's folds come from its language server.
function M.has(buf)
  if not buf or buf == 0 then
    buf = api.nvim_get_current_buf()
  end
  local st = states[buf]
  return st ~= nil and st.levels ~= nil
end

-- keeping the levels current ------------------------------------------------------

local function foldupdate(buf)
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    if vim.wo[win].foldmethod == "expr" and api.nvim_win_get_tabpage(win) == api.nvim_get_current_tabpage() then
      pcall(vim._foldupdate, win, 0, api.nvim_buf_line_count(buf))
    end
  end
end

local update_pending = {} ---@type table<integer, true?>

--- Re-evaluate the folds now, or after insert mode ends (folds can't be
--- rebuilt while typing).
local function update(buf)
  if api.nvim_get_mode().mode:match("^i") then
    if not update_pending[buf] then
      update_pending[buf] = true
      api.nvim_create_autocmd("InsertLeave", {
        buffer = buf,
        once = true,
        callback = function()
          update_pending[buf] = nil
          if states[buf] then
            foldupdate(buf)
          end
        end,
      })
    end
    return
  end
  foldupdate(buf)
end

--- Shift the levels for lines inserted or deleted since the last answer,
--- so folds don't jump while the next one is on its way.
local function shift(levels, start_row, old_rows, new_rows)
  local delta = new_rows - old_rows
  if delta == 0 then
    return levels
  end
  local out = {}
  for row, l in pairs(levels) do
    if row < start_row then
      out[row] = l
    elseif delta > 0 or row >= start_row - delta then
      out[row + delta] = l
    end
  end
  if delta > 0 then
    local prev = out[start_row - 1]
    -- new lines take "undefined" (-1), unless they follow a fold's last
    -- line, where -1 would be read as a new fold start
    local fill = prev and prev[2] == "<" and { prev[1] - 1 } or { -1 }
    for row = start_row, start_row + delta - 1 do
      out[row] = fill
    end
  end
  return out
end

local function request(buf)
  local st = states[buf]
  if not st or not api.nvim_buf_is_loaded(buf) then
    return
  end
  local tick = api.nvim_buf_get_changedtick(buf)
  local params = { textDocument = vim.lsp.util.make_text_document_params(buf) }
  vim.lsp.buf_request_all(buf, "textDocument/foldingRange", params, function(results)
    if states[buf] ~= st or not api.nvim_buf_is_valid(buf) then
      return
    end
    if api.nvim_buf_get_changedtick(buf) ~= tick then
      return -- edited since: the change's own request answers for it
    end
    local ranges = {}
    for _, res in pairs(results) do
      if res.result then
        vim.list_extend(ranges, res.result)
      end
    end
    local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
    local first = st.levels == nil
    local folds = require("util.folds")
    -- the first answer replaces treesitter's folds with the server's: keep
    -- what's closed across the rebuild, then apply saved folds that had no
    -- matching fold until now
    local closed = first and folds.snapshot(buf) or nil
    st.levels = levels_of(M.normalize(ranges, lines))
    update(buf)
    if first then
      folds.restore(buf, closed)
      folds.rebuilt(buf)
    end
  end)
end

local function supports(client, buf)
  return client:supports_method("textDocument/foldingRange", buf)
end

function M.setup()
  local group = api.nvim_create_augroup("fold_ranges", { clear = true })
  api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(ev)
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if not client or not supports(client, ev.buf) or vim.bo[ev.buf].buftype ~= "" then
        return
      end
      if not states[ev.buf] then
        local st = {}
        states[ev.buf] = st
        api.nvim_buf_attach(ev.buf, false, {
          on_bytes = function(_, _, _, start_row, _, _, old_row, _, _, new_row)
            if states[ev.buf] ~= st then
              return true
            end
            if st.levels then
              st.levels = shift(st.levels, start_row, old_row, new_row)
            end
          end,
          on_reload = function()
            if states[ev.buf] == st then
              st.levels = nil
            end
          end,
          on_detach = function()
            if states[ev.buf] == st then
              states[ev.buf] = nil
            end
          end,
        })
      end
      request(ev.buf)
    end,
  })
  api.nvim_create_autocmd("LspNotify", {
    group = group,
    callback = function(ev)
      local m = ev.data.method
      if (m == "textDocument/didChange" or m == "textDocument/didOpen") and states[ev.buf] then
        local client = vim.lsp.get_client_by_id(ev.data.client_id)
        if client and supports(client, ev.buf) then
          request(ev.buf)
        end
      end
    end,
  })
  api.nvim_create_autocmd("LspDetach", {
    group = group,
    callback = function(ev)
      if not states[ev.buf] then
        return
      end
      for _, c in ipairs(vim.lsp.get_clients({ bufnr = ev.buf })) do
        if c.id ~= ev.data.client_id and supports(c, ev.buf) then
          return
        end
      end
      states[ev.buf] = nil -- back to treesitter's folds
      vim.schedule(function()
        if api.nvim_buf_is_valid(ev.buf) then
          foldupdate(ev.buf)
        end
      end)
    end,
  })
end

return M
