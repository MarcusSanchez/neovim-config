-- IntelliJ-style fold line: the fold's first line coloured exactly as when
-- open (treesitter captures, plus rainbow brackets / LSP semantic tokens
-- from extmarks), then ` ... ` and the closing bracket from its last line,
-- so a folded block reads `func main() { ... }`. Both the dots and that
-- bracket are only drawn — the real lines are untouched.
local M = {}

-- closer -> opener; quotes close themselves (multi-line strings fold too)
local pairs_of = { [")"] = "(", ["]"] = "[", ["}"] = "{", ['"'] = '"', ["'"] = "'", ["`"] = "`" }
local OPENERS = "[%({%[\"'`]"

--- The fold's first line as highlighted chunks, from the buffer's treesitter
--- highlights query (per-column, last capture wins, like the highlighter).
---@param dim? table<integer, boolean> 1-based columns drawn dim (the brackets the fold hides behind)
---@return { [1]: string, [2]: string }[] chunks, table<integer, string> hl per byte column
local function highlighted(buf, lnum, line, dim)
  local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, lang)
  local query = ok and parser and vim.treesitter.query.get(parser:lang(), "highlights")
  if not query then
    return { { line, "Folded" } }
  end
  local tree = parser:parse({ lnum - 1, lnum })[1]
  if not tree then
    return { { line, "Folded" } }
  end
  local hl = {} ---@type table<integer, string> column (1-based) -> group
  for id, node, metadata in query:iter_captures(tree:root(), buf, lnum - 1, lnum) do
    local srow, scol, erow, ecol = node:range()
    if srow < lnum - 1 then
      scol = 0
    end
    if erow > lnum - 1 then
      ecol = #line
    end
    local group = "@" .. query.captures[id] .. "." .. parser:lang()
    for col = scol + 1, math.min(ecol, #line) do
      hl[col] = group
    end
  end
  -- Everything else that colours the open line is an extmark: rainbow
  -- brackets, LSP semantic tokens (catppuccin's @lsp.* overrides), etc. Lay
  -- them over the captures in priority order, like the screen does — only
  -- groups that set a foreground, so underline-only marks (diagnostics)
  -- can't blank a colour.
  local marks = vim.api.nvim_buf_get_extmarks(buf, -1, { lnum - 1, 0 }, { lnum - 1, -1 }, { details = true })
  table.sort(marks, function(x, y)
    return (x[4].priority or 0) < (y[4].priority or 0)
  end)
  local has_fg = {} ---@type table<string, boolean>
  for _, mark in ipairs(marks) do
    local scol, details = mark[3], mark[4]
    local group = details.hl_group
    if group then
      if has_fg[group] == nil then
        local ok_hl, def = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
        has_fg[group] = ok_hl and def.fg ~= nil
      end
      if has_fg[group] then
        local ecol = (details.end_row == nil or details.end_row == lnum - 1) and (details.end_col or scol + 1) or #line
        for col = scol + 1, math.min(ecol, #line) do
          hl[col] = group
        end
      end
    end
  end
  -- the opening bracket(s) the fold hides behind read as part of the drawn
  -- ` ... }` tail, so they take its colour rather than a rainbow one
  for col in pairs(dim or {}) do
    hl[col] = "FoldEllipsis"
  end
  -- columns above are byte offsets into the real line; tabs are expanded
  -- per chunk afterwards so they display at their width
  local tab = string.rep(" ", vim.bo[buf].tabstop)
  local chunks, from, cur = {}, 1, hl[1]
  for col = 2, #line + 1 do
    if hl[col] ~= cur or col == #line + 1 then
      chunks[#chunks + 1] = { (line:sub(from, col - 1):gsub("\t", tab)), cur or "Folded" }
      from, cur = col, hl[col]
    end
  end
  return chunks, hl
end

--- Columns of the first line's openers still unmatched at its end, bottom
--- to top. The fold's closers on the last line pop these in order.
local function unmatched_openers(line)
  local stack = {}
  for col = 1, #line do
    local ch = line:sub(col, col)
    local top = stack[#stack] and line:sub(stack[#stack], stack[#stack])
    if pairs_of[ch] and top == pairs_of[ch] then
      stack[#stack] = nil -- closes the innermost opener (a quote closes itself)
    elseif ch:match(OPENERS) then
      stack[#stack + 1] = col
    end
  end
  return stack
end

--- The fold's last line split into its leading closers (`}`, `)`, `]`, a
--- string's closing quote, rust's `"#`, with a trailing `,`/`;`) and the
--- rest — `) -> Result<(), Error> {` is closers `)` plus the rest. Nil
--- closers when the line doesn't start with one.
local function closer(last)
  local closers, rest = last:match("^%s*([%)%]}\"'`#]+[,;]?)(.*)$")
  if not closers then
    return nil, nil
  end
  if rest:match("^[,;]?%s*$") then
    return closers .. rest:gsub("%s+$", ""), ""
  end
  return closers, rest
end

--- Columns of the trailing opening brackets on a line (`func h(`, `x := {`).
local function trailing_openers(line)
  local cols, from = {}, line:find(OPENERS .. "+%s*$")
  if from then
    for col = from, #line do
      if line:sub(col, col):match(OPENERS) then
        cols[col] = true
      end
    end
  end
  return cols, from
end

--- The 1-based line where the bracket at (lnum, col) is closed, per the
--- syntax tree: the bracket's parent node (parameters, arguments, block…)
--- ends on that line. nil when treesitter can't say.
--- The line holding the opener that the bracket at (lnum, col) closes,
--- via the treesitter node ending at that bracket.
local function opening_line(buf, lnum, col)
  local ok, node =
    pcall(vim.treesitter.get_node, { bufnr = buf, pos = { lnum - 1, col - 1 }, ignore_injections = true })
  if not ok or not node then
    return
  end
  while node do
    local erow, ecol = node:end_()
    if erow == lnum - 1 and ecol == col then
      break
    end
    node = node:parent()
  end
  if not node then
    return
  end
  return node:start() + 1
end

local function closing_line(buf, lnum, col)
  local ok, node =
    pcall(vim.treesitter.get_node, { bufnr = buf, pos = { lnum - 1, col - 1 }, ignore_injections = true })
  if not ok or not node then
    return
  end
  -- get_node returns the smallest *named* node at the position: for `(`
  -- that's the parameter/argument list itself, for `{` the block — the
  -- bracketed node, which starts right at the bracket. Walk up while the
  -- node doesn't start there.
  while node do
    local srow, scol = node:start()
    if srow == lnum - 1 and scol == col - 1 then
      break
    end
    node = node:parent()
  end
  if not node then
    return
  end
  local erow = node:end_()
  return erow + 1
end

function M.text()
  local buf = vim.api.nvim_get_current_buf()
  local first_lnum, last_lnum = vim.v.foldstart, vim.v.foldend
  local function line_at(lnum)
    return vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1] or ""
  end

  -- Walk the fold: a line whose trailing opener closes *before* the fold's
  -- last line (a wrapped parameter list, a call spanning lines) is followed
  -- by ` ... ` and the line that closes it, so `fn send(` … `) -> R {` … `}`
  -- reads `fn send( ... ) -> R { ... }`. Each segment's hidden brackets are
  -- dim: the trailing openers, and the leading closers of a continuation.
  local chunks = {}
  local lnum, line, lead = first_lnum, line_at(first_lnum), 0
  for _ = 1, 4 do
    local dim, from = trailing_openers(line)
    for col = 1, lead do
      dim[col] = true
    end
    vim.list_extend(chunks, (highlighted(buf, lnum, line, dim)))
    if not from then
      break
    end
    local close = closing_line(buf, lnum, #line:gsub("%s+$", ""))
    if not close or close >= last_lnum or close <= lnum then
      break
    end
    chunks[#chunks + 1] = { " ... ", "FoldEllipsis" }
    local raw = line_at(close)
    local indent = raw:match("^%s*")
    line, lnum = raw:sub(#indent + 1), close
    lead = #(line:match("^[%)%]}\"'`#]*") or "")
    -- the continuation's own columns are offset by the indent we dropped;
    -- highlight it against the real line and drop the indent chunk after
    local real_dim = {}
    for col = 1, lead do
      real_dim[col + #indent] = true
    end
    local topen = trailing_openers(raw)
    for col in pairs(topen) do
      real_dim[col] = true
    end
    local seg = highlighted(buf, lnum, raw, real_dim)
    if seg[1] and seg[1][1]:match("^%s+$") then
      table.remove(seg, 1)
    elseif seg[1] then
      seg[1][1] = seg[1][1]:gsub("^%s+", "")
    end
    vim.list_extend(chunks, seg)
    line, lead = raw, 0
    -- the trailing-opener test above already ran for `raw` inside highlighted;
    -- continue the walk from this line
    local _, nfrom = trailing_openers(raw)
    if not nfrom then
      break
    end
    local nclose = closing_line(buf, lnum, #raw:gsub("%s+$", ""))
    if not nclose or nclose >= last_lnum or nclose <= lnum then
      break
    end
    -- more than two hops is rare; keep going by re-entering the loop body
    -- with this line as the head (chunks for it are already appended)
    chunks[#chunks + 1] = { " ... ", "FoldEllipsis" }
    raw = line_at(nclose)
    indent = raw:match("^%s*")
    lnum = nclose
    lead = #(raw:sub(#indent + 1):match("^[%)%]}\"'`#]*") or "")
    real_dim = {}
    for col = 1, lead do
      real_dim[col + #indent] = true
    end
    for col in pairs((trailing_openers(raw))) do
      real_dim[col] = true
    end
    seg = highlighted(buf, lnum, raw, real_dim)
    if seg[1] and seg[1][1]:match("^%s+$") then
      table.remove(seg, 1)
    elseif seg[1] then
      seg[1][1] = seg[1][1]:gsub("^%s+", "")
    end
    vim.list_extend(chunks, seg)
    line = raw
    break
  end

  local last = line_at(last_lnum)
  local tail, rest = closer(last)

  -- a head that opens nothing the last line closes — a condition wrapped
  -- over lines before its `{` — is followed by the line that does open it,
  -- so `if self` … `{` … `}` reads `if self ... { ... }`
  if tail and #unmatched_openers(line) == 0 then
    local ccol = last:find("[%)%]}]")
    local open = ccol and opening_line(buf, last_lnum, ccol)
    if open and open > lnum and open < last_lnum then
      chunks[#chunks + 1] = { " ... ", "FoldEllipsis" }
      local raw = line_at(open)
      local seg = highlighted(buf, open, raw, (trailing_openers(raw)))
      if seg[1] and seg[1][1]:match("^%s+$") then
        table.remove(seg, 1)
      elseif seg[1] then
        seg[1][1] = seg[1][1]:gsub("^%s+", "")
      end
      vim.list_extend(chunks, seg)
      lnum, line = open, raw
    end
  end

  -- the tail: ` ... ` and the last line's leading closers, each coloured
  -- like the opener it pairs with on the head line (dim when that opener is
  -- hidden), then whatever follows them on that line — so a parameters-only
  -- fold reads `fn send( ... ) -> Result<(), Error> {`
  local _, hl = highlighted(buf, lnum, line)
  local dim_from = select(2, trailing_openers(line))
  chunks[#chunks + 1] = { tail and " ... " or " ...", "FoldEllipsis" }
  if tail then
    local openers = unmatched_openers(line)
    for i = 1, #tail do
      local ch = tail:sub(i, i)
      local group = "FoldEllipsis"
      if pairs_of[ch] then
        local col = table.remove(openers)
        if col and not (dim_from and col >= dim_from) then
          group = hl[col] or "Folded"
        end
      end
      chunks[#chunks + 1] = { ch, group }
    end
    if rest and rest ~= "" then
      -- the remainder of the last line, highlighted in place; an opener it
      -- ends with (the `{` of `) -> R {`) starts something visible below
      -- the fold, so it keeps its colour
      -- (chunks come with tabs expanded, so drop the indent by stripping
      -- leading blanks rather than counting its bytes)
      local seg = highlighted(buf, last_lnum, last, {})
      local skip, pos, started = #tail, 0, false -- the closers are already rendered
      for _, c in ipairs(seg) do
        local text = c[1]
        if not started then
          text = text:gsub("^%s+", "")
          started = text ~= ""
        end
        if started then
          if pos + #text > skip then
            chunks[#chunks + 1] = { text:sub(math.max(skip - pos + 1, 1)), c[2] }
          end
          pos = pos + #text
        end
      end
    end
  end
  return chunks
end

return M
