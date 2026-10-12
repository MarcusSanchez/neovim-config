-- Shared scaffolding for the fold-shape suites: a result log beside the
-- fixture, PASS/FAIL checks, waits, and the ,d helpers. A suite calls
-- `suite(server, function(t) ... end)`; the body runs once the named
-- language server is attached and util/foldranges.lua has its ranges.
local M = {}

---@class tests.Suite
---@field log fun(s: string)
---@field check fun(name: string, got: any, want: any)
---@field wait fun(ms: integer)
---@field fold fun(l: integer) ,d on line l
---@field span fun(l: integer): string "start..end" of the closed fold at l, "-1..-1" if open
---@field shape fun(l: integer, span: string, text: string) open all, ,d on l, check span and fold line

function M.suite(server, body)
  local logf = io.open(vim.fn.expand("%:p:h") .. "/result.log", "w")
  local t = {} ---@type tests.Suite
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
  local FR = require("util.foldranges")
  function t.fold(l)
    vim.cmd(("normal! %dG"):format(l))
    FR.toggle()
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
  end, 120000)
  vim.schedule(function()
    local ok, err = pcall(function()
      vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
      vim.o.lines, vim.o.columns = 40, 120
      vim.wait(30000, function()
        return #vim.lsp.get_clients({ bufnr = 0, name = server }) > 0
      end, 100)
      vim.wait(15000, function()
        return FR.has(0)
      end, 50)
      t.wait(300)
      t.check("folds come from " .. server, FR.has(0), true)
      body(t)
      vim.cmd("normal! zR")
    end)
    t.log(ok and "DONE" or ("ERROR: " .. tostring(err)))
    vim.cmd("qall!")
  end)
end

return M
