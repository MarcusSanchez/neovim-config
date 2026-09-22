local logf = io.open(vim.fn.expand("%:p:h") .. "/result.log", "w")
local function log(s) logf:write(s, "\n"); logf:flush() end
local function fire() vim.api.nvim_exec_autocmds("CursorMoved", { buffer = 0 }) end
local function blank_below() return 20 - vim.api.nvim_win_text_height(0, { start_row = vim.fn.line("w0") - 1, end_row = 99 }).all end
vim.schedule(function()
  local ok, err = pcall(function()
    vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
    vim.o.lines = 24; vim.api.nvim_win_set_height(0, 20); vim.wo.foldmethod = "manual"
    vim.cmd("normal! G"); fire()
    log(("no folds, G: topline=%d blank rows below last=%d (want 4)"):format(vim.fn.line("w0"), blank_below()))
    -- fold lines 60-90 (31 lines -> 1 row) and 95-97
    vim.cmd("60,90fold"); vim.cmd("95,97fold")
    vim.cmd("normal! gg"); fire(); vim.cmd("normal! G"); fire()
    log(("folds 60-90 & 95-97, G: topline=%d blank rows below last=%d (want 4) fold60 closed=%s"):format(vim.fn.line("w0"), blank_below(), tostring(vim.fn.foldclosed(60) == 60)))
    vim.cmd("normal! gg"); fire(); vim.cmd("normal! 94G"); fire()
    log(("94G (fold 95-97 + lines 98-100 = 4 rows below): topline=%d blank rows below last=%d cursor rows from bottom=%d (want 4)"):format(vim.fn.line("w0"), blank_below(), 20 - vim.api.nvim_win_text_height(0, { start_row = vim.fn.line("w0") - 1, end_row = 93 }).all))
    vim.cmd("normal! gg"); fire(); vim.cmd("normal! 50G"); fire()
    log(("50G: topline=%d (want plain scrolling, cursor visible=%s)"):format(vim.fn.line("w0"), tostring(vim.fn.line("w0") <= 50 and 50 <= vim.fn.line("w$"))))
  end)
  log(ok and "OK" or ("ERROR: " .. tostring(err)))
  vim.cmd("qall!")
end)
