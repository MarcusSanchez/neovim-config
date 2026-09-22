-- The snacks explorer sidebar: open/focus/close helpers shared by the ,a/,c
-- keymaps and the :q-on-last-window autocmd.
local M = {}

--- The open explorer picker on this tab, or nil when it's closed.
---@return snacks.Picker?
function M.get()
  if not package.loaded["snacks"] then
    return
  end
  local explorer = Snacks.picker.get({ source = "explorer" })[1]
  if explorer and not explorer.closed then
    return explorer
  end
end

--- Open the explorer at the project root; focus it if it's open; close it if
--- it's already focused.
function M.toggle()
  local explorer = M.get()
  if not explorer then
    Snacks.explorer({ cwd = LazyVim.root() })
  elseif explorer:is_focused() then
    explorer:close()
  else
    explorer:focus()
  end
end

--- Close the explorer (no-op when it's already closed).
function M.close()
  local explorer = M.get()
  if explorer then
    explorer:close()
  end
end

--- Number of non-floating windows on the current tab that aren't snacks
--- pickers (the explorer included).
---@return integer
function M.real_window_count()
  local real = 0
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(win).relative == "" then
      local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
      if not ft:find("^snacks_") then
        real = real + 1
      end
    end
  end
  return real
end

--- QuitPre handler: when :q closes the last real window, quit nvim entirely
--- instead of leaving the explorer behind (closing just the explorer isn't
--- enough — snacks re-seats it on an empty scratch buffer).
function M.on_quit_pre()
  if not M.get() then
    return
  end
  if M.real_window_count() <= 1 then
    -- scheduled so the original :q finishes first; if it aborts on a
    -- modified buffer, qall raises the same E37 rather than force-quitting
    vim.schedule(function()
      vim.cmd("qall")
    end)
  end
end

return M
