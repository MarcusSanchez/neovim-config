-- IntelliJ-style fold line: the fold's first line with its treesitter
-- highlighting, then ` ... ` and the closing bracket from its last line, so
-- a folded block reads `func main() { ... }`. Both the dots and that bracket
-- are only drawn — the real lines are untouched.
local M = {}

--- The fold's first line as highlighted chunks, from the buffer's treesitter
--- highlights query (per-column, last capture wins, like the highlighter).
---@return { [1]: string, [2]: string }[]
local function highlighted(buf, lnum, line)
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
  return chunks
end

--- Closing punctuation at the end of the fold (`}`, `)`, `]`, `},`, `});`…),
--- or nil when the last line is more than that.
local function closer(last)
  return last:match("^%s*([%)%]}]+[,;]?)%s*$")
end

function M.text()
  local buf = vim.api.nvim_get_current_buf()
  local first = vim.api.nvim_buf_get_lines(buf, vim.v.foldstart - 1, vim.v.foldstart, false)[1] or ""
  local last = vim.api.nvim_buf_get_lines(buf, vim.v.foldend - 1, vim.v.foldend, false)[1] or ""
  local chunks = highlighted(buf, vim.v.foldstart, first)
  local tail = closer(last)
  chunks[#chunks + 1] = { tail and " ... " or " ...", "FoldEllipsis" }
  if tail then
    chunks[#chunks + 1] = { tail, "FoldEllipsis" }
  end
  return chunks
end

return M
