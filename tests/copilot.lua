-- The Copilot server can't outlive nvim. Inside nvim: the client is launched
-- through the watchdog wrapper with an exit timeout, the watchdog subshell
-- is running under the server, and a planted orphan (run.sh starts a fake
-- server reparented to launchd) gets reaped. run.sh then SIGKILLs this nvim
-- and checks the real server is gone.
local logf = io.open(vim.fn.getcwd() .. "/result.log", "w")
local function log(s) logf:write(s, "\n"); logf:flush() end
local function check(name, got, want) log(("%s %s: %s (want %s)"):format(got == want and "PASS" or "FAIL", name, tostring(got), tostring(want))) end
vim.defer_fn(function() log("TIMEOUT"); vim.cmd("qall!") end, 60000)
vim.schedule(function()
  local ok, err = pcall(function()
    local copilot = require("util.copilot")
    vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
    -- the reaper runs async off VeryLazy; give it a moment
    vim.wait(3000, function() return false end)
    local orphan = vim.trim(vim.fn.system({ "pgrep", "-f", "FAKE-ORPHAN " .. copilot.server }))
    check("planted orphan reaped at startup", orphan, "")
    -- the real client
    local client
    vim.wait(30000, function()
      client = vim.lsp.get_clients({ name = "copilot" })[1]
      return client ~= nil and client.initialized
    end, 200)
    check("copilot client up", client ~= nil, true)
    if client then
      check("launched through the sh watchdog wrapper", client.config.cmd[1] .. " " .. client.config.cmd[2], "sh -c")
      check("wrapper execs node with the server", client.config.cmd[3]:find('exec node "$@"', 1, true) ~= nil and table.concat(client.config.cmd, " "):find(copilot.server, 1, true) ~= nil, true)
      check("exit_timeout set", client.config.exit_timeout, 1000)
      local server_pid = client.rpc and client.rpc.pid or (vim.fn.jobpid and 0)
      -- the exec'd server pid: nvim's child running the server script
      local pid = vim.trim(vim.fn.system({ "pgrep", "-P", tostring(vim.fn.getpid()), "-f", copilot.server }))
      check("server is nvim's direct child (sh exec'd into node)", pid ~= "", true)
      vim.fn.writefile({ pid }, "server.pid")
      local watchdog = vim.trim(vim.fn.system({ "pgrep", "-P", pid }))
      check("watchdog subshell running under the server", watchdog ~= "", true)
      check("server process is node", vim.trim(vim.fn.system({ "ps", "-o", "comm=", "-p", pid })):match("node$") ~= nil, true)
    end
    log("OK")
  end)
  log(ok and "DONE" or ("ERROR: " .. tostring(err)))
  -- stay alive: run.sh SIGKILLs this nvim (by the pid written here, not the
  -- subshell that launched it) to test the watchdog
  vim.fn.writefile({ tostring(vim.fn.getpid()) }, "nvim.pid")
  vim.fn.writefile({ "ready" }, "ready")
end)
