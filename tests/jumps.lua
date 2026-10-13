-- Jumps glide (lua/util/jumps.lua): G, gg and the half-page scrolls run
-- as usual and the view eases to where they land over a few frames; a
-- key typed mid-glide lands it at once; a jump that doesn't scroll
-- doesn't animate.
local logf = io.open(vim.fn.getcwd() .. "/result.log", "w")
local function log(s)
  logf:write(s, "\n")
  logf:flush()
end
local function check(name, got, want)
  log(("%s %s: %s (want %s)"):format(got == want and "PASS" or "FAIL", name, tostring(got), tostring(want)))
end
vim.defer_fn(function()
  log("TIMEOUT")
  vim.cmd("qall!")
end, 60000)
vim.schedule(function()
  local ok, err = pcall(function()
    vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
    vim.o.lines, vim.o.columns = 30, 80
    local J = require("util.jumps")
    local function key(k)
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(k, true, false, true), "x", false)
    end
    local function view()
      local v = vim.fn.winsaveview()
      return v.topline .. "/" .. v.lnum
    end
    local moves = 0
    vim.api.nvim_create_autocmd("CursorMoved", {
      callback = function()
        moves = moves + 1
      end,
    })
    -- where G lands in this window, measured with Vim's own G
    vim.cmd("normal! G")
    local bottom = vim.fn.winsaveview().topline .. "/100"
    vim.cmd("normal! gg")
    -- G: the cursor lands at once, the view glides there
    check("mapped", vim.fn.maparg("G", "n", false, true).desc, "Go to Last Line")
    J.frames = 0
    key("G")
    check("right after G the view is still at the top", vim.fn.winsaveview().topline, 1)
    check("and a glide is in flight", J.active(), true)
    vim.wait(1000, function()
      return not J.active()
    end, 10)
    check("it lands on the last line", view(), bottom)
    check("over several frames", J.frames >= 4, true)
    check("the frames fired no CursorMoved (only the jump's own)", moves <= 2, true)
    -- gg back, with a count: 50gg
    key("50gg")
    vim.wait(1000, function()
      return not J.active()
    end, 10)
    check("50gg lands on line 50", vim.fn.line("."), 50)
    key("gg")
    vim.wait(1000, function()
      return not J.active()
    end, 10)
    check("gg lands at the top", view(), "1/1")
    -- a half page down (Shift-K here), then up
    key("<S-K>")
    vim.wait(1000, function()
      return not J.active()
    end, 10)
    local after = vim.fn.winsaveview()
    check("Shift-K scrolls half a page", after.topline > 1 and after.lnum > 1, true)
    key("<S-J>")
    vim.wait(1000, function()
      return not J.active()
    end, 10)
    check("Shift-J back up", vim.fn.winsaveview().topline, 1)
    -- a jump that doesn't scroll: no glide
    vim.cmd("normal! 5G")
    J.frames = 0
    key("gg")
    check("gg within the view: no glide", J.active() or J.frames > 0, false)
    check("but it moved", vim.fn.line("."), 1)
    -- a key typed mid-glide lands the view at once
    key("G")
    check("glide started", J.active(), true)
    vim.api.nvim_input("l") -- queued: the next frame sees it and lands
    vim.wait(500, function()
      return not J.active()
    end, 5)
    check("the pending key landed the glide early", J.frames < 4, true)
    check("at the jump's target", vim.fn.line("."), 100)
    -- a second jump during a glide lands the first, then glides anew
    vim.api.nvim_feedkeys("", "x", false) -- the queued l runs now
    key("gg")
    check("gg from the bottom glides", tostring(J.active()) .. " top=" .. vim.fn.winsaveview().topline, "true top=72")
    key("G")
    check(
      "the new glide starts from the landed first one",
      tostring(J.active()) .. " top=" .. vim.fn.winsaveview().topline,
      "true top=1"
    )
    vim.wait(1000, function()
      return not J.active()
    end, 10)
    check("and lands", vim.fn.line("."), 100)
  end)
  log(ok and "DONE" or ("ERROR: " .. tostring(err)))
  vim.cmd("qall!")
end)
