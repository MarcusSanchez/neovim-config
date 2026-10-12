-- Small editing behaviours behind keymaps.
local M = {}

--- Indent (`>`) or dedent (`<`) the visual selection and keep it selected,
--- anchored to the same text: each endpoint moves by however much its line
--- actually shifted, so any shiftwidth and partially indented lines work.
function M.shift_selection(op)
  local cl, cc = vim.fn.line("."), vim.fn.col(".")
  local al, ac = vim.fn.line("v"), vim.fn.col("v")
  local cursor_first = cl < al or (cl == al and cc < ac)
  local clen, alen = #vim.fn.getline(cl), #vim.fn.getline(al)
  vim.cmd("normal! " .. op)
  local cpos = { cl, math.max(cc + #vim.fn.getline(cl) - clen, 1) }
  local apos = { al, math.max(ac + #vim.fn.getline(al) - alen, 1) }
  local first, last = apos, cpos
  if cursor_first then
    first, last = cpos, apos
  end
  vim.fn.setpos("'<", { 0, first[1], first[2], 0 })
  vim.fn.setpos("'>", { 0, last[1], last[2], 0 })
  vim.cmd("normal! gv")
  -- gv leaves the cursor on '>'; put it back on the end the user was on
  if cursor_first then
    vim.cmd("normal! o")
  end
end

--- Keys that leave insert mode where the insert ended instead of one
--- column back (the `^ mark is that spot; normal mode clamps it to the
--- line's last character): `a jj` repeated walks right one character at a
--- time, `i jj` stays put. Keeps LazyVim's insert-mode <Esc> extras (clear
--- hlsearch, stop snippet). For an `expr` mapping.
function M.leave_insert()
  vim.cmd("noh")
  LazyVim.cmp.actions.snippet_stop()
  return "<Esc>`^"
end

return M
