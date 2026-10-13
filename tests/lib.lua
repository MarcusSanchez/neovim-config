-- Shared scaffolding for the suites: a result log, PASS/FAIL checks and
-- waits (`open`), and for the server-backed suites a body that runs once
-- the named language server is attached and util/foldranges.lua has its
-- ranges, with the ,d helpers (`suite`).
local M = {}

---@class tests.Helpers
---@field log fun(s: string)
---@field check fun(name: string, got: any, want: any)
---@field wait fun(ms: integer)

--- The result log at `path` ("w" unless `mode` says "a": a second pass
--- appends) and the checks that write to it.
---@return tests.Helpers
function M.open(path, mode)
  local logf = assert(io.open(path, mode or "w"))
  local t = {} ---@type tests.Helpers
  function t.log(s)
    logf:write(s, "\n")
    logf:flush()
  end
  function t.check(name, got, want)
    t.log(("%s %s: %s (want %s)"):format(got == want and "PASS" or "FAIL", name, tostring(got), tostring(want)))
  end
  function t.wait(ms)
    vim.wait(ms, function()
      return false
    end)
  end
  return t
end

---@class tests.Suite : tests.Helpers
---@field ranges fun(timeout?: integer): boolean wait for the server's ranges in the current buffer, then settle
---@field fold fun(l: integer) ,d on line l
---@field span fun(l: integer): string "start..end" of the closed fold at l, "-1..-1" if open
---@field shape fun(l: integer, span: string, text: string) open all, ,d on l, check span and fold line

---@param server string the language server to wait for
---@param body fun(t: tests.Suite)
---@param opts? { treesitter?: boolean, timeout?: integer, deadline?: integer }
--- treesitter: the language's folds are treesitter's (no server ranges);
--- timeout: ms to wait for the server to attach, and again for its ranges
--- (30000 / 15000); deadline: ms for the whole suite (120000), what
--- actually bounds it
function M.suite(server, body, opts)
  opts = opts or {}
  local t = M.open(vim.fn.expand("%:p:h") .. "/result.log") ---@cast t tests.Suite
  local FR = require("util.foldranges")
  function t.ranges(timeout)
    vim.wait(timeout or opts.timeout or 15000, function()
      return FR.has(0)
    end, 50)
    t.wait(300)
    return FR.has(0)
  end
  function t.fold(l) -- what the ,d mapping does (config/keymaps.lua)
    vim.cmd(("normal! %dG"):format(l))
    FR.toggle()
    require("util.foldcursor").refresh()
  end
  function t.span(l)
    return vim.fn.foldclosed(l) .. ".." .. vim.fn.foldclosedend(l)
  end
  function t.shape(l, want_span, want_text)
    vim.cmd("normal! zR")
    t.fold(l)
    t.check(
      "fold at " .. l,
      t.span(l) .. " " .. vim.fn.foldtextresult(vim.fn.foldclosed(l)),
      want_span .. " " .. want_text
    )
  end
  vim.defer_fn(function()
    t.log("TIMEOUT")
    vim.cmd("qall!")
  end, opts.deadline or 120000)
  vim.schedule(function()
    local ok, err = pcall(function()
      vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
      vim.o.lines, vim.o.columns = 40, 120
      vim.wait(opts.timeout or 30000, function()
        return #vim.lsp.get_clients({ bufnr = 0, name = server }) > 0
      end, 100)
      if opts.treesitter then
        t.wait(1500)
        t.check("folds are treesitter's (no server ranges)", FR.has(0), false)
      else
        t.check("folds come from " .. server, t.ranges(), true)
      end
      t.check("the fold expression is ours", vim.wo.foldexpr, "v:lua.require('util.foldranges').foldexpr()")
      body(t)
      vim.cmd("normal! zR")
    end)
    t.log(ok and "DONE" or ("ERROR: " .. tostring(err)))
    vim.cmd("qall!")
  end)
end

return M
