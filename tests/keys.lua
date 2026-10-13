-- j/k are swapped in this config; every place vim or a plugin spells
-- "down" as j / "up" as k must follow. Opens long.txt.
local lib = dofile(debug.getinfo(1, "S").source:sub(2):match("^(.*)/[^/]*$") .. "/lib.lua")
local t = lib.open(vim.fn.expand("%:p:h") .. "/result.log", "w")
local log, check = t.log, t.check
local function rhs(mode, lhs)
  local m = vim.fn.maparg(lhs, mode, false, true)
  return m.rhs or (m.callback and "<callback>") or nil
end
vim.defer_fn(function()
  log("TIMEOUT")
  vim.cmd("qall!")
end, 60000)
vim.schedule(function()
  local ok, err = pcall(function()
    vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
    vim.api.nvim_exec_autocmds("FileType", { buffer = 0 }) -- as LazyVim re-fires it after loading autocmds
    -- a search doesn't unfold what it passes through: a match inside a
    -- closed fold opens it for the visit only
    vim.fn.writefile({
      "block one",
      "    one line 1",
      "        one deep 1",
      "        one deep 2",
      "    one line 2",
      "block two",
      "    two line 1",
      "    two line 2",
      "block three",
      "    three line 1",
      "    three line 2",
    }, "search.txt")
    vim.cmd("edit search.txt")
    local sb = vim.api.nvim_get_current_buf()
    local function type_keys(k)
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(k, true, false, true), "x", false)
    end
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    type_keys(",d") -- the inner block, then the outer around it
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    type_keys(",d")
    vim.api.nvim_win_set_cursor(0, { 10, 0 })
    type_keys(",d")
    check(
      "search: indent folds closed (outer hides inner)",
      vim.fn.foldclosed(2) .. " " .. vim.fn.foldclosed(10),
      "2 10"
    )
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    type_keys("/2$<CR>") -- matches: one deep 2, one line 2, two line 2, three line 2
    vim.wait(200, function()
      return vim.fn.foldclosed(4) == -1
    end, 10)
    check("search: cursor on the match inside the nested fold", vim.api.nvim_win_get_cursor(0)[1], 4)
    check("search: both levels open for the visit", vim.fn.foldclosed(4) .. " " .. vim.fn.foldclosed(2), "-1 -1")
    check("search: the fold it passed over stays closed", vim.fn.foldclosed(10), 10)
    -- a save during the visit still records the fold as closed
    require("util.folds").save(0, vim.api.nvim_get_current_win())
    local state = vim.fn.stdpath("state") .. "/folds/" .. vim.api.nvim_buf_get_name(0):gsub("[/\\:]", "%%") .. ".json"
    local saved = vim.fn.filereadable(state) == 1 and table.concat(vim.fn.readfile(state), "") or ""
    check("search: saving mid-visit keeps the visited fold", saved:find('"start":2', 1, true) ~= nil, true)
    type_keys("n") -- `one line 2`: still inside the outer fold
    check("search: a match in the same fold keeps it open", vim.fn.foldclosed(5), -1)
    type_keys("n") -- `two line 2`, outside any fold
    check("search: n moves on", vim.api.nvim_win_get_cursor(0)[1], 8)
    check("search: the fold left behind closes again", vim.fn.foldclosed(2), 2)
    vim.cmd("normal! 2Gzo")
    check("search: its inner fold is closed again too", vim.fn.foldclosed(3), 3)
    vim.cmd("normal! 2Gzc8G")
    type_keys("n") -- `three line 2`, inside the last fold
    check("search: n into a fold opens it", vim.fn.foldclosed(11), -1)
    type_keys("gg")
    vim.api.nvim_exec_autocmds("CursorMoved", {}) -- fed keys don't reach the main loop that fires it
    check("search: leaving closes it again", vim.fn.foldclosed(10), 10)
    type_keys("G")
    type_keys("n") -- wraps to `one deep 2`
    vim.cmd("normal! A!") -- an edit inside the visited fold
    type_keys("gg")
    vim.api.nvim_exec_autocmds("CursorMoved", {})
    check("search: an edited fold stays open", vim.fn.foldclosed(4), -1)
    check("search: 'foldopen' no longer opens on search", vim.opt.foldopen:get().search, nil)
    check("Shift-N still joins lines (not a search key)", vim.fn.maparg("N", "n", false, true).rhs, "J")
    vim.cmd("buffer long.txt")
    vim.api.nvim_buf_delete(sb, { force = true })
    vim.fn.delete("search.txt")
    check("text files: no spell squiggles", vim.wo.spell, false)
    check("text files: still wrap", vim.wo.wrap, true)
    -- leaving insert mode doesn't step the cursor back
    local function keys(k)
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(k, true, false, true), "x", false)
    end
    vim.api.nvim_win_set_cursor(0, { 50, 2 }) -- "line 50", on 'n'
    keys("ajj")
    keys("ajj")
    keys("ajj")
    check("a jj x3 walks right three columns", vim.api.nvim_win_get_cursor(0)[2], 5)
    keys("$")
    keys("ajj")
    keys("ajj")
    check("a jj at end of line stays on the last character", vim.api.nvim_win_get_cursor(0)[2], #vim.fn.getline(50) - 1)
    check("...and never wraps to a new line", vim.fn.line("."), 50)
    vim.api.nvim_win_set_cursor(0, { 50, 3 })
    keys("ijj")
    keys("ijj")
    keys("ijj")
    check("i jj x3 stays put", vim.api.nvim_win_get_cursor(0)[2], 3)
    keys("i<Esc>")
    check("<Esc> behaves like jj", vim.api.nvim_win_get_cursor(0)[2], 3)
    check("buffer unchanged by the above", vim.fn.getline(50), "line 50")
    -- motions
    vim.api.nvim_win_set_cursor(0, { 50, 0 })
    vim.cmd("normal j")
    check("j goes up", vim.fn.line("."), 49)
    vim.cmd("normal k")
    check("k goes down", vim.fn.line("."), 50)
    vim.cmd("normal dk")
    check("dk deletes downward", vim.fn.getline(50), "line 52")
    vim.cmd("undo")
    -- windows
    check("<C-w>j goes up", rhs("n", "<C-w>j"), "<C-w>k")
    check("<C-w>k goes down", rhs("n", "<C-w>k"), "<C-w>j")
    check("<C-w>J moves window to top", rhs("n", "<C-w>J"), "<C-w>K")
    -- folds
    vim.wo.foldmethod = "manual"
    vim.cmd("10,20fold")
    vim.cmd("30,40fold")
    vim.cmd("normal! zR")
    vim.api.nvim_win_set_cursor(0, { 25, 0 })
    vim.cmd("normal zk")
    check("zk goes to the next fold (down)", vim.fn.line("."), 30)
    vim.api.nvim_win_set_cursor(0, { 25, 0 })
    vim.cmd("normal zj")
    check("zj goes to the previous fold (up)", vim.fn.line("."), 20)
    -- LazyVim's Alt-j/k line moves are gone in every mode
    check("<A-j> insert unmapped", vim.fn.maparg("<A-j>", "i"), "")
    check("<A-k> visual unmapped", vim.fn.maparg("<A-k>", "v"), "")
    -- snacks picker + terminal
    local p = Snacks.picker.config.get({ source = "files" })
    local function keyspec(keys, lhs)
      for k, v in pairs(keys) do
        if k:lower() == lhs then
          return type(v) == "table" and v[1] or v
        end
      end
    end
    check("picker input <c-k> is list_down", keyspec(p.win.input.keys, "<c-k>"), "list_down")
    check("picker list <c-j> is list_up", keyspec(p.win.list.keys, "<c-j>"), "list_up")
    local t = Snacks.config.get("terminal", {}).win.keys
    check("terminal <C-j> desc", t.nav_j.desc, "Go to Upper Window")
    check("terminal <C-k> desc", t.nav_k.desc, "Go to Lower Window")
    -- oil and harpoon live alongside the snacks explorer
    check(",a is still the explorer", vim.fn.maparg(",a", "n", false, true).desc, "Toggle/Focus Explorer (Root Dir)")
    check(
      "- opens oil for the file's directory",
      vim.fn.maparg("-", "n", false, true).desc,
      "Open Parent Directory (Oil Float)"
    )
    check(
      ",o opens oil at the project root",
      vim.fn.maparg(",o", "n", false, true).desc,
      "Open Project Root (Oil Float)"
    )
    require("oil").open_float()
    vim.wait(3000, function()
      return vim.bo.filetype == "oil"
    end, 50)
    check("oil float shows the directory as a buffer", vim.bo.filetype, "oil")
    vim.wait(5000, function()
      return vim.fn.search("long.txt", "nw") > 0
    end, 50) -- the listing fills in async
    check("oil lists this file", vim.fn.search("long.txt", "nw") > 0, true)
    require("oil").close()
    check(
      "harpoon keys",
      vim.fn.maparg(",ha", "n", false, true).desc
        .. " / "
        .. vim.fn.maparg(",hl", "n", false, true).desc
        .. " / "
        .. vim.fn.maparg(",3", "n", false, true).desc,
      "Harpoon Add File / Harpoon Quick Menu / Harpoon File 3"
    )
    require("harpoon"):list():clear()
    vim.fn.maparg(",ha", "n", false, true).callback()
    check("harpoon pins the current file", require("harpoon"):list():length(), 1)
    -- a jump from an empty buffer replaces it: no [No Name] tab left behind
    vim.cmd("enew")
    local empty = vim.api.nvim_get_current_buf()
    check("harpoon: on an empty buffer", vim.api.nvim_buf_get_name(0) == "" and vim.bo.buflisted, true)
    vim.fn.maparg(",1", "n", false, true).callback()
    check("harpoon: jump lands on the pinned file", vim.fn.expand("%:t"), "long.txt")
    check("harpoon: the empty buffer is gone", vim.api.nvim_buf_is_valid(empty), false)
    -- a jump from a real file keeps that file's tab
    vim.cmd("edit search.txt")
    vim.fn.writefile({ "x" }, "search.txt")
    vim.cmd("edit search.txt")
    local real = vim.api.nvim_get_current_buf()
    vim.fn.maparg(",1", "n", false, true).callback()
    check("harpoon: a real buffer stays listed", vim.api.nvim_buf_is_valid(real) and vim.bo[real].buflisted, true)
    vim.api.nvim_buf_delete(real, { force = true })
    vim.fn.delete("search.txt")
    require("harpoon"):list():clear()
    -- undotree
    require("lazy").load({ plugins = { "undotree" } })
    check("undotree custom map defined", vim.fn.exists("*g:Undotree_CustomMap"), 1)
  end)
  log(ok and "DONE" or ("ERROR: " .. tostring(err)))
  vim.cmd("qall!")
end)
