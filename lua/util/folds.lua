-- Folds persist across sessions, like IntelliJ: when a file leaves a window
-- its fold state is written to a view (vim's per-file :mkview under
-- 'viewdir'), and reopening the file restores it. 'viewoptions' is cut down
-- to folds only, so views never drag cursor position, options or cwd along.
--
-- Folds are remembered by line number, so edits made outside nvim can shift
-- them; a quick zR/zM clears any that landed wrong.
local M = {}

local function real_file(buf)
  return vim.bo[buf].buftype == ""
    and vim.api.nvim_buf_get_name(buf) ~= ""
    and vim.fn.filereadable(vim.api.nvim_buf_get_name(buf)) == 1
end

function M.save(buf)
  if real_file(buf) then
    pcall(vim.cmd, "silent! mkview")
  end
end

function M.load(buf)
  if real_file(buf) then
    pcall(vim.cmd, "silent! loadview")
  end
end

function M.setup()
  vim.opt.viewoptions = { "folds" }
  local group = vim.api.nvim_create_augroup("remember_folds", { clear = true })
  vim.api.nvim_create_autocmd({ "BufWinLeave", "BufWritePost" }, {
    group = group,
    callback = function(ev)
      M.save(ev.buf)
    end,
  })
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    callback = function(ev)
      M.load(ev.buf)
    end,
  })
end

return M
