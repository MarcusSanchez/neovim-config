-- The file-explorer sidebar: open/focus/close helpers shared by the ,a/,c
-- keymaps, the :q-on-last-window autocmd and the session hooks.
-- Two backends behind one API, picked by vim.g.explorer:
--   "snacks"    the snacks picker explorer (current)
--   "neo-tree"  benched 2026-10-11 (lua/benched/neo-tree.lua says how to revive)
local M = {}

M.backend = vim.g.explorer or "snacks"

-- the sidebar's own filetypes: neo-tree's, and the snacks explorer's
-- layout box, list and input (a snacks terminal or dashboard is not a
-- sidebar; a picker's floats are filtered by their window)
local sidebar_filetypes = {
  ["neo-tree"] = true,
  snacks_layout_box = true,
  snacks_picker_list = true,
  snacks_picker_input = true,
}

--- Is this buffer a sidebar buffer (either backend)?
function M.is_sidebar_buf(buf)
  return sidebar_filetypes[vim.bo[buf].filetype] == true
end

--- The sidebar's windows on the current tab: non-floating windows showing
--- a sidebar buffer.
---@return integer[]
function M.sidebar_wins()
  local wins = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(win).relative == "" and M.is_sidebar_buf(vim.api.nvim_win_get_buf(win)) then
      wins[#wins + 1] = win
    end
  end
  return wins
end

local backends = {}

backends["neo-tree"] = {
  get = function()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.api.nvim_win_get_config(win).relative == "" and vim.b[buf].neo_tree_source == "filesystem" then
        return win
      end
    end
  end,
  is_focused = function(win)
    return vim.api.nvim_get_current_win() == win
  end,
  open = function(focus)
    require("neo-tree.command").execute({
      action = focus and "focus" or "show",
      source = "filesystem",
      position = "right",
      dir = LazyVim.root(),
    })
  end,
  focus = function()
    require("neo-tree.command").execute({ action = "focus", source = "filesystem", position = "right" })
  end,
  close = function()
    require("neo-tree.command").execute({ action = "close", source = "filesystem", position = "right" })
  end,
}

backends.snacks = {
  get = function()
    if not package.loaded["snacks"] then
      return
    end
    local explorer = Snacks.picker.get({ source = "explorer" })[1]
    if explorer and not explorer.closed then
      return explorer
    end
  end,
  is_focused = function(explorer)
    return explorer:is_focused()
  end,
  open = function(focus)
    Snacks.explorer({
      cwd = LazyVim.root(),
      on_show = not focus and function(picker)
        if picker.main and vim.api.nvim_win_is_valid(picker.main) then
          vim.api.nvim_set_current_win(picker.main)
        end
      end or nil,
    })
  end,
  focus = function(explorer)
    explorer:focus()
  end,
  close = function(explorer)
    explorer:close()
  end,
}

local function b()
  return backends[M.backend] or backends.snacks
end

--- The open explorer on this tab (a window id or picker), or nil.
function M.get()
  return b().get()
end

--- Open the explorer at the project root; focus it if it's open; close it if
--- it's already focused.
function M.toggle()
  local explorer = M.get()
  if not explorer then
    b().open(true)
  elseif b().is_focused(explorer) then
    b().close(explorer)
  else
    b().focus(explorer)
  end
end

--- Open the explorer without taking focus (session restore).
function M.open_unfocused()
  if not M.get() then
    b().open(false)
  end
end

--- Close the explorer (no-op when it's already closed).
function M.close()
  local explorer = M.get()
  if explorer then
    b().close(explorer)
  end
end

--- Number of non-floating windows on the current tab that aren't sidebar
--- windows (either backend's).
---@return integer
function M.real_window_count()
  local real = 0
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(win).relative == "" and not M.is_sidebar_buf(vim.api.nvim_win_get_buf(win)) then
      real = real + 1
    end
  end
  return real
end

local quit_pending = false -- a qall scheduled by on_quit_pre, not yet run

--- QuitPre handler: when :q closes the last real window, quit nvim entirely
--- instead of leaving the sidebar behind. A :q in the sidebar itself or in
--- a float closes just that.
function M.on_quit_pre()
  if not M.get() then
    return
  end
  local cur = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_config(cur).relative ~= "" or M.is_sidebar_buf(vim.api.nvim_win_get_buf(cur)) then
    return
  end
  if M.real_window_count() <= 1 then
    -- scheduled so the original :q finishes first; if it aborts on a
    -- modified buffer, qall raises the same E37 rather than force-quitting
    quit_pending = true
    vim.schedule(function()
      if not quit_pending or vim.v.exiting ~= vim.NIL then
        return
      end
      quit_pending = false
      vim.cmd("qall")
    end)
  end
end

--- ExitPre handler: Vim is exiting on its own (:qa, :wqa, the last :q),
--- so the qall on_quit_pre scheduled must not run. It would: Neovim's
--- exit waits for language servers to stop and runs scheduled callbacks
--- meanwhile, and a qall nested in the exit ends the process at once —
--- before VimLeavePre, so the session was never saved.
function M.on_exit_pre()
  quit_pending = false
end

return M
