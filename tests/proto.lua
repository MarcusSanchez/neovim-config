-- protobuf via buf: buf_ls attaches, reports buf lint, navigates across
-- files; buf format runs on an explicit save. Opens acme/v1/user.proto in
-- the proto fixture module (buf.yaml with STANDARD lint).
local logf = io.open(vim.fn.getcwd() .. "/result.log", "w")
local function log(s) logf:write(s, "\n"); logf:flush() end
local function check(name, got, want) log(("%s %s: %s (want %s)"):format(got == want and "PASS" or "FAIL", name, tostring(got), tostring(want))) end
local function wait(ms) vim.wait(ms, function() return false end) end
vim.defer_fn(function() log("TIMEOUT"); vim.cmd("qall!") end, 120000)
vim.schedule(function()
  local ok, err = pcall(function()
    vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
    check("filetype", vim.bo.filetype, "proto")
    check("treesitter proto parser", (pcall(vim.treesitter.language.add, "proto")), true)
    local function client() return vim.lsp.get_clients({ bufnr = 0, name = "buf_ls" })[1] end
    vim.wait(30000, function() return client() ~= nil end, 200)
    check("buf_ls attached", client() ~= nil, true)
    -- lint: userName breaks FIELD_LOWER_SNAKE_CASE
    local lint
    vim.wait(30000, function()
      for _, d in ipairs(vim.diagnostic.get(0)) do
        if (d.code == "FIELD_LOWER_SNAKE_CASE") or d.message:find("lower_snake_case", 1, true) then lint = d; return true end
      end
      return false
    end, 250)
    check("buf lint diagnostic on userName (line 8)", lint and lint.lnum + 1, 8)
    -- gd on Address jumps into common.proto
    vim.wait(20000, function() return vim.fn.maparg("gd", "n", false, true).callback ~= nil end, 100)
    vim.api.nvim_win_set_cursor(0, { 9, 4 })
    vim.fn.maparg("gd", "n", false, true).callback(); wait(2000)
    check("gd on Address", vim.fn.expand("%:t") .. ":" .. vim.fn.line("."), "common.proto:5")
    -- buf format on explicit save; autosave leaves formatting alone
    vim.cmd("edit acme/v1/user.proto")
    vim.api.nvim_buf_set_lines(0, 9, 10, false, { "}", "message   Extra{string   note=1;}" })
    vim.api.nvim_exec_autocmds("InsertLeave", { buffer = 0 }); wait(500)
    check("autosave kept the messy line", vim.fn.readfile("acme/v1/user.proto")[11], "message   Extra{string   note=1;}")
    local fmt = require("conform").list_formatters_to_run(0)
    check("conform formatter for proto", fmt[1] and fmt[1].name, "buf")
    vim.cmd("write"); wait(1500)
    local lines = vim.fn.readfile("acme/v1/user.proto")
    check(":w formats with buf", table.concat(lines, "\n"):find("message Extra {", 1, true) ~= nil, true)
    log("OK")
  end)
  log(ok and "DONE" or ("ERROR: " .. tostring(err)))
  vim.cmd("qall!")
end)
