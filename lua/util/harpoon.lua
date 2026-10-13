-- Harpoon jumps that respect an empty buffer: a harpooned file opened from
-- a fresh `[No Name]` buffer replaces it instead of leaving it behind as a
-- tab.
local M = {}

local placeholder = require("util.buffers").is_placeholder

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
