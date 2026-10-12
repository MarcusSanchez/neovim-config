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
  for id, node in query:iter_captures(tree:root(), buf, lnum - 1, lnum) do
    local name = query.captures[id]
    -- captures that aren't highlights: `_`-prefixed helpers the queries
    -- use in predicates (`@_tag`, `@_jsx_attribute`), and the spell markers
    -- on comments and strings. They have no colour, so a chunk given one
    -- would fall back to Folded (blue). The highlighter skips them too.
    if name:sub(1, 1) ~= "_" and name ~= "spell" and name ~= "nospell" then
      local srow, scol, erow, ecol = node:range()
      if srow < lnum - 1 then
        scol = 0
      end
      if erow > lnum - 1 then
        ecol = #line
      end
      local group = "@" .. name .. "." .. parser:lang()
      for col = scol + 1, math.min(ecol, #line) do
        hl[col] = group
      end
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
  -- a closing tag closes an element the way `}` closes a block
  local tag = last:match("^%s*(</[%w%.%-_]*>)") or last:match("^%s*(/?>)")
  if tag then
    return tag, last:sub(#last:match("^%s*") + #tag + 1)
  end
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

--- For a line that starts an opening tag whose attributes wrap (`<a`
--- without its `>`): the line the tag ends on, via treesitter.
local function tag_end_line(buf, lnum, line)
  local col = #line:match("^%s*") + 1
  if not line:match("^%s*<[%w%.%-_]*") or line:find(">", col, true) then
    return
  end
  local ok, node =
    pcall(vim.treesitter.get_node, { bufnr = buf, pos = { lnum - 1, col - 1 }, ignore_injections = true })
  if not ok or not node then
    return
  end
  local tags =
    { jsx_opening_element = true, jsx_self_closing_element = true, start_tag = true, self_closing_tag = true }
  while node and not tags[node:type()] do
    node = node:parent()
  end
  if not node then
    return
  end
  return node:end_() + 1
end

--- The 1-based line where the bracket at (lnum, col) is closed, per the
--- syntax tree: the bracket's parent node (parameters, arguments, block…)
--- ends on that line. nil when treesitter can't say.
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

--- A line's chunks without its indent, to continue the fold line after
--- ` ... `.
local function trimmed(chunks)
  if chunks[1] and chunks[1][1]:match("^%s+$") then
    table.remove(chunks, 1)
  elseif chunks[1] then
    chunks[1][1] = chunks[1][1]:gsub("^%s+", "")
  end
  return chunks
end

--- Columns of a continuation line drawn dim: its trailing openers (the
--- bracket the fold hides behind) and, when asked, its leading closers
--- (`) -> R {` after a hidden parameter list).
local function hidden_brackets(raw, with_leading)
  local dim = trailing_openers(raw)
  if with_leading then
    local indent = #raw:match("^%s*")
    local lead = #(raw:sub(indent + 1):match("^[%)%]}\"'`#]*") or "")
    for col = indent + 1, indent + lead do
      dim[col] = true
    end
  end
  return dim
end

function M.text()
  local buf = vim.api.nvim_get_current_buf()
  local first_lnum, last_lnum = vim.v.foldstart, vim.v.foldend
  local function line_at(lnum)
    return vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1] or ""
  end
  local chunks = {}
  --- ` ... ` and the line, indent dropped, as the fold line's next segment
  local function continue_with(lnum, dim)
    chunks[#chunks + 1] = { " ... ", "FoldEllipsis" }
    vim.list_extend(chunks, trimmed(highlighted(buf, lnum, line_at(lnum), dim)))
  end

  -- a run of imports (the server says so) reads `import ...` / `use ...`,
  -- as JetBrains collapses it: no one line stands for the whole run.
  -- Bracketed forms (`import (` … `)`) keep the usual shape.
  local head, last = line_at(first_lnum), line_at(last_lnum)
  if require("util.foldranges").kind(buf, first_lnum, last_lnum) == "imports" then
    local keyword = head:match("^%s*(%a+)")
    if keyword and not select(2, trailing_openers(head)) then
      local pos, want = 0, #head:match("^%s*") + #keyword
      for _, c in ipairs((highlighted(buf, first_lnum, head))) do
        if pos >= want then
          break
        end
        local text = c[1]
        if pos + #text > want then
          text = text:sub(1, want - pos)
        end
        chunks[#chunks + 1] = { text, c[2] }
        pos = pos + #text
      end
      chunks[#chunks + 1] = { " ...", "FoldEllipsis" }
      return chunks
    end
  end

  -- a block comment closes with `*/` the way a block closes with `}`:
  -- `/**` … `*/` reads `/** ... */`, `/* note` … `*/` reads `/* note ... */`
  local open = head:find("/*", 1, true)
  local close = last:find("%*/%s*$")
  if open and not head:find("*/", open + 2, true) and close then
    vim.list_extend(chunks, (highlighted(buf, first_lnum, head)))
    chunks[#chunks + 1] = { " ... ", "FoldEllipsis" }
    local pos = 0
    for _, c in ipairs((highlighted(buf, last_lnum, last))) do
      local text = c[1]
      if pos + #text > close - 1 then
        chunks[#chunks + 1] = { (text:sub(math.max(close - pos, 1)):gsub("%s+$", "")), c[2] }
      end
      pos = pos + #text
    end
    return chunks
  end

  -- Go's error check, folded, reads as the one-liner it is:
  -- `if err != nil { return err }`, the `{ return err }` dim as one piece
  if vim.bo[buf].filetype == "go" and last_lnum == first_lnum + 2 then
    local brace = head:find("{%s*$")
    local ret = line_at(first_lnum + 1):match("^%s*(return%s+.-)%s*$")
    if brace and ret and ret:find("%f[%w]err%f[%W]") and last:match("^%s*}%s*$") then
      vim.list_extend(chunks, (highlighted(buf, first_lnum, head:sub(1, brace - 1))))
      chunks[#chunks + 1] = { "{ " .. ret .. " }", "FoldEllipsis" }
      return chunks
    end
  end

  -- Walk the fold: a line whose trailing opener closes *before* the fold's
  -- last line (a wrapped parameter list, a call spanning lines) is followed
  -- by ` ... ` and the line that closes it, so `fn send(` … `) -> R {` … `}`
  -- reads `fn send( ... ) -> R { ... }`. Each segment's hidden brackets are
  -- dim: the trailing openers, and the leading closers of a continuation.
  local lnum, line = first_lnum, head
  vim.list_extend(chunks, (highlighted(buf, lnum, line, (trailing_openers(line)))))
  for _ = 1, 4 do
    if not select(2, trailing_openers(line)) then
      -- an opening tag whose attributes wrap: elide them up to its `>`, so
      -- `<a` … `>` … `</a>` reads `<a ... > ... </a>`
      local tag_end = tag_end_line(buf, lnum, line)
      if tag_end and tag_end > lnum and tag_end < last_lnum then
        continue_with(tag_end, {})
        lnum, line = tag_end, line_at(tag_end)
      end
      break
    end
    local closes = closing_line(buf, lnum, #line:gsub("%s+$", ""))
    if not closes or closes >= last_lnum or closes <= lnum then
      break
    end
    continue_with(closes, hidden_brackets(line_at(closes), true))
    lnum, line = closes, line_at(closes)
  end

  local tail, rest = closer(last)

  -- a head that opens nothing the last line closes — a condition wrapped
  -- over lines before its `{` — is followed by the line that does open it,
  -- so `if self` … `{` … `}` reads `if self ... { ... }`
  if tail and #unmatched_openers(line) == 0 then
    local ccol = last:find("[%)%]}]")
    local opener = ccol and opening_line(buf, last_lnum, ccol)
    if opener and opener > lnum and opener < last_lnum then
      continue_with(opener, hidden_brackets(line_at(opener), false))
      lnum, line = opener, line_at(opener)
    end
  end

  -- a head fold ends on the line that opens the body (`{` alone under a
  -- wrapped condition): show it, so `if self` … `{` reads `if self ... {`
  if not tail and last:match("^%s*[%({%[]") and last_lnum > lnum then
    continue_with(last_lnum, {})
    return chunks
  end

  -- the tail: ` ... ` and the last line's leading closers, each coloured
  -- like the opener it pairs with on the head line (dim when that opener is
  -- hidden), then whatever follows them on that line — so a parameters-only
  -- fold reads `fn send( ... ) -> Result<(), Error> {`
  chunks[#chunks + 1] = { tail and " ... " or " ...", "FoldEllipsis" }
  if not tail then
    return chunks
  end
  if tail:match("^[</>]") then
    -- a closing tag keeps its own colours (the one closer that isn't dim:
    -- `</main>` reads as the tag it is, not as punctuation)
    local indent, pos = #last:match("^%s*"), 0
    for _, c in ipairs((highlighted(buf, last_lnum, last))) do
      local text = c[1]
      if pos + #text > indent and pos < indent + #tail then
        chunks[#chunks + 1] = { text:sub(math.max(indent - pos + 1, 1), indent + #tail - pos), c[2] }
      end
      pos = pos + #text
    end
    return chunks
  end
  local _, hl = highlighted(buf, lnum, line)
  local dim_from = select(2, trailing_openers(line))
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
    -- ends with (the `{` of `) -> R {`) starts something visible below the
    -- fold, so it keeps its colour. Chunks come with tabs expanded, so the
    -- indent is dropped by stripping blanks, not by counting its bytes.
    local skip, pos, started = #tail, 0, false -- the closers are already rendered
    for _, c in ipairs((highlighted(buf, last_lnum, last, {}))) do
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
  return chunks
end

return M
