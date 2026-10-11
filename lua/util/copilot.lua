-- Keeps the Copilot language server (a node process) from outliving nvim.
--
-- nvim stops LSP servers by asking politely (shutdown/exit) and, by default,
-- doesn't wait or force anything on quit; when the terminal closes nvim
-- (SIGHUP) no Lua runs at all. The server then lives on only as long as it
-- takes to notice its stdin closing — usually a second or two, but with
-- requests in flight it has been known to stay, orphaned to launchd and
-- holding its memory. Three layers:
--   1. the server is launched through a tiny sh wrapper whose background
--      watchdog kills it as soon as nvim's pid is gone, however nvim went
--   2. the client gets an exit_timeout, so a normal quit waits briefly for
--      the polite shutdown and force-stops the server if it stalls
--   3. at startup, any server already orphaned (parent = launchd) is reaped
local M = {}

M.server = "copilot.lua/copilot/js/language-server.js"

--- `sh -c WRAPPER sh <node args...>`: a watchdog subshell polls nvim's pid
--- ($PPID of the wrapper) and the server's own ($$ survives the exec), and
--- kills the server once nvim is gone; then exec node in place.
-- (a background `&` can't be followed by `;`, hence the plain space)
M.wrapper = "self=$$; "
  .. '( while kill -0 "$PPID" 2>/dev/null && kill -0 "$self" 2>/dev/null; do sleep 2; done; kill "$self" 2>/dev/null ) >/dev/null 2>&1 & '
  .. 'exec node "$@"'

--- The command copilot.lua should launch node through.
function M.node_command()
  return { "sh", "-c", M.wrapper, "sh" }
end

--- Kill copilot servers whose nvim is gone (reparented to launchd, ppid 1).
---@param cb? fun(killed: integer)
function M.reap_orphans(cb)
  -- one ps call lists every process with its parent; filter in Lua. The
  -- callback runs off the main loop, so hop back before touching vim.fn.
  vim.system({ "ps", "-axo", "pid=,ppid=,command=" }, { text = true }, function(res)
    vim.schedule(function()
      local killed = 0
      for line in (res.stdout or ""):gmatch("[^\n]+") do
        local pid, ppid, cmd = line:match("^%s*(%d+)%s+(%d+)%s+(.*)$")
        if pid and ppid == "1" and cmd:find(M.server, 1, true) then
          vim.uv.kill(tonumber(pid), "sigterm")
          killed = killed + 1
        end
      end
      if cb then
        cb(killed)
      end
    end)
  end)
end

function M.setup()
  vim.api.nvim_create_autocmd("User", {
    pattern = "VeryLazy",
    once = true,
    callback = function()
      M.reap_orphans(function(killed)
        if killed > 0 then
          vim.schedule(function()
            vim.notify(
              ("Reaped %d orphaned Copilot server%s"):format(killed, killed == 1 and "" or "s"),
              vim.log.levels.INFO,
              { title = "Copilot" }
            )
          end)
        end
      end)
    end,
  })
end

return M
