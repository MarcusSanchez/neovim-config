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
    -- newer states sit higher in the tree; with j/k swapped, J should climb
    -- to the next (newer) state and K drop to the previous (older) one —
    -- the plugin's own defaults are the other way round
    vim.cmd([[
      function! g:Undotree_CustomMap()
        nmap <buffer> J <plug>UndotreeNextState
        nmap <buffer> K <plug>UndotreePreviousState
      endfunc
    ]])
  end,
}
