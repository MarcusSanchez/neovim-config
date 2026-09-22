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
    key("<Esc>"); wait(100); check("Esc closes ge float", vim.api.nvim_win_is_valid(float), false)
    require("lazy").load({ plugins = { "noice.nvim" } }); wait(300)
    local docs = require("noice.lsp.docs"); local msg = docs.get("hover"); local hid = false
    docs.hide = function(m) hid = m == msg end; msg.win = function() return 1 end
    key("<Esc>"); check("Esc hides hover docs", hid, true)
    -- K inside a noice markdown buffer scrolls
    local mb = vim.api.nvim_create_buf(false, true); require("noice.text.markdown").keys(mb)
    check("K in hover buffer", vim.api.nvim_buf_call(mb, function() return vim.fn.maparg("K", "n", false, true).rhs end), "<C-D>")
    -- autosave: normal-mode change writes after 300ms without formatting; insert change doesn't
    vim.cmd("edit! main.go")
    local before = vim.fn.readfile("main.go")
    local fmt = {}
    vim.api.nvim_create_autocmd("BufWritePre", { callback = function(ev) fmt[#fmt + 1] = LazyVim.format.enabled(ev.buf) end })
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { "// x" }); vim.api.nvim_exec_autocmds("TextChangedI", { buffer = 0 }); wait(600)
    check("insert-mode change not saved", vim.bo.modified, true)
    vim.api.nvim_exec_autocmds("TextChanged", { buffer = 0 }); wait(150); check("not yet at 150ms", vim.bo.modified, true)
    wait(400); check("saved after 300ms pause", vim.bo.modified, false)
    check("autosave skipped formatting", fmt[1], false)
    vim.fn.writefile(before, "main.go")
    -- explorer helpers
    local ex = require("util.explorer"); check("explorer closed -> nil", ex.get(), nil)
    check("real window count", ex.real_window_count(), 1)
  end)
  log(ok and "DONE" or ("ERROR: " .. tostring(err)))
  vim.cmd("qall!")
end)
