-- Folds persist across sessions. Run twice on folds.txt (two indented
-- blocks, so the config's indent folding gives one fold each) with VIEWDIR
-- set: pass 1 (FOLD_PASS=1) closes the first block and quits; pass 2 reopens
-- the file and expects the first block closed and the second still open.
local logf = io.open(vim.fn.getcwd() .. "/result.log", vim.env.FOLD_PASS == "1" and "w" or "a")
local function log(s) logf:write(s, "\n"); logf:flush() end
local function check(name, got, want) log(("%s %s: %s (want %s)"):format(got == want and "PASS" or "FAIL", name, tostring(got), tostring(want))) end
vim.defer_fn(function() log("TIMEOUT"); vim.cmd("qall!") end, 30000)
vim.o.viewdir = vim.env.VIEWDIR
vim.schedule(function()
  local ok, err = pcall(function()
    vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
    vim.api.nvim_exec_autocmds("BufWinEnter", { buffer = 0 })
    check("viewoptions is folds only", vim.o.viewoptions, "folds")
    check("indent folds present", vim.fn.foldlevel(3) > 0, true)
    if vim.env.FOLD_PASS == "1" then
      vim.cmd("normal! 3Gzc")
      check("pass 1: first block closed", vim.fn.foldclosed(3), 2)
      check("pass 1: second block open", vim.fn.foldclosed(13), -1)
      vim.api.nvim_win_set_cursor(0, { 20, 0 })
      vim.cmd("qall") -- BufWinLeave writes the view
      return
    end
    check("pass 2: first block is still closed", vim.fn.foldclosed(3), 2)
    check("pass 2: second block is still open", vim.fn.foldclosed(13), -1)
    check("pass 2: cursor not restored by the view (folds only)", vim.fn.line(".") ~= 20, true)
    log("OK")
  end)
  log(ok and "DONE" or ("ERROR: " .. tostring(err)))
  vim.cmd("qall!")
end)
