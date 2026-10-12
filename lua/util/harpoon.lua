-- Harpoon jumps that respect an empty buffer: a harpooned file opened from
-- a fresh `[No Name]` buffer replaces it instead of leaving it behind as a
-- tab.
local M = {}

--- An unnamed, unmodified, empty scratch buffer: a placeholder, not a tab
--- worth keeping.
local function placeholder(buf)
  return vim.api.nvim_buf_is_valid(buf)
    and vim.api.nvim_buf_get_name(buf) == ""
    and vim.bo[buf].buftype == ""
    and not vim.bo[buf].modified
    and vim.api.nvim_buf_line_count(buf) == 1
    and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
end

--- harpoon2's `default.select`, plus: when the jump leaves a placeholder
--- buffer behind in no window, wipe it.
function M.select(item, list, opts)
  local before = vim.api.nvim_get_current_buf()
  local was_placeholder = placeholder(before)
  require("harpoon.config").get_default_config().default.select(item, list, opts)
  if was_placeholder and vim.api.nvim_get_current_buf() ~= before and vim.fn.bufwinid(before) == -1 then
    pcall(vim.api.nvim_buf_delete, before, { force = false })
  end
end

return M
