-- The hollow-pill tab styles and the cycle between them. Three tabs with
-- the active one in the middle; each preset is applied and the attributes
-- that define it are checked. Caps are Nerd Font glyphs: ( ) outlined,
-- [ ] filled, in the checks below.
local logf = io.open(vim.fn.getcwd() .. "/result.log", "w")
local function log(s) logf:write(s, "\n"); logf:flush() end
local function check(name, got, want) log(("%s %s: %s (want %s)"):format(got == want and "PASS" or "FAIL", name, tostring(got), tostring(want))) end
vim.defer_fn(function() log("TIMEOUT"); vim.cmd("qall!") end, 40000)
vim.schedule(function()
  local ok, err = pcall(function()
    vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
    vim.o.columns = 100
    vim.fn.writefile({ "c" }, "third.txt")
    vim.cmd("edit folds.txt"); vim.cmd("edit long.txt"); vim.cmd("edit third.txt"); vim.cmd("buffer long.txt")
    local tabs = require("util.tabs")
    local function hl(name) return vim.api.nvim_get_hl(0, { name = name, link = false }) end
    local function hex(v) return v and ("#%06x"):format(v) or nil end
    local function render()
      local s = vim.api.nvim_eval_statusline(vim.o.tabline, { use_tabline = true }).str
      return (s:gsub("\u{e0b7}", "("):gsub("\u{e0b5}", ")"):gsub("\u{e0b6}", "["):gsub("\u{e0b4}", "]"))
    end
    local function count(s, ch) return select(2, s:gsub("%" .. ch, "")) end
    check("default style", tabs.current, "classic")
    check("the cycle key is not LazyVim's treesitter toggle", vim.fn.maparg("<leader>uB", "n", false, true).desc, "Toggle Tab Style")
    check("<leader>uT still LazyVim's", (vim.fn.maparg("<leader>uT", "n", false, true).desc or ""):find("[Tt]reesitter") ~= nil, true)

    tabs.apply("classic")
    check("classic: the bar is a solid strip", hex(hl("BufferLineFill").bg), "#181825")
    check("classic: inactive tabs sit on the strip", hex(hl("BufferLineBackground").bg), "#181825")
    check("classic: active tab cut out (transparent)", hl("BufferLineBufferSelected").bg, nil)
    check("classic: active tab's icon cell cut out too", (function()
      local r = vim.api.nvim_eval_statusline(vim.o.tabline, { use_tabline = true, highlights = true })
      for _, h in ipairs(r.highlights) do if h.group:find("Icon") and h.group:find("Selected$") then return hl(h.group).bg end end
    end)(), nil)
    check("classic: blue indicator on the active tab", hex(hl("BufferLineIndicatorSelected").fg), "#89b4fa")
    check("classic: thin separators drawn", render():find("▏", 1, true) ~= nil, true)
    check("classic: no caps", count(render(), "(") + count(render(), "[") , 0)

    tabs.apply("classic-raised")
    check("classic-raised: active tab a lighter block", hex(hl("BufferLineBufferSelected").bg), "#313244")

    tabs.apply("classic-crust")
    check("classic-crust: darker strip", hex(hl("BufferLineFill").bg), "#11111b")

    tabs.apply("outline")
    check("outline: one hollow pill", count(render(), "(") .. count(render(), ")"), "11")
    check("outline: pill around the active tab", render():match("%(%s*%S+%s*long%.txt%s*%)") ~= nil, true)
    check("outline: caps in the popup border blue", hex(hl("BufferLineIndicatorSelected").fg) .. hex(hl("BufferLineCloseButtonSelected").fg), "#89b4fa#89b4fa")
    check("outline: nothing filled, nothing underlined", hl("BufferLineBufferSelected").bg == nil and hl("BufferLineBufferSelected").underline == nil and hl("BufferLineFill").underline == nil, true)
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { "x" })
    check("outline: modified keeps one right cap, in peach", count(render(), ")") == 1 and hex(hl("BufferLineModifiedSelected").fg) == "#fab387", true)
    vim.cmd("silent! undo")

    tabs.apply("outline-all")
    check("outline-all: every tab outlined", count(render(), "(") .. count(render(), ")"), "33")
    check("outline-all: inactive caps dim", hex(hl("BufferLineNumbers").fg) .. hex(hl("BufferLineCloseButton").fg), "#585b70#585b70")
    check("outline-all: active caps blue", hex(hl("BufferLineNumbersSelected").fg), "#89b4fa")

    tabs.apply("outline-divided")
    check("outline-divided: divider after the inactive tab", render():find("│", 1, true) ~= nil, true)
    check("outline-divided: divider dim", hex(hl("BufferLineSeparator").fg), "#45475a")
    check("outline-divided: still one pill", count(render(), "(") .. count(render(), ")"), "11")

    tabs.apply("outline-solid")
    check("outline-solid: filled caps", count(render(), "[") .. count(render(), "]"), "11")
    check("outline-solid: active tab filled blue with dark text", hex(hl("BufferLineBufferSelected").bg) .. hex(hl("BufferLineBufferSelected").fg), "#89b4fa#1e1e2e")
    check("outline-solid: inactive tabs plain", hl("BufferLineBackground").bg, nil)

    tabs.apply("outline-roomy")
    log(("  roomy render: %q"):format((render():gsub("%s+$", ""))))
    check("outline-roomy: extra space inside the pill", render():match("long%.txt%s%s+%)") ~= nil, true)

    tabs.apply("outline-lavender")
    check("outline-lavender: caps lavender", hex(hl("BufferLineIndicatorSelected").fg), "#b4befe")

    tabs.apply("outline-lavender"); tabs.toggle()
    check("toggle wraps around to the first", tabs.current, "classic")
    vim.cmd("TabStyle outline-all")
    check(":TabStyle picks a preset", tabs.current, "outline-all")
    log("OK")
  end)
  log(ok and "DONE" or ("ERROR: " .. tostring(err)))
  vim.cmd("qall!")
end)
