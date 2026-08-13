-- Undo history as a browsable tree — with LazyVim's persistent undofile this
-- allows time-travel through past states across sessions.
return {
  "mbbill/undotree",
  cmd = "UndotreeToggle",
  keys = {
    { ",u", "<cmd>UndotreeToggle<cr>", desc = "Toggle Undo Tree" },
  },
  init = function()
    -- jump into the tree window on open; q closes it from there
    vim.g.undotree_SetFocusWhenToggle = 1
  end,
}
