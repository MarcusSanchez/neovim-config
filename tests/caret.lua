-- The caret on a closed fold (lua/util/foldcursor.lua): h/l/^/_/$ and the
-- config's word motions walk the drawn fold line, the real cursor follows
-- to the buffer position each character stands for, stepping onto the
-- ` ... ` opens the fold. On the Go fixture with gopls.
local lib = dofile(debug.getinfo(1, "S").source:sub(2):match("^(.*)/[^/]*$") .. "/lib.lua")
lib.suite("gopls", function(t)
  local FR, FT, FC = require("util.foldranges"), require("util.foldtext"), require("util.foldcursor")
  vim.fn.writefile({
    "package main",
    "",
    'import "errors"',
    "",
    "func h(",
    "\ta int,",
    "\tb int,",
    ") (int, error) {",
    '\treturn a + b, errors.New("x")',
    "}",
  }, "sig.go")
  vim.cmd("edit sig.go")
  vim.wait(15000, function()
    return FR.has(0)
  end, 50)
  t.wait(300)
  local win, buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
  vim.cmd("normal! zR")
  t.fold(6)
  t.check("the parameters are folded", t.span(5), "5..8")
  local function key(k)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(k, true, false, true), "x", false)
  end
  local function cursor()
    local c = vim.api.nvim_win_get_cursor(win)
    return c[1] .. ":" .. c[2]
  end
  local function caret()
    for _, c in ipairs(FT.render(FT.build(buf, 5, 8), FC.cell_at(win, buf, 5))) do
      if c[2] == "FoldCursor" then
        return c[1]
      end
    end
    return "none"
  end
  -- the drawn line's cells stand for buffer positions on the first and last line
  local cells = {}
  for _, c in ipairs(FT.cells(FT.build(buf, 5, 8))) do
    cells[#cells + 1] = c.ch .. (c.lnum and (c.lnum .. "." .. c.col) or "")
  end
  t.check(
    "cells",
    table.concat(cells, " "),
    "f5.0 u5.1 n5.2 c5.3  5.4 h5.5 (5.6   . . .   )8.0  8.1 (8.2 i8.3 n8.4 t8.5 ,8.6  8.7 e8.8 r8.9 r8.10 o8.11 r8.12 )8.13  8.14 {8.15"
  )
  vim.api.nvim_win_set_cursor(win, { 5, 0 })
  t.check("no caret before a motion", caret(), "none")
  key("$")
  t.check("$ lands on the `{` of the last line", cursor() .. " " .. caret(), "8:15 {")
  t.check("the fold stays closed", vim.fn.foldclosed(8), 5)
  t.check("the fold line reads the same with the caret", vim.fn.foldtextresult(5), "func h( ... ) (int, error) {")
  key("h")
  key("h")
  t.check("h h back onto `)`", cursor() .. " " .. caret(), "8:13 )")
  key("w") -- the config's w: previous word start, punctuation skipped
  t.check("w: previous word start, `error`", cursor() .. " " .. caret(), "8:8 e")
  local p = vim.lsp.util.make_position_params(win, "utf-8")
  t.check("hover/diagnostics see the caret's position", p.position.line .. ":" .. p.position.character, "7:8")
  key("w")
  t.check("w again: `int`", cursor() .. " " .. caret(), "8:3 i")
  key("w")
  t.check("w over the ` ... `: `h` on the first line", cursor() .. " " .. caret(), "5:5 h")
  key("b") -- next word end
  t.check("b: next word end, `t` of int", cursor() .. " " .. caret(), "8:5 t")
  key("B") -- next WORD end
  t.check("B: next WORD end, the `,` of `int,`", cursor() .. " " .. caret(), "8:6 ,")
  key("<S-h>")
  t.check("Shift-H: first cell", cursor() .. " " .. caret(), "5:0 f")
  key("<S-l>")
  t.check("Shift-L: last cell", cursor() .. " " .. caret(), "8:15 {")
  key("_")
  key("3l")
  t.check("3l counts cells", cursor() .. " " .. caret(), "5:3 c")
  vim.cmd("normal! k") -- (j/k are swapped in this config: Vim's own k here)
  t.check("leaving the fold upward drops the caret", cursor() .. " " .. caret(), "4:0 none")
  vim.cmd("normal! j")
  key("$")
  key("e") -- next word start: none left on the line, so the line below
  t.check("e past the last word: the line below the fold", cursor(), "9:1")
  t.check("the fold is still closed", vim.fn.foldclosed(5) .. ".." .. vim.fn.foldclosedend(5), "5..8")
  vim.api.nvim_win_set_cursor(win, { 5, 1 }) -- back onto the fold, at `u`
  key("l")
  t.check("l from `u`", cursor() .. " " .. caret(), "5:2 n")
  -- onto the ` ... `: the fold opens where the hidden text begins
  vim.api.nvim_win_set_cursor(win, { 5, 6 })
  key("l")
  t.check("l from `(` onto the dots opens the fold", vim.fn.foldclosed(5), -1)
  t.check("cursor on the first hidden line", cursor(), "6:1")
  t.fold(6)
  vim.api.nvim_win_set_cursor(win, { 8, 0 }) -- the `)` right after the dots
  key("h")
  t.check("h from `)` onto the dots opens the fold", vim.fn.foldclosed(5), -1)
  t.check("cursor at the end of the last hidden line", cursor(), "7:6")
  -- an edit drops the caret
  t.fold(6)
  key("$")
  t.check("caret back", caret(), "{")
  vim.api.nvim_buf_set_lines(buf, 9, 10, false, { "}", "" })
  t.check("an edit drops the caret", caret(), "none")
  -- off a fold the motions are as before: the config's w goes backwards
  vim.cmd("normal! zR")
  vim.api.nvim_win_set_cursor(win, { 9, 10 })
  key("w")
  t.check("w on an open line: previous word start", cursor(), "9:8")
  key("$")
  t.check("$ on an open line", cursor(), "9:29")
  vim.cmd("normal! zR")
  vim.cmd("buffer main.go")
  vim.api.nvim_buf_delete(buf, { force = true })
  vim.fn.delete("sig.go")
end)
