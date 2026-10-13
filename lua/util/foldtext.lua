-- IntelliJ-style fold line: the fold's first line coloured exactly as when
-- open (treesitter captures, plus rainbow brackets / LSP semantic tokens
-- from extmarks), then ` ... ` and the closing bracket from its last line,
-- so a folded block reads `func main() { ... }`. Both the dots and that
-- bracket are only drawn — the real lines are untouched.
--
-- Every chunk of the line remembers the buffer position its text comes
-- from, so the line can be read as cells (M.cells): one per character,
-- each standing for a position or for drawn text. util/foldcursor.lua
-- walks those with its caret, which M.text draws through the `caret` hook.
local M = {}

--- The caret cell to draw in a fold line, if any: (win, buf, first line)
--- -> cell index. Set by util/foldcursor.lua.
---@type fun(win: integer, buf: integer, start: integer): integer?
M.caret = nil

---@class util.foldtext.Chunk
---@field [1] string text as displayed (tabs expanded)
---@field [2] string highlight group
---@field [3] integer? buffer line the text comes from
---@field [4] integer? 0-based byte column it starts at there
---@field [5] string? the raw text there (tabs unexpanded)

---@class util.foldtext.Cell
---@field ch string
---@field hl string highlight group
---@field lnum integer? buffer line, nil for drawn text
---@field col integer? 0-based byte column

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
  local tree = query and parser:parse({ lnum - 1, lnum })[1]
  if not tree then
    return { { (line:gsub("\t", string.rep(" ", vim.bo[buf].tabstop))), "Folded", lnum, 0, line } }
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
      local raw = line:sub(from, col - 1)
      chunks[#chunks + 1] = { (raw:gsub("\t", tab)), cur or "Folded", lnum, from - 1, raw }
      from, cur = col, hl[col]
    end
  end
  return chunks, hl
end

--- A chunk's text from expanded byte i to j (to its end without j), with
--- its origin moved along: the raw text and its 0-based column, through
--- the tabs the expansion widened.
local function slice(c, i, j)
  local text, raw = c[1], c[5]
  j = j or #text
  local out = { text:sub(i, j), c[2] }
  if raw then
    local ntabs = select(2, raw:gsub("\t", ""))
    local width = ntabs > 0 and (#text - (#raw - ntabs)) / ntabs or 1
    local map, e = {}, 0 -- expanded byte -> raw byte
    for r = 1, #raw do
      for _ = 1, raw:sub(r, r) == "\t" and width or 1 do
        e = e + 1
        map[e] = r
      end
    end
    if map[i] then
      out[3], out[4], out[5] = c[3], c[4] + map[i] - 1, raw:sub(map[i], map[j] or #raw)
    end
  end
  return out
end

--- The chunk without its trailing blanks.
local function rtrimmed(c)
  local kept = #c[1]:gsub("%s+$", "")
  return kept < #c[1] and slice(c, 1, kept) or c
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
local function closer(last, filetype)
  -- a closing tag closes an element the way `}` closes a block (a `>>`
  -- closes a bit array, not a tag)
  local tag = last:match("^%s*(</[%w%.%-_]*>)") or (not last:match("^%s*>>") and last:match("^%s*(/?>)"))
  if tag then
    return tag, last:sub(#last:match("^%s*") + #tag + 1)
  end
  -- so does a closing keyword (`end`, `fi`, an `elseif`) in the languages
  -- that have them (util/foldranges.lua's table)
  local word = require("util.foldranges").closing_keyword(last, filetype)
  if word then
    return word, last:sub(#last:match("^%s*") + #word + 1)
  end
  local closers, rest = last:match("^%s*([%)%]}>\"'`#]+[,;]?)(.*)$")
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
    chunks[1] = slice(chunks[1], #chunks[1][1]:match("^%s*") + 1)
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

---@class util.foldtext.Fold what the builder works on
---@field buf integer
---@field first integer 1-based first line
---@field last integer 1-based last line
---@field head string the first line's text
---@field foot string the last line's text
---@field filetype string
---@field line fun(lnum: integer): string
---@field chunks util.foldtext.Chunk[] the line being built

--- ` ... ` and the line, indent dropped, as the fold line's next segment.
local function continue_with(f, lnum, dim)
  f.chunks[#f.chunks + 1] = { " ... ", "FoldEllipsis" }
  vim.list_extend(f.chunks, trimmed(highlighted(f.buf, lnum, f.line(lnum), dim)))
end

--- A run of imports reads `import ...` / `use ...` / `#include ...`, as
--- JetBrains collapses it: no one line stands for the whole run. The
--- server says which folds are imports; a run treesitter folded (Python)
--- is import lines, a wrapped one's closer included. One wrapped import
--- keeps its `( ... )` shape, as do bracketed forms (`import (` … `)`).
---@param f util.foldtext.Fold
---@return util.foldtext.Chunk[]?
local function imports(f)
  local function is_import(line)
    return line:match("^%s*import%f[%W]") ~= nil or line:match("^%s*from%f[%W]") ~= nil
  end
  local function import_run()
    if not is_import(f.head) then
      return false
    end
    local statements = 1
    for lnum = f.first + 1, f.last do
      local line = f.line(lnum)
      if is_import(line) then
        statements = statements + 1
      elseif not (line:match("^%s*[%)}]") or line:match("^%s+%S")) then
        return false
      end
    end
    return statements > 1
  end
  if require("util.foldranges").kind(f.buf, f.first, f.last) ~= "imports" and not import_run() then
    return
  end
  local keyword = f.head:match("^%s*(#?%a+)")
  if not keyword or select(2, trailing_openers(f.head)) then
    return
  end
  local pos, want = 0, #f.head:match("^%s*") + #keyword
  for _, c in ipairs((highlighted(f.buf, f.first, f.head))) do
    if pos >= want then
      break
    end
    local text = c[1]
    f.chunks[#f.chunks + 1] = pos + #text > want and slice(c, 1, want - pos) or c
    pos = pos + #text
  end
  f.chunks[#f.chunks + 1] = { " ...", "FoldEllipsis" }
  return f.chunks
end

--- A block comment closes with `*/` the way a block closes with `}`:
--- `/**` … `*/` reads `/** ... */`, `/* note` … `*/` reads `/* note ... */`.
---@param f util.foldtext.Fold
---@return util.foldtext.Chunk[]?
local function block_comment(f)
  local open = f.head:find("/*", 1, true)
  local close = f.foot:find("%*/%s*$")
  if not (open and close) or f.head:find("*/", open + 2, true) then
    return
  end
  vim.list_extend(f.chunks, (highlighted(f.buf, f.first, f.head)))
  f.chunks[#f.chunks + 1] = { " ... ", "FoldEllipsis" }
  local pos = 0
  for _, c in ipairs((highlighted(f.buf, f.last, f.foot))) do
    local text = c[1]
    if pos + #text > close - 1 then
      f.chunks[#f.chunks + 1] = rtrimmed(slice(c, math.max(close - pos, 1)))
    end
    pos = pos + #text
  end
  return f.chunks
end

--- Go's error check, folded, reads as the one-liner it is:
--- `if err != nil { return err }`, the `{ return err }` dim as one piece.
---@param f util.foldtext.Fold
---@return util.foldtext.Chunk[]?
local function go_error_check(f)
  if f.filetype ~= "go" or f.last ~= f.first + 2 then
    return
  end
  local brace = f.head:find("{%s*$")
  local ret = f.line(f.first + 1):match("^%s*(return%s+.-)%s*$")
  if not (brace and ret and ret:find("%f[%w]err%f[%W]") and f.foot:match("^%s*}%s*$")) then
    return
  end
  vim.list_extend(f.chunks, (highlighted(f.buf, f.first, f.head:sub(1, brace - 1))))
  f.chunks[#f.chunks + 1] = { "{ " .. ret .. " }", "FoldEllipsis" }
  return f.chunks
end

--- The line, at the same indent, that closes the keyword block line `l`
--- opens (`if … then` → its `elseif` / `else` / `end`), if it comes
--- before the fold's last line.
local function keyword_closing_line(f, l, text)
  local FR = require("util.foldranges")
  if not FR.opens_block(text, f.filetype) then
    return
  end
  local indent = text:match("^%s*")
  for n = l + 1, f.last - 1 do
    local candidate = f.line(n)
    if candidate:match("^%s*") == indent and FR.closing_keyword(candidate, f.filetype) then
      return n
    end
  end
end

--- Walk the fold: the first line, then each line whose opener closes
--- *before* the fold's last line (a wrapped parameter list, a call
--- spanning lines, an if branch up to its `elseif`) followed by ` ... `
--- and the line that closes it — so `fn send(` … `) -> R {` … `}` reads
--- `fn send( ... ) -> R { ... }`. Each segment's hidden brackets are dim:
--- the trailing openers, and the leading closers of a continuation.
--- Returns the last segment's line and text.
---@param f util.foldtext.Fold
local function walk(f)
  local lnum, line = f.first, f.head
  vim.list_extend(f.chunks, (highlighted(f.buf, lnum, line, (trailing_openers(line)))))
  for _ = 1, 6 do
    if not select(2, trailing_openers(line)) then
      -- an opening tag whose attributes wrap: elide them up to its `>`, so
      -- `<a` … `>` … `</a>` reads `<a ... > ... </a>`
      local tag_end = tag_end_line(f.buf, lnum, line)
      if tag_end and tag_end > lnum and tag_end < f.last then
        continue_with(f, tag_end, {})
        lnum, line = tag_end, f.line(tag_end)
        break
      end
      -- a keyword block closed before the fold's end: the fold line goes
      -- on with the line that closes it, so a Lua if reads
      -- `if x then ... elseif y then ... else ... end`
      local closes = keyword_closing_line(f, lnum, line)
      if not closes then
        break
      end
      continue_with(f, closes, {})
      lnum, line = closes, f.line(closes)
    else
      local closes = closing_line(f.buf, lnum, #line:gsub("%s+$", ""))
      if not closes or closes >= f.last or closes <= lnum then
        break
      end
      continue_with(f, closes, hidden_brackets(f.line(closes), true))
      lnum, line = closes, f.line(closes)
    end
  end
  return lnum, line
end

--- The tail after the walk: ` ... ` and the last line's leading closers,
--- each coloured like the opener it pairs with on the head line (dim when
--- that opener is hidden), then whatever follows them on that line — so
--- a parameters-only fold reads `fn send( ... ) -> Result<(), Error> {`.
---@param f util.foldtext.Fold
---@param lnum integer the walk's last line…
---@param line string …and its text
local function tail(f, lnum, line)
  local closers, rest = closer(f.foot, f.filetype)
  local chunks = f.chunks

  -- a head that opens nothing the last line closes — a condition wrapped
  -- over lines before its `{` — is followed by the line that does open it,
  -- so `if self` … `{` … `}` reads `if self ... { ... }`
  if closers and #unmatched_openers(line) == 0 then
    local ccol = f.foot:find("[%)%]}]")
    local opener = ccol and opening_line(f.buf, f.last, ccol)
    if opener and opener > lnum and opener < f.last then
      continue_with(f, opener, hidden_brackets(f.line(opener), false))
      lnum, line = opener, f.line(opener)
    end
  end

  -- a head fold ends on the line that opens the body (`{` alone under a
  -- wrapped condition): show it, so `if self` … `{` reads `if self ... {`
  if not closers and f.foot:match("^%s*[%({%[]") and f.last > lnum then
    continue_with(f, f.last, {})
    return chunks
  end

  chunks[#chunks + 1] = { closers and " ... " or " ...", "FoldEllipsis" }
  if not closers then
    return chunks
  end
  if closers:match("^[</>]") then
    -- a closing tag keeps its own colours (the one closer that isn't dim:
    -- `</main>` reads as the tag it is, not as punctuation)
    local indent, pos = #f.foot:match("^%s*"), 0
    for _, c in ipairs((highlighted(f.buf, f.last, f.foot))) do
      local text = c[1]
      if pos + #text > indent and pos < indent + #closers then
        chunks[#chunks + 1] = slice(c, math.max(indent - pos + 1, 1), indent + #closers - pos)
      end
      pos = pos + #text
    end
    return chunks
  end
  local _, hl = highlighted(f.buf, lnum, line)
  local dim_from = select(2, trailing_openers(line))
  local openers = unmatched_openers(line)
  local indent = #f.foot:match("^%s*")
  for i = 1, #closers do
    local ch = closers:sub(i, i)
    local group = "FoldEllipsis"
    if pairs_of[ch] then
      local col = table.remove(openers)
      if col and not (dim_from and col >= dim_from) then
        group = hl[col] or "Folded"
      end
    end
    chunks[#chunks + 1] = { ch, group, f.last, indent + i - 1, ch }
  end
  if rest and rest ~= "" then
    -- the remainder of the last line, highlighted in place; an opener it
    -- ends with (the `{` of `) -> R {`) starts something visible below the
    -- fold, so it keeps its colour. Chunks come with tabs expanded, so the
    -- indent is dropped by stripping blanks, not by counting its bytes.
    local skip, pos, started = #closers, 0, false -- the closers are already rendered
    for _, c in ipairs((highlighted(f.buf, f.last, f.foot, {}))) do
      if not started then
        c = slice(c, #c[1]:match("^%s*") + 1)
        started = c[1] ~= ""
      end
      if started then
        local text = c[1]
        if pos + #text > skip then
          chunks[#chunks + 1] = pos < skip and slice(c, skip - pos + 1) or c
        end
        pos = pos + #text
      end
    end
  end
  return chunks
end

--- The fold line for lines first_lnum..last_lnum of the buffer, as
--- chunks `{ text, group, lnum?, col?, raw? }`: text drawn from a buffer
--- line carries that line and the 0-based byte column it starts at (its
--- raw text too, tabs unexpanded); drawn text (` ... `, Go's
--- `{ return err }`) carries none. An import run, a block comment and
--- Go's error check have shapes of their own; everything else is the
--- walk through the fold's segments and the tail.
---@return util.foldtext.Chunk[]
function M.build(buf, first_lnum, last_lnum)
  local function line_at(lnum)
    return vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1] or ""
  end
  local f = {
    buf = buf,
    first = first_lnum,
    last = last_lnum,
    head = line_at(first_lnum),
    foot = line_at(last_lnum),
    filetype = vim.bo[buf].filetype,
    line = line_at,
    chunks = {},
  }
  return imports(f) or block_comment(f) or go_error_check(f) or tail(f, walk(f))
end

--- The fold line's cells, one per displayed character: `ch`, and for a
--- character drawn from a buffer line the line and 0-based byte column it
--- stands for (each space of an expanded tab stands for the tab).
---@param chunks util.foldtext.Chunk[]
---@return util.foldtext.Cell[]
function M.cells(chunks)
  local cells = {}
  for _, c in ipairs(chunks) do
    if c[3] then
      local raw, text = c[5], c[1]
      local ntabs = select(2, raw:gsub("\t", ""))
      local width = ntabs > 0 and (#text - (#raw - ntabs)) / ntabs or 1
      local starts = vim.str_utf_pos(raw)
      for n, b in ipairs(starts) do
        local ch = raw:sub(b, (starts[n + 1] or #raw + 1) - 1)
        if ch == "\t" then
          for _ = 1, width do
            cells[#cells + 1] = { ch = " ", hl = c[2], lnum = c[3], col = c[4] + b - 1 }
          end
        else
          cells[#cells + 1] = { ch = ch, hl = c[2], lnum = c[3], col = c[4] + b - 1 }
        end
      end
    else
      local text = c[1]
      local starts = vim.str_utf_pos(text)
      for n, b in ipairs(starts) do
        cells[#cells + 1] = { ch = text:sub(b, (starts[n + 1] or #text + 1) - 1), hl = c[2] }
      end
    end
  end
  return cells
end

--- The chunks as 'foldtext' takes them, `{ text, group }` only, with the
--- cell at index `cursor` (if any) drawn as the caret.
---@param chunks util.foldtext.Chunk[]
---@param cursor integer?
function M.render(chunks, cursor)
  local out, seen = {}, 0
  for _, c in ipairs(chunks) do
    local text = c[1]
    local n = vim.fn.strchars(text)
    if cursor and cursor > seen and cursor <= seen + n then
      local at = cursor - seen - 1 -- 0-based char index within the chunk
      local before, caret, after =
        vim.fn.strcharpart(text, 0, at), vim.fn.strcharpart(text, at, 1), vim.fn.strcharpart(text, at + 1)
      if before ~= "" then
        out[#out + 1] = { before, c[2] }
      end
      out[#out + 1] = { caret, "FoldCursor" }
      if after ~= "" then
        out[#out + 1] = { after, c[2] }
      end
    else
      out[#out + 1] = { text, c[2] }
    end
    seen = seen + n
  end
  return out
end

--- 'foldtext': the fold line of the fold being drawn, with the caret
--- where the `caret` hook says there is one in this window.
function M.text()
  local buf, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
  local chunks = M.build(buf, vim.v.foldstart, vim.v.foldend)
  return M.render(chunks, M.caret and M.caret(win, buf, vim.v.foldstart) or nil)
end

return M
