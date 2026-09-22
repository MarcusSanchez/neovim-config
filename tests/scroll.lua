-- scrolloff past the end of the buffer, with and without folds. Opens
-- long.txt (100 lines) in a 20-row window with scrolloff=4: the cursor must
-- never sit on the bottom 4 rows, and the view must only ever move forward.
local logf = io.open(vim.fn.expand("%:p:h") .. "/result.log", "w")
local function log(s) logf:write(s, "\n"); logf:flush() end
local function check(name, got, want) log(("%s %s: %s (want %s)"):format(got == want and "PASS" or "FAIL", name, tostring(got), tostring(want))) end
local function fire() vim.api.nvim_exec_autocmds("CursorMoved", { buffer = 0 }) end
local function go(cmd) vim.cmd("normal! " .. cmd); fire() end
local function row() return vim.fn.winline() end
local function top() return vim.fn.line("w0") end
vim.defer_fn(function() log("TIMEOUT"); vim.cmd("qall!") end, 30000)
vim.schedule(function()
  local ok, err = pcall(function()
    vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
    vim.o.lines = 24; vim.api.nvim_win_set_height(0, 20); vim.wo.foldmethod = "manual"; vim.o.scrolloff = 4
    go("G"); check("no folds, G: cursor row", row(), 16); check("no folds, G: topline", top(), 85)
    -- folds: 60-90 collapses to one row, 95-97 to one row
    vim.cmd("60,90fold"); vim.cmd("95,97fold"); go("gg"); go("G")
    check("folds, G: cursor row", row(), 16)
    check("folds, G: big fold visible as one row", vim.fn.foldclosed(60) == 60 and top() <= 60, true)
    -- walking down line by line from the middle must be monotonic and never enter the margin
    go("gg"); go("50G")
    local prev_top, monotonic, in_margin = top(), true, false
    for _ = 1, 60 do
      go("j")
      if top() < prev_top then monotonic = false end
      prev_top = top()
      if row() > 16 then in_margin = true end
    end
    check("walk down: view only moves forward", monotonic, true)
    check("walk down: cursor never in bottom margin", in_margin, false)
    check("walk down: ends on last line", vim.fn.line("."), 100)
    -- cursor sitting on a closed fold that ends the buffer
    vim.cmd("normal! zE"); vim.cmd("90,100fold"); go("gg"); go("G")
    check("closed fold at EOF: cursor inside the fold", vim.fn.foldclosed(vim.fn.line(".")), 90)
    check("closed fold at EOF: cursor row", row(), 16)
    -- opening that fold under the cursor and moving into it
    go("zo"); go("95G")
    check("after zo + move: cursor row <= 16", row() <= 16, true)
    -- moving back up never scrolls the view
    local t = top(); go("k"); go("k"); check("moving up keeps view", top(), t)
    -- wrapped long last line: still inside the margin
    vim.api.nvim_buf_set_lines(0, 99, 100, false, { string.rep("x", 400) }); vim.cmd("normal! zE"); vim.wo.wrap = true
    go("gg"); go("G"); check("wrapped last line: cursor row <= 16", row() <= 16, true)
    log("OK")
  end)
  log(ok and "DONE" or ("ERROR: " .. tostring(err)))
  vim.cmd("qall!")
end)
