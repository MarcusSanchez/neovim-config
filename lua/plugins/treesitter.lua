return {
  "nvim-treesitter/nvim-treesitter",
  opts = {
    -- LazyVim would set every treesitter buffer's fold expression to its
    -- own; folds come from lua/util/foldranges.lua (one expression, set in
    -- config/options.lua, that uses treesitter's levels itself until the
    -- language server's ranges arrive)
    folds = { enable = false },
  },
}
