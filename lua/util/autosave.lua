-- Autosave like Zed (`autosave.after_delay`), but only from normal mode:
-- nothing is written while typing in insert mode; leaving insert counts as a
-- normal-mode change, so the save lands `delay` ms after `jj`. Like Zed,
-- these saves skip format-on-save — only an explicit :w / ,f formats — so
-- cargo check / golangci-lint / eslint get pause-triggered diagnostics
-- without the buffer being reshuffled mid-thought.
local M = {}

local timers = {} ---@type table<integer, uv.uv_timer_t>

---@param buf integer
local function save(buf)
  timers[buf] = nil
  if not vim.api.nvim_buf_is_valid(buf) or not vim.bo[buf].modified then
    return
  end
  local name = vim.api.nvim_buf_get_name(buf)
  if vim.bo[buf].buftype ~= "" or name == "" or not vim.bo[buf].modifiable or vim.bo[buf].readonly then
    return
  end
  if vim.fn.filewritable(name) ~= 1 then
    return -- unsaved new file, or not ours to write
  end
  vim.api.nvim_buf_call(buf, function()
    local autoformat = vim.b[buf].autoformat
    vim.b[buf].autoformat = false
    -- silent!: a file changed on disk (E13/E211) shouldn't raise on a timer
    pcall(vim.cmd, "silent! update")
    vim.b[buf].autoformat = autoformat
  end)
end

---@param opts? { delay?: integer } delay in ms (default 300)
function M.setup(opts)
  local delay = opts and opts.delay or 300
  vim.api.nvim_create_autocmd("TextChanged", {
    group = vim.api.nvim_create_augroup("autosave_after_delay", { clear = true }),
    callback = function(ev)
      local timer = timers[ev.buf]
      if timer then
        timer:stop()
        timer:close()
      end
      timers[ev.buf] = vim.defer_fn(function()
        save(ev.buf)
      end, delay)
    end,
  })
end

return M
