-- A bare `nvim` in a directory with a saved session restores it; without
-- one, nothing happens (the dashboard's turn). Two sessions in the go
-- fixture dir: pass 1 (SESSION_PASS=1) opens main.go and main_test.go and
-- saves a session; pass 2 starts bare and expects both buffers back.
local logf = io.open(vim.fn.getcwd() .. "/result.log", vim.env.SESSION_PASS == "1" and "w" or "a")
local function log(s) logf:write(s, "\n"); logf:flush() end
local function check(name, got, want) log(("%s %s: %s (want %s)"):format(got == want and "PASS" or "FAIL", name, tostring(got), tostring(want))) end
vim.defer_fn(function() log("TIMEOUT"); vim.cmd("qall!") end, 40000)
local function listed()
  local names = {}
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].buflisted and vim.api.nvim_buf_get_name(b) ~= "" then names[#names + 1] = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(b), ":t") end
  end
  table.sort(names)
  return table.concat(names, ",")
end
vim.schedule(function()
  local ok, err = pcall(function()
    vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
    vim.wait(500, function() return false end) -- the scheduled restore
    if vim.env.SESSION_PASS == "1" then
      check("pass 1: bare start, no session yet -> nothing restored", listed(), "")
      check("pass 1: dashboard would be enabled", Snacks.config.dashboard.enabled, true)
      check("pass 1: stock intro allowed (no I in shortmess)", vim.o.shortmess:find("I", 1, true), nil)
      vim.cmd("edit main.go"); vim.cmd("edit main_test.go")
      require("persistence").save()
      check("pass 1: session saved", vim.fn.filereadable(require("util.session").file() or ""), 1)
      vim.cmd("qall!")
      return
    end
    check("pass 2: session detected", require("util.session").has_session(), true)
    check("pass 2: dashboard disabled", Snacks.config.dashboard.enabled, false)
    check("pass 2: stock intro hidden (I in shortmess)", vim.o.shortmess:find("I", 1, true) ~= nil, true)
    check("pass 2: buffers restored", listed(), "main.go,main_test.go")
    check("pass 2: a real file is current", vim.fn.expand("%:t") ~= "", true)
    log("OK")
  end)
  log(ok and "DONE" or ("ERROR: " .. tostring(err)))
  vim.cmd("qall!")
end)
