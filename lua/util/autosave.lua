-- Autosave, but never mid-typing: leaving insert mode (`jj`) writes the
-- buffer immediately, so cargo check / golangci-lint / eslint report on what
-- was just typed; edits made in normal mode (dd, p, ...) are written `delay`
-- ms after the last one, like Zed's autosave.after_delay. These saves skip
-- format-on-save — only an explicit :w / ,f formats — so the buffer isn't
-- reshuffled mid-thought.
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

---@param buf integer
local function cancel(buf)
  local timer = timers[buf]
  if timer then
    timer:stop()
    timer:close()
    timers[buf] = nil
  end
end

---@param opts? { delay?: integer } normal-mode debounce in ms (default 300)
function M.setup(opts)
  local delay = opts and opts.delay or 300
  local group = vim.api.nvim_create_augroup("autosave", { clear = true })
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = group,
    callback = function(ev)
      cancel(ev.buf)
      -- scheduled: a write from inside an autocmd callback fires no nested
      -- autocmds, and BufWritePost is what sends didSave to the LSP (cargo
      -- check) and runs nvim-lint
      vim.schedule(function()
        save(ev.buf)
      end)
    end,
  })
  vim.api.nvim_create_autocmd("TextChanged", {
    group = group,
    callback = function(ev)
      cancel(ev.buf)
      timers[ev.buf] = vim.defer_fn(function()
        save(ev.buf)
      end, delay)
    end,
  })
end

return M
