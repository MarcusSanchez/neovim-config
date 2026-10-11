local dir = vim.fn.expand("%:p:h:h")
local logf = io.open(dir .. "/result.log", "w")
local function log(s) logf:write(s, "\n"); logf:flush() end
vim.defer_fn(function() log("TIMEOUT"); vim.cmd("qall!") end, 100000)
vim.schedule(function()
  local ok, err = pcall(function()
    vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
    vim.o.lines, vim.o.columns = 40, 120
    local is_noise = require("util.noise").checker()
    local f = dir .. "/src/lib.rs"
    local res = {}
    for _, c in ipairs({ { 1, 7, false }, { 7, 0, true }, { 8, 3, true }, { 11, 4, true }, { 14, 7, true } }) do res[#res + 1] = tostring(is_noise(f, c[1], c[2]) == c[3]) end
    log("noise checks all OK: " .. table.concat(res, ","))
    local function client() return vim.lsp.get_clients({ bufnr = 0, name = "rust-analyzer" })[1] end
    vim.wait(60000, function() return client() ~= nil end, 200)
    local c = assert(client(), "rust-analyzer never attached")
    vim.wait(60000, function() local r = c:request_sync("workspace/symbol", { query = "foobar" }, 5000, 0); return r and r.result and #r.result > 0 end, 1000)
    vim.fn.maparg("gs", "n", false, true).callback()
    vim.wait(2000, function() return #Snacks.picker.get() > 0 end, 50)
    local p = assert(Snacks.picker.get()[1], "no picker")
    p.input:set("", "foobar"); p:find({ refresh = true })
    vim.wait(10000, function() return not p.finder:running() and p:count() > 0 end, 100); vim.wait(500, function() return false end)
    log("gs 'foobar' -> " .. table.concat(vim.tbl_map(function(i) return i.name .. "@" .. i.pos[1] end, p:items()), ", ") .. "  (want only foobar@1)")
    p:close()
    -- a type used as a path qualifier is upright; a module qualifier is italic
    local function resolved(name)
      local n = name
      for _ = 1, 20 do
        local h = vim.api.nvim_get_hl(0, { name = n })
        if h.link then n = h.link elseif next(h) == nil and n:find("%.") then n = n:gsub("%.[^.]+$", "") else break end
      end
      return vim.api.nvim_get_hl(0, { name = n, link = false }).italic == true
    end
    local function italic_at(row, col)
      local info = vim.inspect_pos(0, row, col)
      for _, c in ipairs(info.treesitter) do if resolved(c.hl_group) then return true end end
      for _, t in ipairs(info.semantic_tokens) do if resolved(t.opts.hl_group) then return true end end
      return false
    end
    local t = vim.fn.searchpos("Dongle::open()", "nw") -- the usage in use_it
    local m = vim.fn.searchpos("dongle::Error> { Dongle", "nw")
    local trow, tcol, mrow, mcol = t[1] - 1, t[2] - 1, m[1] - 1, m[2] - 1
    vim.wait(20000, function() return #vim.lsp.semantic_tokens.get_at_pos(0, trow, tcol) > 0 end, 250)
    log(("%s type as path qualifier (`Dongle::open`) upright: %s (want false)"):format(italic_at(trow, tcol) == false and "PASS" or "FAIL", tostring(italic_at(trow, tcol))))
    log(("%s module qualifier (`dongle::Error`) italic: %s (want true)"):format(italic_at(mrow, mcol) and "PASS" or "FAIL", tostring(italic_at(mrow, mcol))))
  end)
  log(ok and "DONE" or ("ERROR: " .. tostring(err)))
  vim.cmd("qall!")
end)
