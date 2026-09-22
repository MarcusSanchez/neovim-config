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
  end)
  log(ok and "DONE" or ("ERROR: " .. tostring(err)))
  vim.cmd("qall!")
end)
