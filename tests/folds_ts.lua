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
    check("pass 2: fn foobar still open", vim.fn.foldclosed(1), -1)
    log("OK")
  end)
  log(ok and "DONE" or ("ERROR: " .. tostring(err)))
  vim.cmd("qall!")
end)
