-- Skip the dashboard when this directory has a session: `nvim` in a project
-- you've worked in before picks up where you left off (what the dashboard's
-- `s` key does, pressed for you). No session, dashboard as usual.
local M = {}

--- Would a bare `nvim` here show the dashboard? Same conditions snacks uses.
function M.bare_start()
  if vim.fn.argc(-1) > 0 or vim.api.nvim_buf_get_name(1) ~= "" or vim.bo[1].modified then
    return false
  end
  return vim.api.nvim_buf_line_count(1) == 1 and vim.api.nvim_buf_get_lines(1, 0, 1, false)[1] == ""
end

--- The session file persistence.nvim would load for the cwd, if one exists
--- (per-branch first, then the plain one — the same fallback its load() does).
---@return string?
function M.file()
  local ok, persistence = pcall(require, "persistence")
  if not ok then
    return
  end
  for _, file in ipairs({ persistence.current(), persistence.current({ branch = false }) }) do
    if vim.fn.filereadable(file) == 1 then
      return file
    end
  end
end

function M.has_session()
  return M.file() ~= nil
end

--- Is this start going to restore a session (bare `nvim`, session on disk)?
--- Decided once, early (plugin config time), so startup UI can act on it.
function M.restoring()
  if M._restoring == nil then
    M._restoring = vim.fn.argc(-1) == 0 and M.has_session()
  end
  return M._restoring
end

--- Restore the cwd's session, when starting bare and one exists.
function M.restore()
  if M.bare_start() and M.has_session() then
    require("persistence").load()
    return true
  end
  return false
end

return M
