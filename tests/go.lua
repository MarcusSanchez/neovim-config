local dir = vim.fn.expand("%:p:h")
local logf = io.open(dir .. "/result.log", "w")
local function log(s) logf:write(s, "\n"); logf:flush() end
local function wait(ms) vim.wait(ms, function() return false end) end
local function key(k) vim.fn.maparg(k, "n", false, true).callback() end
local function keys(k) vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(k, true, false, true), "x", false) end
local function pos() local c = vim.api.nvim_win_get_cursor(0); return vim.fn.expand("%:t") .. ":" .. c[1] .. ":" .. c[2] end
local function check(name, got, want) log(("%s %s: %s (want %s)"):format(got == want and "PASS" or "FAIL", name, tostring(got), tostring(want))) end
-- other plugins (nvim-lint, lazy) notify too; look for ours anywhere
local function notified(list, msg) return vim.tbl_contains(list, msg) and msg or ("not among: " .. table.concat(list, " / ")) end
vim.defer_fn(function() log("TIMEOUT"); vim.cmd("qall!") end, 120000)
vim.schedule(function()
  local ok, err = pcall(function()
    vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
    vim.o.lines, vim.o.columns = 40, 120
    vim.wait(30000, function() return #vim.lsp.get_clients({ bufnr = 0, name = "gopls" }) > 0 and vim.fn.maparg("gd", "n", false, true).callback ~= nil end, 100)
    wait(2000)
    local notes = {}
    vim.notify = function(msg) notes[#notes + 1] = msg end
    -- gd: call site -> definition; definition -> popup (test usage hidden); single usage; tests-only fallback
    vim.api.nvim_win_set_cursor(0, { 11, 2 }); key("gd"); wait(1500); check("gd call site -> def", pos(), "main.go:5:5")
    vim.api.nvim_win_set_cursor(0, { 5, 6 }); key("gd"); wait(1500)
    local p = Snacks.picker.get()[1]
    check("popup rows (test usage hidden)", p and table.concat(vim.tbl_filter(function(l) return l ~= "" end, vim.api.nvim_buf_get_lines(p.list.win.buf, 0, -1, false)), "|"), " main.go:11  multi()| main.go:12  multi()")
    check("popup in normal mode on list", p and vim.api.nvim_get_mode().mode .. (vim.api.nvim_get_current_win() == p.list.win.win and "/list" or "/other"), "n/list")
    keys("k<CR>"); wait(800); check("k<CR> picks second usage", pos(), "main.go:12:1")
    vim.api.nvim_win_set_cursor(0, { 3, 6 }); key("gd"); wait(1500); check("single usage auto-jump", pos(), "main.go:10:1")
    check("single usage notice", notified(notes, "Only usage of `foobar`"), "Only usage of `foobar`")
    vim.api.nvim_win_set_cursor(0, { 7, 6 }); key("gd"); wait(1500); check("tests-only fallback jumps into test", pos(), "main_test.go:8:1")
    check("tests-only notice", notified(notes, "Only usage of `unused` is in test/generated code"), "Only usage of `unused` is in test/generated code")
    -- gh unwinds: main_test.go:8 -> 7:6 -> 10 -> 3:6 ... (tagstack)
    key("gh"); wait(300); check("gh #1", pos(), "main.go:7:6")
    key("gh"); wait(300); check("gh #2", pos(), "main.go:3:6")
    key("gh"); wait(300); check("gh #3", pos(), "main.go:5:6")
    key("gh"); wait(300); check("gh #4", pos(), "main.go:11:2")
    key("gh"); wait(300); check("gh empty stack notice", notified(notes, "No jump to go back to"), "No jump to go back to")
    -- Esc dismisses ge float + hover docs
    local ns = vim.api.nvim_create_namespace("suite")
    vim.diagnostic.set(ns, 0, { { lnum = 10, col = 1, end_col = 7, severity = vim.diagnostic.severity.ERROR, message = "grumpy" } })
    key("ge"); wait(200)
    local float = vim.b.lsp_floating_preview
    check("ge float styled", float and vim.wo[float].winhighlight, "Normal:CursorPopup,FloatBorder:CursorPopupBorder")
    keys("<Esc>"); wait(100); check("Esc closes ge float", vim.api.nvim_win_is_valid(float), false)
    -- a second ge focuses the float; Esc from inside must close it and return
    local src = vim.api.nvim_get_current_win()
    key("ge"); wait(100); key("ge"); wait(100)
    check("second ge focuses the float", vim.api.nvim_get_current_win() ~= src, true)
    float = vim.api.nvim_get_current_win()
    keys("<Esc>"); wait(100)
    check("Esc inside the float closes it", vim.api.nvim_win_is_valid(float), false)
    check("back in the source window", vim.api.nvim_get_current_win(), src)
    require("lazy").load({ plugins = { "noice.nvim" } }); wait(300)
    local docs = require("noice.lsp.docs"); local msg = docs.get("hover"); local hid = false
    docs.hide = function(m) hid = m == msg end; msg.win = function() return 1 end
    keys("<Esc>"); wait(100); check("Esc hides hover docs", hid, true)
    -- K inside a noice markdown buffer scrolls
    local mb = vim.api.nvim_create_buf(false, true); require("noice.text.markdown").keys(mb)
    check("K in hover buffer", vim.api.nvim_buf_call(mb, function() return vim.fn.maparg("K", "n", false, true).rhs end), "<C-D>")
    -- gd in the hover follows the nearest [label](file://...#L<n>) link
    local target = vim.fn.fnamemodify("main_test.go", ":p")
    vim.api.nvim_buf_set_lines(mb, 0, -1, false, { "func multi()", "", "Go to [Foo](file://" .. target .. "#L5) | [Bar](file://" .. target .. "#L2)" })
    -- an untagged float, like noice's hover window
    local mw = vim.api.nvim_open_win(mb, true, { relative = "cursor", row = 1, col = 0, width = 60, height = 3 })
    vim.api.nvim_win_set_cursor(mw, { 3, 8 }) -- inside [Foo]
    check("hover gd mapped", vim.fn.maparg("gd", "n", false, true).desc, "Goto Linked Definition")
    keys("gd"); wait(200)
    check("hover gd opened the linked file", vim.fn.expand("%:t") .. ":" .. vim.fn.line("."), "main_test.go:5")
    check("hover gd closed the float", vim.api.nvim_win_is_valid(mw), false)
    key("gh"); wait(200); check("gh returns from a hover link", vim.fn.expand("%:t"), "main.go")
    -- gd on an https link opens the browser and stays put
    local opened
    local ui_open = vim.ui.open
    vim.ui.open = function(url) opened = url end
    vim.api.nvim_buf_set_lines(mb, 0, -1, false, { "See [the docs](https://pkg.go.dev/testing) for more" })
    mw = vim.api.nvim_open_win(mb, true, { relative = "cursor", row = 1, col = 0, width = 60, height = 1 })
    vim.api.nvim_win_set_cursor(mw, { 1, 8 })
    keys("gd"); wait(100)
    check("hover gd on https opens the browser", opened, "https://pkg.go.dev/testing")
    check("hover gd on https leaves the hover open", vim.api.nvim_win_is_valid(mw), true)
    vim.ui.open = ui_open
    vim.api.nvim_win_close(mw, true)
    -- autosave: normal-mode change writes after 300ms without formatting; insert change doesn't
    vim.cmd("edit! main.go")
    local before = vim.fn.readfile("main.go")
    local fmt = {}
    vim.api.nvim_create_autocmd("BufWritePre", { callback = function(ev) fmt[#fmt + 1] = LazyVim.format.enabled(ev.buf) end })
    local posts = 0
    vim.api.nvim_create_autocmd("BufWritePost", { callback = function() posts = posts + 1 end })
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { "// x" }); vim.api.nvim_exec_autocmds("TextChangedI", { buffer = 0 }); wait(600)
    check("insert-mode change not saved while typing", vim.bo.modified, true)
    vim.api.nvim_exec_autocmds("InsertLeave", { buffer = 0 }); wait(50)
    check("saved immediately on leaving insert", vim.bo.modified, false)
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { "// y" })
    vim.api.nvim_exec_autocmds("TextChanged", { buffer = 0 }); wait(150); check("normal-mode edit: not yet at 150ms", vim.bo.modified, true)
    wait(400); check("normal-mode edit: saved after 300ms pause", vim.bo.modified, false)
    check("autosave skipped formatting (format flags per write)", vim.inspect(fmt), "{ false, false }")
    check("both autosaves fired BufWritePost (LSP didSave / nvim-lint)", posts, 2)
    vim.fn.writefile(before, "main.go")
    -- explorer helpers
    local ex = require("util.explorer"); check("explorer closed -> nil", ex.get(), nil)
    check("real window count", ex.real_window_count(), 1)
  end)
  log(ok and "DONE" or ("ERROR: " .. tostring(err)))
  vim.cmd("qall!")
end)
