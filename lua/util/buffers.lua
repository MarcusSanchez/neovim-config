-- What several features need to know about buffers.
local M = {}

--- An unnamed, unmodified, empty scratch buffer: the `[No Name]` a bare
--- `nvim` starts on, or one left behind — a placeholder, not a tab worth
--- keeping. False for a buffer that isn't loaded.
function M.is_placeholder(buf)
  return vim.api.nvim_buf_is_loaded(buf)
    and vim.api.nvim_buf_get_name(buf) == ""
    and vim.bo[buf].buftype == ""
    and not vim.bo[buf].modified
    and vim.api.nvim_buf_line_count(buf) == 1
    and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
end

return M
