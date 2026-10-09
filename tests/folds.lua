-- Folds persist across sessions, anchored to content. folds.txt has three
-- indented blocks. Pass 1 (FOLD_PASS=1) closes blocks one and three and
-- quits. run.sh then prepends lines (everything shifts) and edits a line
-- inside block three. Pass 2 expects block one closed at its new place,
-- block three open (its text changed), block two untouched.
local logf = io.open(vim.fn.getcwd() .. "/result.log", vim.env.FOLD_PASS == "1" and "w" or "a")
local function log(s) logf:write(s, "\n"); logf:flush() end
local function check(name, got, want) log(("%s %s: %s (want %s)"):format(got == want and "PASS" or "FAIL", name, tostring(got), tostring(want))) end
vim.defer_fn(function() log("TIMEOUT"); vim.cmd("qall!") end, 30000)
vim.schedule(function()
  local ok, err = pcall(function()
    vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
    vim.api.nvim_exec_autocmds("BufWinEnter", { buffer = 0 })
    local names = { "one", "two", "three" }
    local function block(n) -- first indented line of block n
      return vim.fn.search("^block " .. names[n] .. "$", "nw") + 1
    end
    if vim.env.FOLD_PASS == "1" then
      vim.cmd(("normal! %dGzc"):format(block(1)))
      vim.cmd(("normal! %dGzc"):format(block(3)))
      check("pass 1: block one closed", vim.fn.foldclosed(block(1)) ~= -1, true)
      check("pass 1: block three closed", vim.fn.foldclosed(block(3)) ~= -1, true)
      vim.cmd("qall")
      return
    end
    check("pass 2: block one closed at its shifted position", vim.fn.foldclosed(block(1)), block(1))
    check("pass 2: block one fold spans its 9 lines", vim.fn.foldclosedend(block(1)) - block(1), 8)
    check("pass 2: block two still open", vim.fn.foldclosed(block(2)), -1)
    check("pass 2: block three open (edited, not re-folded)", vim.fn.foldclosed(block(3)), -1)
    check("pass 2: prepended lines unfolded", vim.fn.foldclosed(1), -1)
    log("OK")
  end)
  log(ok and "DONE" or ("ERROR: " .. tostring(err)))
  vim.cmd("qall!")
end)
