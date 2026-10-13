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
    "",
    "func g() {}",
    "",
    "// one",
    "// two",
    "var z = 1",
  }, "sig.go")
  vim.cmd("edit sig.go")
  t.ranges()
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
  local function moved()
    vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
  end
  local function caret() -- the caret's character in the closed fold at the cursor
    local l = vim.api.nvim_win_get_cursor(win)[1]
    local s = vim.fn.foldclosed(l)
    if s == -1 then
      return "none"
    end
    for _, c in ipairs(FT.render(FT.build(buf, s, vim.fn.foldclosedend(l)), FC.cell_at(win, buf, s))) do
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
  t.check("folding from a hidden line: the caret on the first cell", cursor() .. " " .. caret(), "5:0 f")
  vim.api.nvim_win_set_cursor(win, { 5, 0 })
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
  -- Vim's cursor is hidden (a beam in the line's colour) while the caret shows
  t.fold(6)
  key("$")
  t.check("caret back", caret(), "{")
  t.check("the cursor is hidden while the caret shows", vim.o.guicursor:match("n:ver1%-FoldHiddenCursor$") ~= nil, true)
  local hl = vim.api.nvim_get_hl(0, { name = "FoldHiddenCursor" })
  t.check("in the cursor line's colour", hl.bg ~= nil and hl.bg == hl.fg, true)
  vim.cmd("normal! k")
  vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
  t.check("moving off the fold restores the cursor", vim.o.guicursor:find("FoldHiddenCursor") == nil, true)
  t.check("restored to the value from before", FC.hidden(), nil)
  vim.cmd("normal! j")
  key("$")
  -- an edit elsewhere keeps the caret (its character still where it was);
  -- one that moves the character drops it
  t.check("caret back after the cursor-hide round trip", caret(), "{")
  vim.api.nvim_buf_set_lines(buf, 9, 10, false, { "}", "" })
  t.check("an edit elsewhere keeps the caret", caret(), "{")
  vim.api.nvim_buf_set_text(buf, 7, 0, 7, 0, { " " })
  t.check("an edit moving its character drops the caret", caret(), "none")
  vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
  t.check("and shows the cursor", vim.o.guicursor:find("FoldHiddenCursor") == nil, true)
  -- a line with two ` ... `: each opens only what it hides
  vim.api.nvim_buf_set_lines(buf, 7, 11, false, { ") (int, error) {", '\treturn a + b, errors.New("x")', "}" }) -- the edits undone; gopls answers again
  vim.wait(10000, function()
    for _, r in ipairs(FR.ranges(buf) or {}) do
      if r[1] == 5 and r[2] == 10 then
        return true
      end
    end
    return false
  end, 50)
  t.wait(300)
  vim.cmd("normal! zR")
  t.fold(6) -- parameters
  t.fold(9) -- body, over the folded parameters: the whole function
  t.check(
    "the whole function is folded",
    t.span(5) .. " " .. vim.fn.foldtextresult(5),
    "5..10 func h( ... ) (int, error) { ... }"
  )
  vim.api.nvim_win_set_cursor(win, { 5, 6 }) -- `(`
  key("l")
  t.check("onto the first dots: the parameters open", vim.fn.foldclosed(6), -1)
  t.check("the body stays folded", t.span(9), "8..10")
  t.check("cursor on the first parameter", cursor(), "6:1")
  vim.cmd("normal! zR")
  t.fold(6)
  t.fold(9)
  vim.api.nvim_win_set_cursor(win, { 8, 15 }) -- `{`
  key("l")
  t.check("onto the second dots: the body opens", vim.fn.foldclosed(9), -1)
  t.check("the parameters stay folded", t.span(6), "5..8")
  t.check("cursor on the first body line", cursor(), "9:1")
  vim.cmd("normal! zR")
  t.fold(6)
  t.fold(9)
  vim.api.nvim_win_set_cursor(win, { 10, 0 }) -- the `}` after the second dots
  key("h")
  t.check(
    "back onto the second dots: the body opens, parameters folded",
    vim.fn.foldclosed(9) .. " " .. t.span(6),
    "-1 5..8"
  )
  t.check("cursor at the end of the last body line", cursor(), "9:29")
  -- word motions go on past the line, into the buffer beyond the fold
  vim.cmd("normal! zR")
  t.fold(6)
  t.fold(9)
  vim.api.nvim_win_set_cursor(win, { 10, 0 }) -- the `}`
  key("e") -- next word start: nothing left on the line, `func` two lines down
  t.check("e past the fold's line: the next word in the buffer", cursor() .. " " .. vim.fn.foldclosed(5), "12:0 5")
  key("w") -- previous word start: back onto the fold line, its last word
  t.check("w back onto the fold: its last word", cursor() .. " " .. caret(), "8:8 e")
  -- and from an open line a motion never lands inside a closed fold: it
  -- lands on the fold's line
  vim.api.nvim_win_set_cursor(win, { 12, 5 }) -- `g`
  key("w") -- previous word start: `func`, then `error` on the fold line
  key("w")
  t.check(
    "w from below a closed fold: onto its line",
    cursor() .. " " .. caret() .. " " .. vim.fn.foldclosed(5),
    "8:8 e 5"
  )
  vim.api.nvim_win_set_cursor(win, { 3, 0 })
  key("b") -- next word end: `import`, `errors`, then the fold line's `func`
  key("b")
  key("b")
  t.check("b from above: onto the fold line's first word", cursor() .. " " .. caret(), "5:3 c")
  vim.api.nvim_win_set_cursor(win, { 4, 0 })
  key("E") -- next WORD start: the fold line's `func`, then its `h(`
  t.check("E from above: the fold line's first WORD", cursor() .. " " .. caret(), "5:0 f")
  key("E")
  t.check("E again: its second WORD", cursor() .. " " .. caret(), "5:5 h")
  -- x / X / r edit the caret's character with the fold closed; insert
  -- mode opens the fold (Vim) and it closes again after; v opens it to select
  vim.cmd("normal! zR")
  t.fold(6)
  vim.api.nvim_win_set_cursor(win, { 8, 5 }) -- the `t` of `(int, error)`
  key("l")
  t.check("caret on the comma", caret(), ",")
  key("x")
  t.check(
    "x deletes it, fold closed, caret on the next character",
    vim.fn.getline(8) .. " " .. t.span(8) .. " " .. caret(),
    ") (int error) { 5..8  "
  )
  key("X")
  t.check("X deletes the character before, caret stays", vim.fn.getline(8) .. " " .. caret(), ") (in error) {  ")
  key("r,")
  t.check("r replaces it", vim.fn.getline(8) .. " " .. caret() .. " " .. t.span(8), ") (in,error) { , 5..8")
  key("2x")
  t.check("a count", vim.fn.getline(8) .. " " .. caret(), ") (inrror) { r")
  key("iX<Esc>") -- insert before the caret's `r`: `inXrror`, still parsing
  vim.api.nvim_exec_autocmds("SafeState", {}) -- the fold closes again once idle
  moved() -- Esc here stays put, after the X (config/keymaps.lua)
  t.check(
    "insert at the caret, then the fold is closed again",
    vim.fn.getline(8) .. " " .. t.span(8),
    ") (inXrror) { 5..8"
  )
  t.check("caret back, after the inserted character (Esc stays put)", cursor() .. " " .. caret(), "8:6 r")
  key("v")
  t.check(
    "v opens the fold and selects from the caret",
    vim.api.nvim_get_mode().mode .. " " .. cursor() .. " " .. vim.fn.foldclosed(8),
    "v 8:6 -1"
  )
  key("<Esc>")
  vim.api.nvim_exec_autocmds("SafeState", {})
  -- (fed keys leave the cursor a column off here, unlike typed ones; the
  -- probe with real input lands on the X — so only the state is checked)
  t.check(
    "leaving visual mode: the fold closes again, caret back",
    t.span(8) .. " " .. (caret() ~= "none" and "caret" or "none"),
    "5..8 caret"
  )
  key("viwy") -- a quick yank of the word under the caret
  vim.api.nvim_exec_autocmds("SafeState", {})
  t.check("viwy: yanked", vim.fn.getreg('"'), "inXrror")
  t.check(
    "and the fold is closed again, caret at the word's start",
    t.span(8) .. " " .. cursor() .. " " .. caret(),
    "5..8 8:3 i"
  )
  key("<Esc>")
  vim.api.nvim_buf_set_lines(buf, 7, 8, false, { ") (int, error) {" })
  vim.wait(10000, function()
    for _, r in ipairs(FR.ranges(buf) or {}) do
      if r[1] == 5 and r[2] == 8 then
        return true
      end
    end
    return false
  end, 50)
  t.wait(300)
  -- ,d closing a fold around the cursor gives it the caret
  vim.cmd("normal! zR")
  vim.api.nvim_win_set_cursor(win, { 8, 5 })
  t.fold(8) -- the body, from its `) (int, error) {` line
  t.check(",d puts the caret where the cursor was", t.span(8) .. " " .. cursor() .. " " .. caret(), "8..10 8:5 t")
  -- $ / Shift-L into hidden text: the fold line ends in a ` ... ` or the
  -- dim closer behind it, so the end is inside: that last run opens
  vim.cmd("normal! zR")
  t.fold(6)
  t.fold(9) -- the whole function: `func h( ... ) (int, error) { ... }`
  vim.api.nvim_win_set_cursor(win, { 5, 0 })
  key("<S-l>")
  t.check("Shift-L on a line ending `{ ... }`: the body opens", vim.fn.foldclosed(9) .. " " .. t.span(6), "-1 5..8")
  t.check("cursor on the closing brace", cursor(), "10:0")
  vim.cmd("normal! zR")
  t.fold(15)
  vim.api.nvim_win_set_cursor(win, { 14, 0 })
  key("$")
  t.check(
    "$ on a line ending in dots: the fold opens, cursor at its end",
    vim.fn.foldclosed(14) .. " " .. cursor(),
    "-1 15:5"
  )
  vim.cmd("normal! zR")
  t.fold(6)
  vim.api.nvim_win_set_cursor(win, { 5, 0 })
  key("$")
  t.check("$ on a line ending in a real character: the caret", cursor() .. " " .. caret(), "8:15 {")
  vim.cmd("normal! zR")
  t.fold(6)
  t.fold(9)
  vim.api.nvim_win_set_cursor(win, { 11, 0 })
  key("h")
  t.check(
    "h from below a `{ ... }` line: the body opens",
    vim.fn.foldclosed(9) .. " " .. t.span(6) .. " " .. cursor(),
    "-1 5..8 10:0"
  )
  -- 'whichwrap' has h and l: off either end of the fold line they go to
  -- the line above / below, and from those lines back onto the fold's
  -- last / first drawn character
  t.check("whichwrap has h and l", vim.o.whichwrap:find("h") ~= nil and vim.o.whichwrap:find("l") ~= nil, true)
  vim.cmd("normal! zR")
  t.fold(6)
  vim.api.nvim_win_set_cursor(win, { 5, 0 })
  key("$")
  key("l")
  t.check("l off the end: the line below", cursor() .. " " .. caret(), "9:0 none")
  key("h")
  t.check("h from there: back onto the fold's last cell", cursor() .. " " .. caret(), "8:15 {")
  key("<S-h>")
  key("h")
  t.check("h off the start: the line above", cursor() .. " " .. caret(), "4:0 none")
  key("l")
  t.check("l from there: onto the fold's first cell", cursor() .. " " .. caret(), "5:0 f")
  key("3h")
  t.check("a count past the start wraps too", cursor(), "4:0")
  -- on a chain fold (`func h( ... ) (int, error) { ... }`) the same: the
  -- folds opened for the selection or the insert close again, innermost
  -- first, and the folds not on the cursor's path keep their state
  vim.cmd("normal! zR")
  t.fold(6)
  t.fold(9)
  vim.api.nvim_win_set_cursor(win, { 8, 7 })
  key("l") -- caret on `e` of error
  key("viwy")
  vim.api.nvim_exec_autocmds("SafeState", {})
  t.check("viwy on a chain fold: yanked", vim.fn.getreg('"'), "error")
  t.check(
    "and the chain is folded again with the same line",
    t.span(5) .. " " .. vim.fn.foldtextresult(5) .. " " .. caret(),
    "5..10 func h( ... ) (int, error) { ... } e"
  )
  key("iX<Esc>")
  vim.api.nvim_exec_autocmds("SafeState", {})
  moved()
  t.check("insert on a chain fold: folded again", t.span(5) .. " " .. vim.fn.getline(8), "5..10 ) (int, Xerror) {")
  t.check("caret after the inserted character", caret(), "e")
  vim.api.nvim_buf_set_lines(buf, 7, 8, false, { ") (int, error) {" })
  vim.wait(10000, function()
    for _, r in ipairs(FR.ranges(buf) or {}) do
      if r[1] == 5 and r[2] == 8 then
        return true
      end
    end
    return false
  end, 50)
  t.wait(300)
  -- a fold line ending in dots (a comment run): h from below opens it
  vim.cmd("normal! zR")
  t.fold(15)
  t.check("the comment run is folded", t.span(14) .. " " .. vim.fn.foldtextresult(14), "14..15 // one ...")
  vim.api.nvim_win_set_cursor(win, { 16, 0 })
  key("h")
  t.check("h from below onto the dots opens the fold", vim.fn.foldclosed(14), -1)
  t.check("at the end of its last line", cursor(), "15:5")
  vim.cmd("normal! zR")
  t.fold(6)
  t.fold(9) -- the whole function again
  -- arriving from another line, the caret takes the column the cursor
  -- was heading for, and keeps it for the next vertical move
  vim.api.nvim_win_set_cursor(win, { 3, 12 })
  moved()
  vim.cmd("normal! jj") -- Vim's own j: onto the fold
  moved()
  t.check("arriving on the fold: the caret at that column", cursor() .. " " .. caret(), "8:0 )")
  t.check("curswant kept at the drawn column", vim.fn.winsaveview().curswant, 12)
  vim.cmd("normal! j")
  moved()
  t.check("j off the fold keeps the column", cursor(), "11:0")
  vim.cmd("normal! k")
  moved()
  t.check("k back: the same caret", cursor() .. " " .. caret(), "8:0 )")
  vim.api.nvim_win_set_cursor(win, { 12, 0 })
  vim.cmd("normal! $")
  moved()
  vim.cmd("normal! kk")
  moved()
  t.check("arriving after $: the last cell", cursor() .. " " .. caret(), "10:0 }")
  vim.api.nvim_win_set_cursor(win, { 3, 9 }) -- column 10 is in the ` ... `
  moved()
  vim.cmd("normal! jj")
  moved()
  t.check(
    "a column in the dots: the cell before them, nothing opens",
    cursor() .. " " .. caret() .. " " .. vim.fn.foldclosed(5),
    "5:6 ( 5"
  )
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
