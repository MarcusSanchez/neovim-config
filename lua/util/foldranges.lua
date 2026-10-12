-- One fold expression for every buffer, JetBrains-shaped.
--
-- Folds come from the language server's folding ranges once it has
-- answered (rust-analyzer, gopls, vtsls… know every bracket region: a
-- struct literal inside a closure, a wrapped argument list, an if/else
-- chain), from treesitter's fold queries until then or where no server
-- folds, and from indentation in files with no parser. For JSX, treesitter
-- supplements the server, which reports elements inconsistently.
--
-- Server ranges are normalised (M.normalize) in stages:
--  1. grow: servers follow VS Code's convention and stop a range one line
--     short so the closing bracket stays visible (`}`, `});`, `}, log)`,
--     `</div>`); the closer joins the fold. An opening tag's attribute
--     list grows into the tag itself (`<Hero` … `/>`).
--  2. chains: neighbours that share a line (if / else if / else,
--     parameters / body) also get one range covering all of them.
--  3. heads and bodies: a statement whose body starts lines later gets a
--     range for its wrapped head (`if self` … `{`); a range whose head is
--     its own range gets one for the body (`>` … `</a>`, `) -> R {` … `}`).
--
-- Neighbours then share lines (`) -> R {`, `} else {`, `>`), and Vim gives
-- a line to one fold. The owner is decided when a fold is made (M.fold,
-- behind ,d): fold the if branch and it reads `if x { ... } else {`; fold
-- the else branch instead and it reads `} else { ... }` with the if body
-- open. When the neighbour is already closed, the fold grows to the chain:
-- `if x { ... } else { ... }`, `fn f( ... ) -> R { ... }`.
--
-- Beyond that nothing closes a fold by itself: imports close when a file
-- opens (JetBrains does the same), util/folds.lua restores saved ones, and
-- a fold Vim creates closed after an edit — it does, whenever another
-- fold is closed — is opened again.
local M = {}

local api = vim.api

---@class util.foldranges.Range 0-based rows, closer included
---@field s integer
---@field e integer
---@field kind? string

---@class util.foldranges.State
---@field ranges util.foldranges.Range[]? the server's ranges, normalised; neighbours may share a line
---@field owners table<integer, "start"|"end"> who gets a shared row: the range starting or the one ending there
---@field levels table<integer, { [1]: integer, [2]: string? }>? row -> level and ">" where a fold starts, from the resolved ranges

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

--- The tag a line closes, if it starts with one: the name for `</div>`,
--- "" for a fragment's `</>` or a self-closing `/>`.
local function closing_tag(text)
  local name = text:match("^%s*</([%w%.%-_]*)>")
  if name then
    return name
  end
  if text:match("^%s*/>") then
    return ""
  end
end

--- The tag a line opens, if it starts with one (`<div`, `<Foo.Bar`, `<`).
local function opening_tag(text)
  return text:match("^%s*<([%w%.%-_]*)")
end

--- A line that only ends an opening tag whose attributes wrapped: `>` or
--- `/>` (with whatever follows).
local function tag_end(text)
  return text:match("^%s*/?>") ~= nil
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

local function by_start(a, b)
  if a.s ~= b.s then
    return a.s < b.s
  end
  return a.e > b.e
end

--- Ranges indexed by one of their rows ("s" or "e").
local function index_by(list, field)
  local by = {} ---@type table<integer, util.foldranges.Range[]>
  for _, r in ipairs(list) do
    by[r[field]] = by[r[field]] or {}
    table.insert(by[r[field]], r)
  end
  return by
end

--- Stage 1: a range that stops short of its closer grows onto the closer's
--- line; the attribute list of a wrapped opening tag grows into the tag.
local function grow(list, lines)
  for _, r in ipairs(list) do
    local n = r.e + 1
    local text = lines[n + 1] -- nil past the last line: nothing to grow onto
    local head = lines[r.s + 1] or ""
    local grows = false
    if text and leading_closer(text) and balance(lines, r.s, r.e) > 0 then
      grows = true -- `}`, `});`, `}, log)`, `).bar()`: the closer joins the fold
    elseif text and r.kind == "comment" and text:match("^%s*%*/") and head:match("^%s*/%*") then
      grows = true -- clangd stops a block comment short of its ` */`
    elseif text and closing_tag(text) then
      -- `</div>` after an element that opened on the range's first line,
      -- `/>` after a self-closing one, `</>` after a fragment
      local closed = closing_tag(text)
      grows = opening_tag(head) ~= nil and (closed == "" or closed == opening_tag(head))
    end
    if text and tag_end(text) and not opening_tag(head) and r.s > 0 then
      -- `<Hero` / attrs / `/>`: the server folds the attributes alone; fold
      -- the tag instead, from `<Hero` through its `/>` or `>`
      local above = lines[r.s] or ""
      if opening_tag(above) and not above:find(">", 1, true) then
        r.s = r.s - 1
        grows = true
      end
    end
    if grows then
      r.e = n
    end
  end
end

--- Stage 3: one range per chain of neighbours sharing a line.
local function chains(list)
  local starts = index_by(list, "s")
  local function chain_end(r, seen)
    local e = r.e
    for _, b in ipairs(starts[r.e] or {}) do
      if b ~= r and b.s ~= r.s and not seen[b] then
        seen[b] = true
        e = math.max(e, chain_end(b, seen))
      end
    end
    return e
  end
  local out = {}
  for _, r in ipairs(list) do
    local e = chain_end(r, { [r] = true })
    if e > r.e then
      out[#out + 1] = { s = r.s, e = e }
    end
  end
  return out
end

--- Stage 2: the wrapped head of a statement whose body ends with it
--- (`if self` … `{`), and the body of a range whose head is its own range
--- from the same line (`>` … `</a>`), each through the line they share.
local function heads_and_bodies(list)
  local out = {}
  local ends, starts = index_by(list, "e"), index_by(list, "s")
  for _, r in ipairs(list) do
    for _, b in ipairs(ends[r.e]) do
      if b ~= r and b.s >= r.s + 2 then
        out[#out + 1] = { s = r.s, e = b.s }
      end
    end
    for _, t in ipairs(starts[r.s]) do
      if t ~= r and t.e < r.e and t.e > t.s then
        out[#out + 1] = { s = t.e, e = r.e }
      end
    end
  end
  return out
end

--- Server folding ranges, normalised (see the stages above): each runs
--- through its closer, chains and wrapped heads/bodies have ranges of
--- their own, neighbours may share a line. Sorted, no duplicates.
---@param ranges lsp.FoldingRange[]
---@param lines string[] the buffer's lines
---@return util.foldranges.Range[]
function M.normalize(ranges, lines)
  local list = {}
  for _, r in ipairs(ranges) do
    if r.endLine > r.startLine then
      list[#list + 1] = { s = r.startLine, e = r.endLine, kind = r.kind }
    end
  end
  grow(list, lines)
  -- heads and bodies before chains: derived from a chain, a "head" would
  -- be its first links (`if … } else if … {`), which overlaps the chain
  -- of its last links, and Vim can't hold overlapping folds
  vim.list_extend(list, heads_and_bodies(list))
  vim.list_extend(list, chains(list))
  local out, seen = {}, {}
  for _, r in ipairs(list) do
    local key = r.s .. ":" .. r.e
    if not seen[key] then
      seen[key] = true
      out[#out + 1] = { s = r.s, e = r.e, kind = r.kind }
    end
  end
  table.sort(out, by_start)
  return out
end

--- The ranges as folds Vim can hold: every shared row goes to the range
--- the owners table names (the one ending there unless told otherwise),
--- and the other one gives up that row.
---@param ranges util.foldranges.Range[]
---@param owners table<integer, "start"|"end">
---@return util.foldranges.Range[]
function M.resolve(ranges, owners)
  local ends, starts = {}, {}
  for _, r in ipairs(ranges) do
    ends[r.e] = true
    starts[r.s] = true
  end
  local out, seen = {}, {}
  for _, r in ipairs(ranges) do
    local s, e = r.s, r.e
    if starts[e] and owners[e] == "start" then
      e = e - 1 -- the range starting on our last row owns it
    end
    if ends[s] and owners[s] ~= "start" then
      s = s + 1 -- the range ending on our first row owns it
    end
    local key = s .. ":" .. e
    if e > s and not seen[key] then
      seen[key] = true
      out[#out + 1] = { s = s, e = e, kind = r.kind }
    end
  end
  return out
end

--- Fold levels per row, in 'foldexpr' terms: the level, ">" where a fold
--- starts, and "<" where one ends and Vim couldn't tell otherwise. Vim ends
--- an unmarked fold when the level drops, but a "<" line ends every deeper
--- fold still open there too, pulling it onto that line. So a fold's end
--- is marked when the next row is as deep or deeper (the parameters end,
--- the body and its first statement start) or is itself marked — and
--- otherwise left to the drop, since a "<" can only name one level and
--- would drag an unmarked outer fold along.
---@param ranges util.foldranges.Range[] resolved: no two share a row
function M.levels(ranges)
  local levels, ending, last = {}, {}, 0
  for _, r in ipairs(ranges) do
    for row = r.s, r.e do
      local l = levels[row] or { 0 }
      l[1] = l[1] + 1
      levels[row] = l
    end
    ending[r.e] = (ending[r.e] or 0) + 1
    last = math.max(last, r.e)
  end
  local next_marked = false
  for row = last, 0, -1 do
    local marked = false
    if ending[row] then
      -- a row ending several folds (`}` closing an else and its if/else
      -- chain) is marked at the shallowest of them: a "<" ends every
      -- deeper fold on the row too, and the row's level is that one's
      local level = levels[row][1] - ending[row] + 1
      local next_row = levels[row + 1]
      marked = next_marked or (next_row ~= nil and next_row[1] >= level)
      if marked then
        levels[row][1] = level
        levels[row][2] = "<"
      end
    end
    next_marked = marked
  end
  for _, r in ipairs(ranges) do
    levels[r.s][2] = ">"
  end
  return levels
end

local function relevel(st)
  st.levels = M.levels(M.resolve(st.ranges, st.owners))
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

--- The buffer's state, 0 meaning the current buffer.
local function state_of(buf)
  if not buf or buf == 0 then
    buf = api.nvim_get_current_buf()
  end
  return states[buf]
end

--- The buffer's normalised server ranges, 1-based `{ start, stop }` pairs
--- (for tests and :lua inspection); nil without server folds.
function M.ranges(buf)
  local st = state_of(buf)
  if not (st and st.ranges) then
    return nil
  end
  return vim.tbl_map(function(r)
    return { r.s + 1, r.e + 1 }
  end, st.ranges)
end

--- The server's fold kind ("imports", "comment", "region") for the fold
--- spanning exactly these 1-based lines, if it has one.
function M.kind(buf, start, stop)
  local st = state_of(buf)
  if not (st and st.ranges) then
    return nil
  end
  for _, r in ipairs(st.ranges) do
    if r.s == start - 1 and r.e == stop - 1 then
      return r.kind
    end
  end
end

--- Whether the buffer's folds come from its language server.
function M.has(buf)
  local st = state_of(buf)
  return st ~= nil and st.levels ~= nil
end

-- keeping the levels current ------------------------------------------------------

--- The closed folds in a window, as "start:stop" keys.
local function closed_set(win)
  local set = {}
  api.nvim_win_call(win, function()
    local line, last = 1, vim.fn.line("$")
    while line <= last do
      local s = vim.fn.foldclosed(line)
      if s ~= -1 then
        local e = vim.fn.foldclosedend(line)
        set[s .. ":" .. e] = true
        line = e + 1
      else
        line = line + 1
      end
    end
  end)
  return set
end

--- Re-evaluate the folds in every window showing the buffer. Only what was
--- closed before stays closed: Vim creates a fold that appears after an
--- edit *closed* whenever any other fold in the buffer is closed (a plain
--- Vim quirk — the auto-folded imports were enough), so anything newly
--- closed by the update is opened again.
local function foldupdate(buf)
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    if vim.wo[win].foldmethod == "expr" and api.nvim_win_get_tabpage(win) == api.nvim_get_current_tabpage() then
      local before = closed_set(win)
      pcall(vim._foldupdate, win, 0, api.nvim_buf_line_count(buf))
      api.nvim_win_call(win, function()
        for _ = 1, 10 do -- opening one may reveal another closed inside it
          local opened = false
          for key in pairs(closed_set(win)) do
            if not before[key] then
              vim.cmd(("silent! %sfoldopen"):format(key:match("^(%d+):")))
              opened = true
            end
          end
          if not opened then
            break
          end
        end
        -- and the reverse: a fold that was closed and still spans the same
        -- lines comes out of the rebuild closed (a rebuild right after
        -- insert mode re-created it open)
        local after = closed_set(win)
        for key in pairs(before) do
          if not after[key] then
            local s, e = key:match("^(%d+):(%d+)$")
            require("util.folds").close_exact(tonumber(s), tonumber(e))
          end
        end
      end)
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

--- Shift the state for lines inserted or deleted since the last answer,
--- so folds don't jump while the next one is on its way.
local function shift(st, start_row, old_rows, new_rows)
  local delta = new_rows - old_rows
  if delta == 0 or not st.levels then
    return
  end
  local function moved(row)
    if row < start_row then
      return row
    elseif delta > 0 or row >= start_row - delta then
      return row + delta
    end
  end
  local levels, owners = {}, {}
  for row, l in pairs(st.levels) do
    local to = moved(row)
    if to then
      levels[to] = l
    end
  end
  for row, who in pairs(st.owners) do
    local to = moved(row)
    if to then
      owners[to] = who
    end
  end
  for _, r in ipairs(st.ranges) do
    r.s, r.e = moved(r.s) or start_row, moved(r.e) or start_row
  end
  if delta > 0 then
    for row = start_row, start_row + delta - 1 do
      levels[row] = { -1 } -- undefined: the lower of the neighbours' levels
    end
  end
  st.levels, st.owners = levels, owners
end

-- fold kinds closed when a file opens, as JetBrains collapses imports
local autofold_kinds = { imports = true }

--- Close the auto-folded kinds in every window showing the buffer.
local function autofold(buf)
  local st = states[buf]
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    if api.nvim_win_get_config(win).relative == "" then
      api.nvim_win_call(win, function()
        for _, r in ipairs(st.ranges) do
          if r.kind and autofold_kinds[r.kind] then
            local s, e = M.fold(buf, win, r.s, r.e)
            if s then
              require("util.folds").close_exact(s, e)
            end
          end
        end
      end)
    end
  end
end

--- Regions treesitter knows that a server leaves out, as folding ranges,
--- per parser language. The typescript server reports JSX elements
--- inconsistently (a `<Hero … />` gets a range, the `<script … />` beside
--- it none); gleam's folds only top-level declarations, and a wrapped
--- signature from its `)` line; clangd has nothing for `#include` runs
--- and preprocessor conditionals. Treesitter's nodes already end on the
--- closer. A node sharing both lines with a server range is the same fold.
--- `runs` names a node whose consecutive siblings fold as one range of
--- the given kind (a run of `#include`s, like Go's import block).
---@type table<string, { nodes?: string, runs?: { query: string, kind: string } }>
local supplements = {}
-- elements, fragments (elements with an empty name), self-closing
-- elements, and opening tags that wrap (the attribute list on its own)
local jsx = { nodes = "[(jsx_element) (jsx_self_closing_element) (jsx_opening_element)] @e" }
supplements.tsx, supplements.javascript = jsx, jsx
-- every bracketed region: the function (so a wrapped signature folds as
-- parameters + body like Go's), blocks, case, literals, argument lists
supplements.gleam = {
  nodes = "[(function) (function_parameters) (block) (case) (anonymous_function)"
    .. " (arguments) (data_constructor_arguments) (record_update)"
    .. " (list) (tuple) (bit_array) (unqualified_imports)] @e",
}
-- preprocessor conditionals through their `#endif`; `#include` runs
local preproc = {
  nodes = "[(preproc_ifdef) (preproc_if)] @e",
  runs = { query = "(preproc_include) @e", kind = "imports" },
}
supplements.c, supplements.cpp = preproc, preproc

--- The rows each capture of the query spans, 0-based and sorted; a node
--- ending at column 0 ends on the row before.
local function captured_rows(buf, parser, lang, query_text)
  local ok, query = pcall(vim.treesitter.query.parse, lang, query_text)
  if not ok then
    return {}
  end
  local out = {}
  for _, tree in ipairs(parser:trees()) do
    for _, node in query:iter_captures(tree:root(), buf) do
      local s, _, e, ecol = node:range()
      if ecol == 0 then
        e = e - 1
      end
      out[#out + 1] = { s = s, e = e }
    end
  end
  table.sort(out, function(a, b)
    return a.s < b.s
  end)
  return out
end

local function treesitter_ranges(buf)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, nil, { error = false })
  if not ok or not parser then
    return {}
  end
  local lang = parser:lang()
  local spec = supplements[lang]
  if not spec then
    return {}
  end
  parser:parse(true)
  local out = {}
  if spec.nodes then
    for _, r in ipairs(captured_rows(buf, parser, lang, spec.nodes)) do
      if r.e > r.s then
        out[#out + 1] = { startLine = r.s, endLine = r.e }
      end
    end
  end
  if spec.runs then
    local runs, run = {}, nil
    for _, r in ipairs(captured_rows(buf, parser, lang, spec.runs.query)) do
      if run and r.s == run.e + 1 then
        run.e = r.e
      else
        run = { s = r.s, e = r.e }
        runs[#runs + 1] = run
      end
    end
    for _, r in ipairs(runs) do
      if r.e > r.s then
        out[#out + 1] = { startLine = r.s, endLine = r.e, kind = spec.runs.kind }
      end
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
    vim.list_extend(ranges, treesitter_ranges(buf))
    local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
    local first = st.levels == nil
    local folds = require("util.folds")
    -- the first answer replaces treesitter's folds with the server's: keep
    -- what's closed across the rebuild, then apply saved folds that had no
    -- matching fold until now
    local closed = first and folds.snapshot(buf) or nil
    st.ranges = M.normalize(ranges, lines)
    relevel(st)
    update(buf)
    if first then
      folds.restore(buf, closed)
      folds.rebuilt(buf)
      autofold(buf)
    end
  end)
end

-- folding ------------------------------------------------------------------------

--- The smallest range holding the row, preferring one that starts on it.
local function range_at(st, row)
  local best
  for _, r in ipairs(st.ranges) do
    if r.s <= row and row <= r.e then
      local starts = r.s == row
      if not best or (starts and best.s ~= row) or (starts == (best.s == row) and r.e - r.s < best.e - best.s) then
        best = r
      end
    end
  end
  return best
end

--- The smallest range strictly containing r.
local function parent_of(st, r)
  local best
  for _, p in ipairs(st.ranges) do
    if p.s <= r.s and r.e <= p.e and (p.s < r.s or p.e > r.e) and (not best or p.e - p.s < best.e - best.s) then
      best = p
    end
  end
  return best
end

--- Make the fold for the range at rows s..e in the window: claim its shared
--- rows (so it reads `if x { ... } else {`, or `} else { ... }`), unless a
--- neighbour holding one is already closed — then the chain they both
--- belong to is the fold. Returns the 1-based lines of the fold to close,
--- or nil when the buffer has no server folds or no such range.
---@return integer? start, integer? stop
function M.fold(buf, win, s, e)
  if buf == 0 then
    buf = api.nvim_get_current_buf()
  end
  local st = state_of(buf)
  if not (st and st.levels) then
    return
  end
  local r
  for _, x in ipairs(st.ranges) do
    if x.s == s and x.e == e then
      r = x
      break
    end
  end
  if not r then
    return
  end
  local shared = {} ---@type table<integer, "start"|"end"> row -> what r is there
  for _, o in ipairs(st.ranges) do
    if o ~= r and o.s ~= r.s and o.e == r.s then
      shared[r.s] = "start"
    end
    if o ~= r and o.e ~= r.e and o.s == r.e then
      shared[r.e] = "end"
    end
  end
  local blocked = false
  api.nvim_win_call(win, function()
    for row in pairs(shared) do
      local closed = vim.fn.foldclosed(row + 1)
      if closed ~= -1 then
        -- a closed fold that neither contains the range nor lies inside
        -- it (a chain's own first link, closed) is the neighbour holding
        -- that row
        local cs, ce = closed - 1, vim.fn.foldclosedend(row + 1) - 1
        local contains, inside = cs <= r.s and ce >= r.e, cs >= r.s and ce <= r.e
        blocked = blocked or not (contains or inside)
      end
    end
  end)
  if blocked then
    local p = parent_of(st, r)
    if not p then
      return
    end
    return M.fold(buf, win, p.s, p.e)
  end
  local changed = false
  for row, who in pairs(shared) do
    if st.owners[row] ~= who then
      st.owners[row] = who
      changed = true
    end
  end
  if changed then
    relevel(st)
    foldupdate(buf)
  end
  return r.s + 1, r.e + 1
end

--- ,d: open the closed fold at the cursor, else fold the region there.
function M.toggle()
  local buf, win = api.nvim_get_current_buf(), api.nvim_get_current_win()
  local lnum = api.nvim_win_get_cursor(win)[1]
  local st = states[buf]
  if not (st and st.levels) then
    vim.cmd("normal! za") -- treesitter's or indent folds: Vim's toggle
    return
  end
  if vim.fn.foldclosed(lnum) ~= -1 then
    vim.cmd("normal! zo")
    return
  end
  local r = range_at(st, lnum - 1)
  local s, e
  if r then
    s, e = M.fold(buf, win, r.s, r.e)
  end
  if not s then
    vim.notify("Nothing to fold here", vim.log.levels.INFO, { title = "Fold" })
    return
  end
  require("util.folds").close_exact(s, e)
  require("util.foldcursor").refresh()
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
        local st = { owners = {} }
        states[ev.buf] = st
        api.nvim_buf_attach(ev.buf, false, {
          on_bytes = function(_, _, _, start_row, _, _, old_row, _, _, new_row)
            if states[ev.buf] ~= st then
              return true
            end
            shift(st, start_row, old_row, new_row)
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
