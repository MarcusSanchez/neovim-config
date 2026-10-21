-- Flash on a closed fold (lua/util/flashfolds.lua): a match on the drawn
-- fold line is labelled there and jumped to with the caret, the fold kept
-- closed; a match in the hidden text doesn't exist — for `s` and for the
-- f/F motions flash owns. On the Go fixture with gopls.
local lib = dofile(debug.getinfo(1, "S").source:sub(2):match("^(.*)/[^/]*$") .. "/lib.lua")
lib.suite("gopls", function(t)
  local FT, FC = require("util.foldtext"), require("util.foldcursor")
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
  }, "sig.go")
  vim.cmd("edit sig.go")
  t.ranges()
  local win, buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
  vim.cmd("normal! zR")
  t.fold(6)
  t.check("the parameters are folded", t.span(5), "5..8")
  require("lazy").load({ plugins = { "flash.nvim" } })
  t.check("flash draws its labels through the fold line", FT.labels ~= nil, true)
  local function key(k)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(k, true, false, true), "x", false)
  end
  local function cursor()
    local c = vim.api.nvim_win_get_cursor(win)
    return c[1] .. ":" .. c[2]
  end
  local function fold_line() -- the fold line as drawn: its chunks
    return FT.render(FT.build(buf, 5, 8), FC.cell_at(win, buf, 5), 0, FT.labels(win, buf, 5))
  end
  local function caret() -- the caret's character on the fold line
    for _, c in ipairs(fold_line()) do
      if c[2] == "FoldCursor" then
        return c[1]
      end
    end
    return "none"
  end
  local function label() -- the flash label drawn on the fold line, "text@cell"
    local at = 0
    for _, c in ipairs(fold_line()) do
      if c[2] == "FlashLabel" then
        return c[1] .. "@" .. (at + 1)
      end
      at = at + vim.fn.strchars(c[1])
    end
    return "none"
  end
  local function cell_of(lnum, col)
    for i, c in ipairs(FT.cells(FT.build(buf, 5, 8))) do
      if c.lnum == lnum and c.col == col then
        return i
      end
    end
  end
  -- s: a flash search for `in` — the hidden parameters have two, the
  -- fold line's `(int,` one, the first line another
  vim.api.nvim_win_set_cursor(win, { 1, 0 })
  local st = require("flash.state").new({
    pattern = "in",
    labels = "abc",
    search = { multi_window = false, wrap = true, mode = "exact" },
    jump = { autojump = false },
  })
  local found, labelled = {}, nil
  for _, m in ipairs(st.results) do
    found[#found + 1] = m.pos[1] .. ":" .. m.pos[2] .. (m.cell and "+" or "")
    labelled = m.cell and m.label or labelled
  end
  t.check("matches: the open line's, the fold line's drawn one (+), none hidden", table.concat(found, " "), "1:10 8:3+")
  t.check("the fold line's match has a label", labelled ~= nil and labelled ~= "", true)
  t.check("drawn on the fold line, after the match", label(), tostring(labelled) .. "@" .. cell_of(8, 5))
  t.check(
    "the label stands in for the character after the match",
    vim.fn.foldtextresult(5),
    "func h( ... ) (in" .. tostring(labelled) .. ", error) {"
  )
  local matched
  for _, c in ipairs(fold_line()) do
    matched = (c[2] == "FlashMatch" or c[2] == "FlashCurrent") and c[1] or matched
  end
  t.check("the match itself is highlighted on the fold line (an extmark the builder reads)", matched, "in")
  st:jump(labelled)
  t.check(
    "the jump: the caret on `i`, the fold closed",
    cursor() .. " " .. caret() .. " " .. vim.fn.foldclosed(5),
    "8:3 i 5"
  )
  st:hide()
  t.check("the label goes with flash", label(), "none")
  -- f/F: flash's char motions from the caret, over the drawn line. Flash
  -- keeps a char motion's state for ; and , (and clever-f's f/F) until
  -- the cursor moves on; headless, that CursorMoved is emulated
  local function settle()
    vim.wait(20, function()
      return false
    end)
    vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
  end
  vim.api.nvim_win_set_cursor(win, { 5, 0 })
  key("fi")
  t.check(
    "f i: the drawn `i`, not a hidden parameter's",
    cursor() .. " " .. caret() .. " " .. vim.fn.foldclosed(5),
    "8:3 i 5"
  )
  settle()
  key("$")
  settle()
  key("Fh")
  t.check("F h: back on the first line's `h`", cursor() .. " " .. caret(), "5:5 h")
  settle()
  key("fb") -- the hidden `b int,` is skipped: the `b` of `a + b` below the fold
  t.check(
    "f b: the hidden parameter skipped, the `b` below the fold",
    cursor() .. " " .. vim.fn.foldclosed(5),
    "9:12 5"
  )
end)
