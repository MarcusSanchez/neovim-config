-- The two tab-bar styles and the flip between them. Opens long.txt plus a
-- second buffer so the bar renders, then applies each style and checks the
-- highlight attributes that define it.
local logf = io.open(vim.fn.getcwd() .. "/result.log", "w")
local function log(s) logf:write(s, "\n"); logf:flush() end
local function check(name, got, want) log(("%s %s: %s (want %s)"):format(got == want and "PASS" or "FAIL", name, tostring(got), tostring(want))) end
vim.defer_fn(function() log("TIMEOUT"); vim.cmd("qall!") end, 30000)
vim.schedule(function()
  local ok, err = pcall(function()
    vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
    vim.o.columns = 100
    -- three tabs with the active one in the middle, so there's a divider
    -- after an inactive tab (bufferline draws none after the last tab)
    vim.fn.writefile({ "c" }, "third.txt")
    vim.cmd("edit folds.txt"); vim.cmd("edit long.txt"); vim.cmd("edit third.txt"); vim.cmd("buffer long.txt")
    local tabs = require("util.tabs")
    local function hl(name) return vim.api.nvim_get_hl(0, { name = name, link = false }) end
    local function hex(v) return v and ("#%06x"):format(v) or nil end
    local function render() return vim.api.nvim_eval_statusline(vim.o.tabline, { use_tabline = true }).str end
    check("default style", tabs.current, "attached")
    tabs.apply("attached")
    check("attached: baseline under the empty bar", hl("BufferLineFill").underline, true)
    check("attached: baseline under inactive tabs", hl("BufferLineBackground").underline, true)
    check("attached: baseline under dividers", hl("BufferLineSeparator").underline, true)
    check("attached: no baseline under the active tab", hl("BufferLineBufferSelected").underline, nil)
    check("attached: active tab tinted", hex(hl("BufferLineBufferSelected").bg), "#313244")
    check("attached: active tab's modified dot shares the tint", hex(hl("BufferLineModifiedSelected").bg), "#313244")
    check("attached: left wall drawn", render():find("▏", 1, true) ~= nil, true)
    check("attached: dividers drawn", render():find("│", 1, true) ~= nil, true)
    tabs.apply("accent")
    check("accent: active tab underlined", hl("BufferLineBufferSelected").underline, true)
    check("accent: underline is lavender", hex(hl("BufferLineBufferSelected").sp), "#b4befe")
    check("accent: underline spans the close button too", hl("BufferLineCloseButtonSelected").underline, true)
    check("accent: no baseline on the bar", hl("BufferLineFill").underline, nil)
    check("accent: no baseline under inactive tabs", hl("BufferLineBackground").underline, nil)
    tabs.toggle()
    check("toggle flips back", tabs.current, "attached")
    check("toggle re-applied the baseline", hl("BufferLineFill").underline, true)
    vim.cmd("TabStyle accent")
    check(":TabStyle switches", tabs.current, "accent")
    log("OK")
  end)
  log(ok and "DONE" or ("ERROR: " .. tostring(err)))
  vim.cmd("qall!")
end)
