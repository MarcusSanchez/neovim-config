-- gc on a selection within a line wraps it in a block comment, as
-- IntelliJ comments a selection: `foo(/* bar */, baz)` rather than the
-- whole line turned into `// foo(bar, baz)`. Linewise selections and gcc
-- stay line comments. Languages without block comments (zig, gleam,
-- python…) fall back to the line comment.
local M = {}

local blocks = {
  c = "/* %s */",
  cpp = "/* %s */",
  go = "/* %s */",
  rust = "/* %s */",
  typescript = "/* %s */",
  javascript = "/* %s */",
  typescriptreact = "/* %s */",
  javascriptreact = "/* %s */",
  proto = "/* %s */",
  nix = "/* %s */",
  css = "/* %s */",
  scss = "/* %s */",
  java = "/* %s */",
  kotlin = "/* %s */",
  swift = "/* %s */",
  lua = "--[[ %s ]]",
  html = "<!-- %s -->",
  markdown = "<!-- %s -->",
}

--- The block comment form at a position of the buffer (`%s` for the
--- text), nil where the language has none. In JSX markup (not inside an
--- `{expression}` or a tag's attributes) a comment is `{/* … */}`.
---@return string?
function M.form(buf, row, col)
  local ft = vim.bo[buf].filetype
  local form = blocks[ft]
  if not form or (ft ~= "typescriptreact" and ft ~= "javascriptreact") then
    return form
  end
  local okp, parser = pcall(vim.treesitter.get_parser, buf, nil, { error = false })
  if okp and parser then
    parser:parse(true) -- a buffer not yet drawn has no tree
  end
  local ok, node = pcall(vim.treesitter.get_node, { bufnr = buf, pos = { row, col } })
  while ok and node do
    local t = node:type()
    if t == "jsx_expression" or t == "jsx_opening_element" or t == "jsx_closing_element" then
      break
    end
    if t == "jsx_element" then
      return "{/* %s */}"
    end
    node = node:parent()
  end
  return form
end

--- The rhs for `gc` in visual mode (an expr mapping): on a charwise
--- selection in a language with block comments, the block toggle; else
--- the built-in comment operator (Neovim's own `gc`, a private module
--- that may move between versions).
function M.operator()
  local pos = vim.fn.getpos("v")
  if vim.fn.mode() == "v" and M.form(0, pos[2] - 1, pos[3] - 1) then
    return "<Cmd>lua require('util.comment').block()<CR>"
  end
  return require("vim._comment").operator()
end

--- The selection (charwise visual mode is active) wrapped in the block
--- comment, or unwrapped when it already is one.
function M.block()
  local buf = vim.api.nvim_get_current_buf()
  local v, c = vim.fn.getpos("v"), vim.fn.getpos(".")
  local sl, sc, el, ec = v[2], v[3], c[2], c[3]
  if sl > el or (sl == el and sc > ec) then
    sl, sc, el, ec = el, ec, sl, sc
  end
  ec = math.min(ec, #vim.fn.getline(el)) -- `$` selects past the end
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
  local form = M.form(buf, sl - 1, sc - 1)
  if not form then
    return
  end
  local open, close = form:match("^(.-)%%s(.-)$")
  local lines = vim.api.nvim_buf_get_text(buf, sl - 1, sc - 1, el - 1, ec, {})
  local text = table.concat(lines, "\n")
  local bare_open, bare_close = vim.trim(open), vim.trim(close)
  local inner = text:match("^" .. vim.pesc(bare_open) .. " ?(.-) ?" .. vim.pesc(bare_close) .. "$")
  local new = inner or (open .. text .. close)
  vim.api.nvim_buf_set_text(buf, sl - 1, sc - 1, el - 1, ec, vim.split(new, "\n", { plain = true }))
  vim.api.nvim_win_set_cursor(0, { sl, sc - 1 })
end

return M
