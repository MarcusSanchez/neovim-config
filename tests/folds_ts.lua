-- Folds persist for treesitter-folded files, whose fold levels arrive
-- asynchronously after the buffer opens. Opens the rust fixture's lib.rs:
-- pass 1 (FOLD_PASS=1) closes `mod tests { ... }` and quits; pass 2 expects
-- it closed again.
local logf = io.open(vim.fn.getcwd() .. "/result.log", vim.env.FOLD_PASS == "1" and "w" or "a")
local function log(s) logf:write(s, "\n"); logf:flush() end
local function check(name, got, want) log(("%s %s: %s (want %s)"):format(got == want and "PASS" or "FAIL", name, tostring(got), tostring(want))) end
vim.defer_fn(function() log("TIMEOUT"); vim.cmd("qall!") end, 30000)
vim.schedule(function()
  local ok, err = pcall(function()
    vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
    local mod = vim.fn.search("^mod tests {", "nw")
    check("treesitter folds (expr) in use", vim.wo.foldmethod, "expr")
    -- the fold engine fills in after treesitter's async parse
    vim.wait(5000, function() return vim.fn.foldlevel(mod) > 0 end, 50)
    check("fold structure arrived for mod tests", vim.fn.foldlevel(mod) > 0, true)
    if vim.env.FOLD_PASS == "1" then
      vim.cmd(("normal! %dGzc"):format(mod))
      check("pass 1: mod tests closed", vim.fn.foldclosed(mod), mod)
      vim.cmd("qall")
      return
    end
    vim.wait(5000, function() return vim.fn.foldclosed(mod) == mod end, 50)
    check("pass 2: mod tests is closed again", vim.fn.foldclosed(mod), mod)
    -- treesitter's later fold passes reopen folds closed too early; the
    -- restore must outlast them
    vim.wait(3000, function() return false end)
    check("pass 2: still closed after treesitter settles", vim.fn.foldclosed(mod), mod)
    check("pass 2: fn foobar still open", vim.fn.foldclosed(1), -1)
    -- the user opening a restored fold must stick: nothing re-closes it
    vim.cmd(("normal! %dGzo"):format(mod))
    local refolded
    for _ = 1, 25 do
      vim.wait(100, function() return false end)
      if vim.fn.foldclosed(mod) ~= -1 then refolded = true break end
    end
    check("pass 2: zo on a restored fold is not undone", refolded, nil)
    vim.cmd(("normal! %dGzc"):format(mod))
    -- a picker-style preview (the real buffer in a float, no folds closed)
    -- coming and going must not wipe the saved state
    local state = vim.fn.stdpath("state") .. "/folds/" .. vim.api.nvim_buf_get_name(0):gsub("[/\\:]", "%%") .. ".json"
    local src = vim.api.nvim_get_current_win()
    local float = vim.api.nvim_open_win(0, true, { relative = "editor", row = 1, col = 1, width = 40, height = 10 })
    vim.api.nvim_exec_autocmds("BufWinEnter", { buffer = 0 })
    vim.cmd("normal! zR")
    vim.api.nvim_win_close(float, true) -- BufWinLeave from the float
    vim.wait(200, function() return false end)
    check("preview float leaving keeps the state file", vim.fn.filereadable(state), 1)
    -- a fresh split closed before its restore could finish must not either
    vim.cmd("split")
    local split = vim.api.nvim_get_current_win()
    require("util.folds").save(0, split) -- what BufWinLeave would do right now
    vim.api.nvim_win_close(split, true)
    vim.api.nvim_set_current_win(src)
    check("unready split leaving keeps the state file", vim.fn.filereadable(state), 1)
    check("main window's fold still closed", vim.fn.foldclosed(mod), mod)
    log("OK")
  end)
  log(ok and "DONE" or ("ERROR: " .. tostring(err)))
  vim.cmd("qall!")
end)
