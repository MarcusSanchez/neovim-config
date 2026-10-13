-- The Go suite: gd/gh, the usages popup, autosave, hover and diagnostic
-- floats, the explorer helpers, and fold shapes with gopls
-- (tests/fixtures/go).
local lib = dofile(debug.getinfo(1, "S").source:sub(2):match("^(.*)/[^/]*$") .. "/lib.lua")
lib.suite("gopls", function(t)
  local function key(k)
    vim.fn.maparg(k, "n", false, true).callback()
  end
  local function keys(k)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(k, true, false, true), "x", false)
  end
  local function pos()
    local c = vim.api.nvim_win_get_cursor(0)
    return vim.fn.expand("%:t") .. ":" .. c[1] .. ":" .. c[2]
  end
  -- other plugins (nvim-lint, lazy) notify too; look for ours anywhere
  local function notified(list, msg)
    return vim.tbl_contains(list, msg) and msg or ("not among: " .. table.concat(list, " / "))
  end
  vim.wait(30000, function()
    return vim.fn.maparg("gd", "n", false, true).callback ~= nil
  end, 100)
  t.wait(2000)
  local notes = {}
  vim.notify = function(msg)
    notes[#notes + 1] = msg
  end
  -- gd: call site -> definition; definition -> popup (test usage hidden); single usage; tests-only fallback
  vim.api.nvim_win_set_cursor(0, { 11, 2 })
  key("gd")
  t.wait(1500)
  t.check("gd call site -> def", pos(), "main.go:5:5")
  vim.api.nvim_win_set_cursor(0, { 5, 6 })
  key("gd")
  t.wait(1500)
  local p = Snacks.picker.get()[1]
  t.check("popup rows (test usage hidden)", p and table.concat(
    vim.tbl_filter(function(l)
      return l ~= ""
    end, vim.api.nvim_buf_get_lines(p.list.win.buf, 0, -1, false)),
    "|"
  ), " main.go:11  multi()| main.go:12  multi()")
  t.check(
    "popup in normal mode on list",
    p and vim.api.nvim_get_mode().mode .. (vim.api.nvim_get_current_win() == p.list.win.win and "/list" or "/other"),
    "n/list"
  )
  keys("k<CR>")
  t.wait(800)
  t.check("k<CR> picks second usage", pos(), "main.go:12:1")
  vim.api.nvim_win_set_cursor(0, { 3, 6 })
  key("gd")
  t.wait(1500)
  t.check("single usage auto-jump", pos(), "main.go:10:1")
  t.check("single usage notice", notified(notes, "Only usage of `foobar`"), "Only usage of `foobar`")
  vim.api.nvim_win_set_cursor(0, { 7, 6 })
  key("gd")
  t.wait(1500)
  t.check("tests-only fallback jumps into test", pos(), "main_test.go:8:1")
  t.check(
    "tests-only notice",
    notified(notes, "Only usage of `unused` is in test/generated code"),
    "Only usage of `unused` is in test/generated code"
  )
  -- gh unwinds: main_test.go:8 -> 7:6 -> 10 -> 3:6 ... (tagstack)
  key("gh")
  t.wait(300)
  t.check("gh #1", pos(), "main.go:7:6")
  key("gh")
  t.wait(300)
  t.check("gh #2", pos(), "main.go:3:6")
  key("gh")
  t.wait(300)
  t.check("gh #3", pos(), "main.go:5:6")
  key("gh")
  t.wait(300)
  t.check("gh #4", pos(), "main.go:11:2")
  key("gh")
  t.wait(300)
  t.check("gh empty stack notice", notified(notes, "No jump to go back to"), "No jump to go back to")
  -- Esc dismisses ge float + hover docs
  local ns = vim.api.nvim_create_namespace("suite")
  vim.diagnostic.set(
    ns,
    0,
    { { lnum = 10, col = 1, end_col = 7, severity = vim.diagnostic.severity.ERROR, message = "grumpy" } }
  )
  key("ge")
  t.wait(200)
  local float = vim.b.lsp_floating_preview
  t.check("ge float styled", float and vim.wo[float].winhighlight, "Normal:CursorPopup,FloatBorder:CursorPopupBorder")
  keys("<Esc>")
  t.wait(100)
  t.check("Esc closes ge float", vim.api.nvim_win_is_valid(float), false)
  -- a second ge focuses the float; Esc from inside must close it and return
  local src = vim.api.nvim_get_current_win()
  key("ge")
  t.wait(100)
  key("ge")
  t.wait(100)
  t.check("second ge focuses the float", vim.api.nvim_get_current_win() ~= src, true)
  float = vim.api.nvim_get_current_win()
  keys("<Esc>")
  t.wait(100)
  t.check("Esc inside the float closes it", vim.api.nvim_win_is_valid(float), false)
  t.check("back in the source window", vim.api.nvim_get_current_win(), src)
  require("lazy").load({ plugins = { "noice.nvim" } })
  t.wait(300)
  local docs = require("noice.lsp.docs")
  -- gk opens noice's hover (its styled one, which replaces vim.lsp.buf.hover
  -- after the LSP keys spec is read — the key must look the function up
  -- when pressed, not capture it)
  vim.api.nvim_win_set_cursor(0, { 11, 2 })
  t.check("gk is the LSP hover key", vim.fn.maparg("gk", "n", false, true).desc, "LSP Hover")
  vim.fn.maparg("gk", "n", false, true).callback()
  vim.wait(5000, function()
    local m = docs.get("hover")
    return m and m:win() ~= nil
  end, 100)
  t.check("gk opens noice's hover window", docs.get("hover"):win() ~= nil, true)
  keys("<Esc>")
  t.wait(200)
  local msg = docs.get("hover")
  local hid = false
  docs.hide = function(m)
    hid = m == msg
  end
  msg.win = function()
    return 1
  end
  keys("<Esc>")
  t.wait(100)
  t.check("Esc hides hover docs", hid, true)
  -- K inside a noice markdown buffer scrolls
  local mb = vim.api.nvim_create_buf(false, true)
  require("noice.text.markdown").keys(mb)
  t.check(
    "K in hover buffer",
    vim.api.nvim_buf_call(mb, function()
      return vim.fn.maparg("K", "n", false, true).rhs
    end),
    "<C-D>"
  )
  -- gd in the hover follows the nearest [label](file://...#L<n>) link
  local target = vim.fn.fnamemodify("main_test.go", ":p")
  vim.api.nvim_buf_set_lines(
    mb,
    0,
    -1,
    false,
    { "func multi()", "", "Go to [Foo](file://" .. target .. "#L5) | [Bar](file://" .. target .. "#L2)" }
  )
  -- an untagged float, like noice's hover window
  local mw = vim.api.nvim_open_win(mb, true, { relative = "cursor", row = 1, col = 0, width = 60, height = 3 })
  vim.api.nvim_win_set_cursor(mw, { 3, 8 }) -- inside [Foo]
  t.check("hover gd mapped", vim.fn.maparg("gd", "n", false, true).desc, "Goto Linked Definition")
  keys("gd")
  t.wait(200)
  t.check("hover gd opened the linked file", vim.fn.expand("%:t") .. ":" .. vim.fn.line("."), "main_test.go:5")
  t.check("hover gd closed the float", vim.api.nvim_win_is_valid(mw), false)
  key("gh")
  t.wait(200)
  t.check("gh returns from a hover link", vim.fn.expand("%:t"), "main.go")
  -- gd on an https link opens the browser and stays put
  local opened
  local ui_open = vim.ui.open
  vim.ui.open = function(url)
    opened = url
  end
  vim.api.nvim_buf_set_lines(mb, 0, -1, false, { "See [the docs](https://pkg.go.dev/testing) for more" })
  mw = vim.api.nvim_open_win(mb, true, { relative = "cursor", row = 1, col = 0, width = 60, height = 1 })
  vim.api.nvim_win_set_cursor(mw, { 1, 8 })
  keys("gd")
  t.wait(100)
  t.check("hover gd on https opens the browser", opened, "https://pkg.go.dev/testing")
  t.check("hover gd on https leaves the hover open", vim.api.nvim_win_is_valid(mw), true)
  vim.ui.open = ui_open
  vim.api.nvim_win_close(mw, true)
  -- autosave: normal-mode change writes after 300ms without formatting; insert change doesn't
  vim.cmd("edit! main.go")
  local before = vim.fn.readfile("main.go")
  local fmt = {}
  vim.api.nvim_create_autocmd("BufWritePre", {
    callback = function(ev)
      fmt[#fmt + 1] = LazyVim.format.enabled(ev.buf)
    end,
  })
  local posts = 0
  vim.api.nvim_create_autocmd("BufWritePost", {
    callback = function()
      posts = posts + 1
    end,
  })
  vim.api.nvim_buf_set_lines(0, -1, -1, false, { "// x" })
  vim.api.nvim_exec_autocmds("TextChangedI", { buffer = 0 })
  t.wait(600)
  t.check("insert-mode change not saved while typing", vim.bo.modified, true)
  vim.api.nvim_exec_autocmds("InsertLeave", { buffer = 0 })
  t.wait(50)
  t.check("saved immediately on leaving insert", vim.bo.modified, false)
  vim.api.nvim_buf_set_lines(0, -1, -1, false, { "// y" })
  vim.api.nvim_exec_autocmds("TextChanged", { buffer = 0 })
  t.wait(150)
  t.check("normal-mode edit: not yet at 150ms", vim.bo.modified, true)
  t.wait(400)
  t.check("normal-mode edit: saved after 300ms pause", vim.bo.modified, false)
  t.check("autosave skipped formatting (format flags per write)", vim.inspect(fmt), "{ false, false }")
  t.check("both autosaves fired BufWritePost (LSP didSave / nvim-lint)", posts, 2)
  vim.fn.writefile(before, "main.go")
  -- folds come from gopls' ranges once they arrive (util/foldranges.lua),
  -- normalised so a fold hides its closing brace
  t.fold(9)
  t.check(",d on func main folds through its closing brace", t.span(9), "9..13")
  t.check("the } line is inside the fold", vim.fn.getline(13), "}")
  t.check("fold line reads like IntelliJ", vim.fn.foldtextresult(9), "func main() { ... }")
  -- the fold line keeps the open line's colours: rainbow brackets included
  -- (rainbow-delimiters attaches on FileType, which fired before it loaded
  -- in this headless run — attach it by hand, as a real session would have)
  pcall(function()
    require("rainbow-delimiters.lib").attach(0)
  end)
  t.wait(500)
  local chunks
  _G.__fold_probe = function()
    chunks = require("util.foldtext").text()
    return chunks
  end
  local ft = vim.wo.foldtext
  vim.wo.foldtext = "v:lua.__fold_probe()"
  vim.fn.foldtextresult(9)
  vim.wo.foldtext = ft
  local groups = {}
  for _, c in ipairs(chunks or {}) do
    groups[c[1]] = c[2]
  end
  -- gopls' semantic token wins over the treesitter capture, as on the open line
  t.check("fold line: func keyword highlighted", (groups["func"] or ""):match("keyword") ~= nil, true)
  t.check("fold line: () in rainbow colour", (groups["()"] or ""):match("^RainbowDelimiter") ~= nil, true)
  t.check("fold line: the { the fold hides behind is dim like the tail", groups["{"], "FoldEllipsis")
  t.check("fold line: ellipsis dim", groups[" ... "], "FoldEllipsis")
  -- a closer on the fold's last line that pairs with an opener visible on
  -- the first line keeps that opener's colour; only the hidden block's
  -- closer is dim: `x := g(1, func() int { ... })`
  vim.fn.writefile({
    "package main",
    "",
    "func g(int, func() int) int { return 0 }",
    "",
    "func f() {",
    "\tx := g(1, func() int {",
    "\t\treturn 2",
    "\t})",
    "\t_ = x",
    "}",
  }, "lit.go")
  vim.cmd("edit lit.go")
  local nb = vim.api.nvim_get_current_buf()
  pcall(function()
    require("rainbow-delimiters.lib").attach(0)
  end)
  t.ranges()
  t.fold(6)
  t.check("literal fold reads right", vim.fn.foldtextresult(6), "    x := g(1, func() int { ... })")
  chunks = nil
  vim.wo.foldtext = "v:lua.__fold_probe()"
  vim.fn.foldtextresult(6)
  vim.wo.foldtext = ft
  local n = #chunks
  t.check("hidden block's } is dim", chunks[n - 1][1] .. "=" .. chunks[n - 1][2], "}=FoldEllipsis")
  local g_open
  for i, c in ipairs(chunks) do
    if c[1] == "g" and chunks[i + 1] and chunks[i + 1][1]:sub(1, 1) == "(" then
      g_open = chunks[i + 1][2]
    end
  end
  t.check("visible ( has a colour", g_open ~= nil and g_open ~= "FoldEllipsis", true)
  t.check("its ) on the fold line takes the same colour", chunks[n][1] .. "=" .. chunks[n][2], ")=" .. tostring(g_open))
  -- a wrapped signature: the fold line shows where the `(` closes too
  vim.fn.writefile(
    { "package main", "", "func h(", "\ta int,", "\tb int,", ") int {", "\treturn a + b", "}" },
    "sig.go"
  )
  vim.cmd("edit sig.go")
  local gb = vim.api.nvim_get_current_buf()
  t.ranges()
  -- the parameter list is its own fold: ,d on `func h(` folds just it,
  -- through its closing `) int {` line (the body that opens there folds
  -- with the whole function: a line belongs to one fold)
  t.fold(3)
  t.check(",d on the signature folds the parameters only", t.span(3), "3..6")
  t.check("parameters fold line", vim.fn.foldtextresult(3), "func h( ... ) int {")
  vim.wo.foldtext = "v:lua.__fold_probe()"
  vim.fn.foldtextresult(3)
  vim.wo.foldtext = ft
  local after, got = false, {}
  for _, c in ipairs(chunks) do
    if c[1] == " ... " then
      after = true
    elseif after and (c[1] == ")" or c[1] == "{") then
      got[c[1]] = c[2]
    end
  end
  t.check("its ) is dim like the ( it pairs with", got[")"], "FoldEllipsis")
  t.check("the { opening the visible body is not dim", got["{"] ~= nil and got["{"] ~= "FoldEllipsis", true)
  -- ,d on the closed fold opens it
  t.fold(3)
  t.check(",d again opens the parameters", vim.fn.foldclosed(3), -1)
  -- the body folds on its own from its `) int {` line, parameters open
  t.fold(7)
  t.check(",d in the body folds the body only", t.span(7), "6..8")
  t.check("body fold line", vim.fn.foldtextresult(6), ") int { ... }")
  t.check("the parameters stay open above it", vim.fn.foldclosed(3), -1)
  -- folding the parameters while the body is folded: the whole function
  t.fold(3)
  t.check("parameters over a folded body: the whole function", t.span(3), "3..8")
  t.check("whole-function fold line", vim.fn.foldtextresult(3), "func h( ... ) int { ... }")
  -- opening it leaves the body folded
  t.fold(3)
  t.check("opening the function keeps the body folded", t.span(6), "6..8")
  t.check("and the signature open", vim.fn.foldclosed(3), -1)
  vim.cmd("normal! zR")
  vim.cmd("buffer main.go")
  vim.api.nvim_buf_delete(gb, { force = true })
  vim.fn.delete("sig.go")
  -- a closing line that goes on after its closers (`}, log)`) joins the
  -- fold, and the fold line renders the rest of it once
  vim.fn.writefile(
    { "package main", "", "func f() {", "\tsender, err := mail.New(mail.Config{", "\t\tDriver: 1,", "\t}, log)", "}" },
    "rest.go"
  )
  vim.cmd("edit rest.go")
  local rb = vim.api.nvim_get_current_buf()
  t.ranges()
  t.fold(5)
  t.check(",d inside a composite literal folds through `}, log)`", t.span(5), "4..6")
  t.check("its fold line", vim.fn.foldtextresult(4), "    sender, err := mail.New(mail.Config{ ... }, log)")
  vim.cmd("normal! zR")
  vim.cmd("buffer main.go")
  vim.api.nvim_buf_delete(rb, { force = true })
  vim.fn.delete("rest.go")
  -- wrapped call arguments fold on their own, from inside them too
  vim.fn.writefile(
    { "package main", "", "func f() {", "\tsrv := server.New(", "\t\tdb,", "\t\tenc,", "\t)", "}" },
    "args.go"
  )
  vim.cmd("edit args.go")
  local ab = vim.api.nvim_get_current_buf()
  t.ranges()
  t.fold(6)
  t.check(",d inside wrapped arguments folds them through `)`", t.span(6), "4..7")
  t.check("argument fold line", vim.fn.foldtextresult(4), "    srv := server.New( ... )")
  vim.cmd("normal! zR")
  vim.cmd("buffer main.go")
  vim.api.nvim_buf_delete(ab, { force = true })
  vim.fn.delete("args.go")
  -- an import block is folded when the file opens (gopls' imports kind)
  vim.fn.writefile(
    { "package main", "", "import (", '\t"context"', '\t"fmt"', ")", "", "var _ = fmt.Sprint(context.TODO())" },
    "imp.go"
  )
  vim.cmd("edit imp.go")
  local ib = vim.api.nvim_get_current_buf()
  t.ranges()
  t.check("imports fold on open", t.span(4), "3..6")
  t.check("imports fold line", vim.fn.foldtextresult(3), "import ( ... )")
  t.check("the rest of the file is open", vim.fn.foldclosed(8), -1)
  -- a fold that appears after an edit must come out open: Vim creates it
  -- closed while another fold (the imports) is closed
  vim.fn.append(8, { "func g() {", "\tfmt.Print()", "}" })
  vim.wait(5000, function()
    return vim.fn.foldlevel(10) > 0
  end, 50)
  t.wait(300)
  t.check("a region added by an edit is open", vim.fn.foldclosed(9), -1)
  t.check("the imports stay folded", t.span(4), "3..6")
  vim.cmd("normal! zR")
  vim.cmd("buffer main.go")
  vim.api.nvim_buf_delete(ib, { force = true })
  vim.fn.delete("imp.go")
  -- a folded error check reads as a one-liner, `{ return err }` dim
  vim.fn.writefile({
    "package main",
    "",
    "func f() error {",
    "\tif err := g(); err != nil {",
    "\t\treturn err",
    "\t}",
    "\tif err := g(); err != nil {",
    '\t\treturn fmt.Errorf("g: %w", err)',
    "\t}",
    "\tif true {",
    "\t\treturn nil",
    "\t}",
    "\treturn nil",
    "}",
  }, "ret.go")
  vim.cmd("edit ret.go")
  local eb = vim.api.nvim_get_current_buf()
  t.ranges()
  t.fold(5)
  t.check(
    "a folded `return err` check is a one-liner",
    vim.fn.foldtextresult(4),
    "    if err := g(); err != nil { return err }"
  )
  chunks = nil
  vim.wo.foldtext = "v:lua.__fold_probe()"
  vim.fn.foldtextresult(4)
  vim.wo.foldtext = ft
  t.check(
    "`{ return err }` is one dim chunk",
    chunks[#chunks][1] .. "=" .. chunks[#chunks][2],
    "{ return err }=FoldEllipsis"
  )
  t.check("the condition keeps its colours", chunks[2][2] ~= "FoldEllipsis", true)
  t.fold(8)
  t.check(
    "a wrapped error return inlines too",
    vim.fn.foldtextresult(7),
    '    if err := g(); err != nil { return fmt.Errorf("g: %w", err) }'
  )
  t.fold(11)
  t.check("a body without err folds the usual way", vim.fn.foldtextresult(10), "    if true { ... }")
  vim.cmd("normal! zR")
  vim.cmd("buffer main.go")
  vim.api.nvim_buf_delete(eb, { force = true })
  vim.fn.delete("ret.go")
  -- a block comment folds with its closer: `/* ... */`
  vim.fn.writefile({ "package main", "", "/*", "Package doc", "spanning lines", "*/", "func f() {}" }, "blk.go")
  vim.cmd("edit blk.go")
  local kb = vim.api.nvim_get_current_buf()
  t.ranges()
  t.fold(4)
  t.check("a block comment folds through its closer", t.span(4), "3..6")
  t.check("block comment fold line", vim.fn.foldtextresult(3), "/* ... */")
  vim.cmd("normal! zR")
  vim.cmd("buffer main.go")
  vim.api.nvim_buf_delete(kb, { force = true })
  vim.fn.delete("blk.go")
  -- a folded multi-line string closes its quote on the fold line
  vim.fn.writefile(
    { "package main", "", "var q = `", "select 1", "`", "", "var r = []string{`", "a", '`, "b"}' },
    "str.go"
  )
  vim.cmd("edit str.go")
  local sb = vim.api.nvim_get_current_buf()
  t.ranges()
  t.fold(3)
  t.check("folded raw string shows its closing quote", vim.fn.foldtextresult(3), "var q = ` ... `")
  chunks = nil
  vim.wo.foldtext = "v:lua.__fold_probe()"
  vim.fn.foldtextresult(3)
  vim.wo.foldtext = ft
  t.check("both quotes dim like the dots", chunks[#chunks][1] .. "=" .. chunks[#chunks][2] .. " " .. (function()
    for i = #chunks, 1, -1 do
      if chunks[i][1] == "`" and i < #chunks - 1 then
        return chunks[i][2]
      end
    end
  end)(), "`=FoldEllipsis FoldEllipsis")
  vim.cmd("normal! zR")
  vim.cmd("buffer main.go")
  vim.api.nvim_buf_delete(sb, { force = true })
  vim.fn.delete("str.go")
  vim.cmd("normal! zR")
  vim.cmd("buffer main.go")
  vim.api.nvim_buf_delete(nb, { force = true })
  vim.fn.delete("lit.go")
  vim.cmd("normal! zR")
  -- explorer helpers
  local ex = require("util.explorer")
  t.check("explorer closed -> nil", ex.get(), nil)
  local wins = {}
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    local b = vim.api.nvim_win_get_buf(w)
    wins[#wins + 1] = ("%s%s[%s]"):format(
      vim.api.nvim_win_get_config(w).relative ~= "" and "float:" or "",
      vim.fn.fnamemodify(vim.api.nvim_buf_get_name(b), ":t"),
      vim.bo[b].filetype
    )
  end
  t.log("  windows: " .. table.concat(wins, " "))
  t.check("real window count", ex.real_window_count(), 1)
end)
