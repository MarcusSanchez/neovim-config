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

--- Quitting with no file open means there is nothing to come back to:
--- forget the directory's session, so the next bare `nvim` here shows the
--- dashboard instead of restoring whatever the previous visit left.
--- (persistence.nvim only skips the save in that case; the old file would
--- stay and be restored.) Same count of file buffers it uses.
function M.forget_if_empty()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if
      vim.bo[b].buftype == ""
      and vim.api.nvim_buf_get_name(b) ~= ""
      and not vim.tbl_contains({ "gitcommit", "gitrebase", "jj" }, vim.bo[b].filetype)
    then
      return false
    end
  end
  local ok, persistence = pcall(require, "persistence")
  if not ok then
    return false
  end
  for _, file in ipairs({ persistence.current(), persistence.current({ branch = false }) }) do
    if vim.fn.filereadable(file) == 1 then
      vim.fn.delete(file)
    end
  end
  return true
end

--- Keep the explorer sidebar out of the session file: its scratch buffer
--- comes back as an empty split with a [No Name] buffer. Close it before
--- the save, remember that it was open (a global the session's "globals"
--- option carries), and reopen it after the load.
function M.setup()
  local group = vim.api.nvim_create_augroup("session_explorer", { clear = true })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = M.forget_if_empty,
  })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "PersistenceSavePre",
    callback = function()
      -- by now snacks has flagged its pickers closed but their windows are
      -- still in the layout, so go by the windows: any non-floating window
      -- showing a snacks buffer is the sidebar
      local had = false
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if
          vim.api.nvim_win_get_config(win).relative == ""
          and require("util.explorer").is_sidebar_buf(vim.api.nvim_win_get_buf(win))
        then
          had = true
          pcall(vim.api.nvim_win_close, win, true)
        end
      end
      -- decided once per exit: the hook can run again (a retried quit) after
      -- the sidebar is already gone, and must not downgrade a 1 to a 0
      if M._exit_explorer == nil then
        M._exit_explorer = had
      end
      vim.g.SessionExplorer = M._exit_explorer and 1 or 0
      require("util.explorer").close()
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "PersistenceLoadPost",
    -- nested: wiping the empty buffer a window is on makes Vim load the
    -- next listed file into it, and that load's BufRead/FileType events
    -- (filetype, treesitter, LSP) only fire from inside an autocmd when
    -- it's nested. A session saved with no file window focused restores
    -- exactly this way, and came back as a file with no highlighting or LSP.
    nested = true,
    callback = function()
      -- anything the layout left behind as an empty unnamed buffer
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if
          vim.api.nvim_buf_is_loaded(b)
          and vim.api.nvim_buf_get_name(b) == ""
          and vim.bo[b].buftype == ""
          and not vim.bo[b].modified
          and vim.api.nvim_buf_line_count(b) == 1
          and vim.api.nvim_buf_get_lines(b, 0, 1, false)[1] == ""
          and #vim.api.nvim_list_bufs() > 1
        then
          pcall(vim.api.nvim_buf_delete, b, { force = true })
        end
      end
      if vim.g.SessionExplorer == 1 then
        vim.schedule(function()
          require("util.explorer").open_unfocused()
        end)
      end
    end,
  })
end

return M
