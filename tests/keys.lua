-- j/k are swapped in this config; every place vim or a plugin spells
-- "down" as j / "up" as k must follow. Opens long.txt.
local logf = io.open(vim.fn.expand("%:p:h") .. "/result.log", "w")
local function log(s) logf:write(s, "\n"); logf:flush() end
local function check(name, got, want) log(("%s %s: %s (want %s)"):format(got == want and "PASS" or "FAIL", name, tostring(got), tostring(want))) end
local function rhs(mode, lhs) local m = vim.fn.maparg(lhs, mode, false, true); return m.rhs or (m.callback and "<callback>") or nil end
vim.defer_fn(function() log("TIMEOUT"); vim.cmd("qall!") end, 60000)
vim.schedule(function()
  local ok, err = pcall(function()
    vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
    vim.api.nvim_exec_autocmds("FileType", { buffer = 0 }) -- as LazyVim re-fires it after loading autocmds
    check("text files: no spell squiggles", vim.wo.spell, false)
    check("text files: still wrap", vim.wo.wrap, true)
    -- motions
    vim.api.nvim_win_set_cursor(0, { 50, 0 })
    vim.cmd("normal j"); check("j goes up", vim.fn.line("."), 49)
    vim.cmd("normal k"); check("k goes down", vim.fn.line("."), 50)
    vim.cmd("normal dk"); check("dk deletes downward", vim.fn.getline(50), "line 52")
    vim.cmd("undo")
    -- windows
    check("<C-w>j goes up", rhs("n", "<C-w>j"), "<C-w>k")
    check("<C-w>k goes down", rhs("n", "<C-w>k"), "<C-w>j")
    check("<C-w>J moves window to top", rhs("n", "<C-w>J"), "<C-w>K")
    -- folds
    vim.wo.foldmethod = "manual"; vim.cmd("10,20fold"); vim.cmd("30,40fold"); vim.cmd("normal! zR")
    vim.api.nvim_win_set_cursor(0, { 25, 0 })
    vim.cmd("normal zk"); check("zk goes to the next fold (down)", vim.fn.line("."), 30)
    vim.api.nvim_win_set_cursor(0, { 25, 0 })
    vim.cmd("normal zj"); check("zj goes to the previous fold (up)", vim.fn.line("."), 20)
    -- LazyVim's Alt-j/k line moves are gone in every mode
    check("<A-j> insert unmapped", vim.fn.maparg("<A-j>", "i"), "")
    check("<A-k> visual unmapped", vim.fn.maparg("<A-k>", "v"), "")
    -- snacks picker + terminal
    local p = Snacks.picker.config.get({ source = "files" })
    local function keyspec(keys, lhs)
      for k, v in pairs(keys) do
        if k:lower() == lhs then return type(v) == "table" and v[1] or v end
      end
    end
    check("picker input <c-k> is list_down", keyspec(p.win.input.keys, "<c-k>"), "list_down")
    check("picker list <c-j> is list_up", keyspec(p.win.list.keys, "<c-j>"), "list_up")
    local t = Snacks.config.get("terminal", {}).win.keys
    check("terminal <C-j> desc", t.nav_j.desc, "Go to Upper Window")
    check("terminal <C-k> desc", t.nav_k.desc, "Go to Lower Window")
    -- undotree
    require("lazy").load({ plugins = { "undotree" } })
    check("undotree custom map defined", vim.fn.exists("*g:Undotree_CustomMap"), 1)
    log("OK")
  end)
  log(ok and "DONE" or ("ERROR: " .. tostring(err)))
  vim.cmd("qall!")
end)
