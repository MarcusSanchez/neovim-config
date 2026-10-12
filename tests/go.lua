local dir = vim.fn.expand("%:p:h")
local logf = io.open(dir .. "/result.log", "w")
local function log(s)
  logf:write(s, "\n")
  logf:flush()
end
local function wait(ms)
  vim.wait(ms, function()
    return false
  end)
end
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
local function check(name, got, want)
  log(("%s %s: %s (want %s)"):format(got == want and "PASS" or "FAIL", name, tostring(got), tostring(want)))
end
-- other plugins (nvim-lint, lazy) notify too; look for ours anywhere
local function notified(list, msg)
  return vim.tbl_contains(list, msg) and msg or ("not among: " .. table.concat(list, " / "))
end
vim.defer_fn(function()
  log("TIMEOUT")
  vim.cmd("qall!")
end, 120000)
vim.schedule(function()
  local ok, err = pcall(function()
    vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
    vim.o.lines, vim.o.columns = 40, 120
    vim.wait(30000, function()
      return #vim.lsp.get_clients({ bufnr = 0, name = "gopls" }) > 0
        and vim.fn.maparg("gd", "n", false, true).callback ~= nil
    end, 100)
    wait(2000)
    local notes = {}
    vim.notify = function(msg)
      notes[#notes + 1] = msg
    end
    -- gd: call site -> definition; definition -> popup (test usage hidden); single usage; tests-only fallback
    vim.api.nvim_win_set_cursor(0, { 11, 2 })
    key("gd")
    wait(1500)
    check("gd call site -> def", pos(), "main.go:5:5")
    vim.api.nvim_win_set_cursor(0, { 5, 6 })
    key("gd")
    wait(1500)
    local p = Snacks.picker.get()[1]
    check(
      "popup rows (test usage hidden)",
      p
        and table.concat(
          vim.tbl_filter(function(l)
            return l ~= ""
          end, vim.api.nvim_buf_get_lines(p.list.win.buf, 0, -1, false)),
          "|"
        ),
      " main.go:11  multi()| main.go:12  multi()"
    )
    check(
      "popup in normal mode on list",
      p and vim.api.nvim_get_mode().mode .. (vim.api.nvim_get_current_win() == p.list.win.win and "/list" or "/other"),
      "n/list"
    )
    keys("k<CR>")
    wait(800)
    check("k<CR> picks second usage", pos(), "main.go:12:1")
    vim.api.nvim_win_set_cursor(0, { 3, 6 })
    key("gd")
    wait(1500)
    check("single usage auto-jump", pos(), "main.go:10:1")
    check("single usage notice", notified(notes, "Only usage of `foobar`"), "Only usage of `foobar`")
    vim.api.nvim_win_set_cursor(0, { 7, 6 })
    key("gd")
    wait(1500)
    check("tests-only fallback jumps into test", pos(), "main_test.go:8:1")
    check(
      "tests-only notice",
      notified(notes, "Only usage of `unused` is in test/generated code"),
      "Only usage of `unused` is in test/generated code"
    )
    -- gh unwinds: main_test.go:8 -> 7:6 -> 10 -> 3:6 ... (tagstack)
    key("gh")
    wait(300)
    check("gh #1", pos(), "main.go:7:6")
    key("gh")
    wait(300)
    check("gh #2", pos(), "main.go:3:6")
    key("gh")
    wait(300)
    check("gh #3", pos(), "main.go:5:6")
    key("gh")
    wait(300)
    check("gh #4", pos(), "main.go:11:2")
    key("gh")
    wait(300)
    check("gh empty stack notice", notified(notes, "No jump to go back to"), "No jump to go back to")
    -- Esc dismisses ge float + hover docs
    local ns = vim.api.nvim_create_namespace("suite")
    vim.diagnostic.set(
      ns,
      0,
      { { lnum = 10, col = 1, end_col = 7, severity = vim.diagnostic.severity.ERROR, message = "grumpy" } }
    )
    key("ge")
    wait(200)
    local float = vim.b.lsp_floating_preview
    check("ge float styled", float and vim.wo[float].winhighlight, "Normal:CursorPopup,FloatBorder:CursorPopupBorder")
    keys("<Esc>")
    wait(100)
    check("Esc closes ge float", vim.api.nvim_win_is_valid(float), false)
    -- a second ge focuses the float; Esc from inside must close it and return
    local src = vim.api.nvim_get_current_win()
    key("ge")
    wait(100)
    key("ge")
    wait(100)
    check("second ge focuses the float", vim.api.nvim_get_current_win() ~= src, true)
    float = vim.api.nvim_get_current_win()
    keys("<Esc>")
    wait(100)
    check("Esc inside the float closes it", vim.api.nvim_win_is_valid(float), false)
    check("back in the source window", vim.api.nvim_get_current_win(), src)
    require("lazy").load({ plugins = { "noice.nvim" } })
    wait(300)
    local docs = require("noice.lsp.docs")
    local msg = docs.get("hover")
    local hid = false
    docs.hide = function(m)
      hid = m == msg
    end
    msg.win = function()
      return 1
    end
    keys("<Esc>")
    wait(100)
    check("Esc hides hover docs", hid, true)
    -- K inside a noice markdown buffer scrolls
    local mb = vim.api.nvim_create_buf(false, true)
    require("noice.text.markdown").keys(mb)
    check(
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
    check("hover gd mapped", vim.fn.maparg("gd", "n", false, true).desc, "Goto Linked Definition")
    keys("gd")
    wait(200)
    check("hover gd opened the linked file", vim.fn.expand("%:t") .. ":" .. vim.fn.line("."), "main_test.go:5")
    check("hover gd closed the float", vim.api.nvim_win_is_valid(mw), false)
    key("gh")
    wait(200)
    check("gh returns from a hover link", vim.fn.expand("%:t"), "main.go")
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
    wait(100)
    check("hover gd on https opens the browser", opened, "https://pkg.go.dev/testing")
    check("hover gd on https leaves the hover open", vim.api.nvim_win_is_valid(mw), true)
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
    wait(600)
    check("insert-mode change not saved while typing", vim.bo.modified, true)
    vim.api.nvim_exec_autocmds("InsertLeave", { buffer = 0 })
    wait(50)
    check("saved immediately on leaving insert", vim.bo.modified, false)
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { "// y" })
    vim.api.nvim_exec_autocmds("TextChanged", { buffer = 0 })
    wait(150)
    check("normal-mode edit: not yet at 150ms", vim.bo.modified, true)
    wait(400)
    check("normal-mode edit: saved after 300ms pause", vim.bo.modified, false)
    check("autosave skipped formatting (format flags per write)", vim.inspect(fmt), "{ false, false }")
    check("both autosaves fired BufWritePost (LSP didSave / nvim-lint)", posts, 2)
    vim.fn.writefile(before, "main.go")
    -- folds come from gopls' ranges once they arrive (util/foldranges.lua),
    -- normalised so a fold hides its closing brace
    local FR = require("util.foldranges")
    local function server_folds()
      vim.wait(15000, function()
        return FR.has(0)
      end, 50)
      wait(300)
      return FR.has(0)
    end
    check("the fold expression is ours", vim.wo.foldexpr, "v:lua.require('util.foldranges').foldexpr()")
    check("folds come from gopls", server_folds(), true)
    local function fold(l) -- ,d on line l
      vim.cmd(("normal! %dG"):format(l))
      FR.toggle()
    end
    fold(9)
    check(
      ",d on func main folds through its closing brace",
      vim.fn.foldclosed(9) .. ".." .. vim.fn.foldclosedend(9),
      "9..13"
    )
    check("the } line is inside the fold", vim.fn.getline(13), "}")
    check("fold line reads like IntelliJ", vim.fn.foldtextresult(9), "func main() { ... }")
    -- the fold line keeps the open line's colours: rainbow brackets included
    -- (rainbow-delimiters attaches on FileType, which fired before it loaded
    -- in this headless run — attach it by hand, as a real session would have)
    pcall(function()
      require("rainbow-delimiters.lib").attach(0)
    end)
    wait(500)
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
    check("fold line: func keyword highlighted", (groups["func"] or ""):match("keyword") ~= nil, true)
    check("fold line: () in rainbow colour", (groups["()"] or ""):match("^RainbowDelimiter") ~= nil, true)
    check("fold line: the { the fold hides behind is dim like the tail", groups["{"], "FoldEllipsis")
    check("fold line: ellipsis dim", groups[" ... "], "FoldEllipsis")
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
    server_folds()
    fold(6)
    check("literal fold reads right", vim.fn.foldtextresult(6), "    x := g(1, func() int { ... })")
    chunks = nil
    vim.wo.foldtext = "v:lua.__fold_probe()"
    vim.fn.foldtextresult(6)
    vim.wo.foldtext = ft
    local n = #chunks
    check("hidden block's } is dim", chunks[n - 1][1] .. "=" .. chunks[n - 1][2], "}=FoldEllipsis")
    local g_open
    for i, c in ipairs(chunks) do
      if c[1] == "g" and chunks[i + 1] and chunks[i + 1][1]:sub(1, 1) == "(" then
        g_open = chunks[i + 1][2]
      end
    end
    check("visible ( has a colour", g_open ~= nil and g_open ~= "FoldEllipsis", true)
    check("its ) on the fold line takes the same colour", chunks[n][1] .. "=" .. chunks[n][2], ")=" .. tostring(g_open))
    -- a wrapped signature: the fold line shows where the `(` closes too
    vim.fn.writefile(
      { "package main", "", "func h(", "\ta int,", "\tb int,", ") int {", "\treturn a + b", "}" },
      "sig.go"
    )
    vim.cmd("edit sig.go")
    local gb = vim.api.nvim_get_current_buf()
    server_folds()
    -- the parameter list is its own fold: zc on `func h(` folds just it,
    -- through its closing `) int {` line (the body that opens there folds
    -- with the whole function: a line belongs to one fold)
    fold(3)
    check(
      ",d on the signature folds the parameters only",
      vim.fn.foldclosed(3) .. ".." .. vim.fn.foldclosedend(3),
      "3..6"
    )
    check("parameters fold line", vim.fn.foldtextresult(3), "func h( ... ) int {")
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
    check("its ) is dim like the ( it pairs with", got[")"], "FoldEllipsis")
    check("the { opening the visible body is not dim", got["{"] ~= nil and got["{"] ~= "FoldEllipsis", true)
    -- ,d on the closed fold opens it
    fold(3)
    check(",d again opens the parameters", vim.fn.foldclosed(3), -1)
    -- the body folds on its own from its `) int {` line, parameters open
    fold(7)
    check(",d in the body folds the body only", vim.fn.foldclosed(7) .. ".." .. vim.fn.foldclosedend(7), "6..8")
    check("body fold line", vim.fn.foldtextresult(6), ") int { ... }")
    check("the parameters stay open above it", vim.fn.foldclosed(3), -1)
    -- folding the parameters while the body is folded: the whole function
    fold(3)
    check(
      "parameters over a folded body: the whole function",
      vim.fn.foldclosed(3) .. ".." .. vim.fn.foldclosedend(3),
      "3..8"
    )
    check("whole-function fold line", vim.fn.foldtextresult(3), "func h( ... ) int { ... }")
    -- opening it leaves the body folded
    fold(3)
    check("opening the function keeps the body folded", vim.fn.foldclosed(6) .. ".." .. vim.fn.foldclosedend(6), "6..8")
    check("and the signature open", vim.fn.foldclosed(3), -1)
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
    server_folds()
    fold(5)
    check(
      ",d inside a composite literal folds through `}, log)`",
      vim.fn.foldclosed(5) .. ".." .. vim.fn.foldclosedend(5),
      "4..6"
    )
    check("its fold line", vim.fn.foldtextresult(4), "    sender, err := mail.New(mail.Config{ ... }, log)")
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
    server_folds()
    fold(6)
    check(
      ",d inside wrapped arguments folds them through `)`",
      vim.fn.foldclosed(6) .. ".." .. vim.fn.foldclosedend(6),
      "4..7"
    )
    check("argument fold line", vim.fn.foldtextresult(4), "    srv := server.New( ... )")
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
    server_folds()
    check("imports fold on open", vim.fn.foldclosed(4) .. ".." .. vim.fn.foldclosedend(4), "3..6")
    check("imports fold line", vim.fn.foldtextresult(3), "import ( ... )")
    check("the rest of the file is open", vim.fn.foldclosed(8), -1)
    -- a fold that appears after an edit must come out open: Vim creates it
    -- closed while another fold (the imports) is closed
    vim.fn.append(8, { "func g() {", "\tfmt.Print()", "}" })
    vim.wait(5000, function()
      return vim.fn.foldlevel(10) > 0
    end, 50)
    wait(300)
    check("a region added by an edit is open", vim.fn.foldclosed(9), -1)
    check("the imports stay folded", vim.fn.foldclosed(4) .. ".." .. vim.fn.foldclosedend(4), "3..6")
    vim.cmd("normal! zR")
    vim.cmd("buffer main.go")
    vim.api.nvim_buf_delete(ib, { force = true })
    vim.fn.delete("imp.go")
    -- a block comment folds with its closer: `/* ... */`
    vim.fn.writefile({ "package main", "", "/*", "Package doc", "spanning lines", "*/", "func f() {}" }, "blk.go")
    vim.cmd("edit blk.go")
    local kb = vim.api.nvim_get_current_buf()
    server_folds()
    fold(4)
    check("a block comment folds through its closer", vim.fn.foldclosed(4) .. ".." .. vim.fn.foldclosedend(4), "3..6")
    check("block comment fold line", vim.fn.foldtextresult(3), "/* ... */")
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
    server_folds()
    fold(3)
    check("folded raw string shows its closing quote", vim.fn.foldtextresult(3), "var q = ` ... `")
    chunks = nil
    vim.wo.foldtext = "v:lua.__fold_probe()"
    vim.fn.foldtextresult(3)
    vim.wo.foldtext = ft
    check("both quotes dim like the dots", chunks[#chunks][1] .. "=" .. chunks[#chunks][2] .. " " .. (function()
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
    check("explorer closed -> nil", ex.get(), nil)
    local wins = {}
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      local b = vim.api.nvim_win_get_buf(w)
      wins[#wins + 1] = ("%s%s[%s]"):format(
        vim.api.nvim_win_get_config(w).relative ~= "" and "float:" or "",
        vim.fn.fnamemodify(vim.api.nvim_buf_get_name(b), ":t"),
        vim.bo[b].filetype
      )
    end
    log("  windows: " .. table.concat(wins, " "))
    check("real window count", ex.real_window_count(), 1)
  end)
  log(ok and "DONE" or ("ERROR: " .. tostring(err)))
  vim.cmd("qall!")
end)
