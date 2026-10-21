-- Flash (LazyVim's `s`, and the f/F/t/T/;/, motions it owns) on closed
-- folds: matches on the drawn fold line, labelled there, jumped to with
-- the caret and the fold closed; hidden text ignored (lua/util/flashfolds.lua)
return {
  "folke/flash.nvim",
  opts = function(_, opts)
    local ff = require("util.flashfolds")
    opts.matcher = ff.matcher
    opts.labeler = ff.labeler
    opts.label = opts.label or {}
    opts.label.format = ff.format
  end,
  config = function(_, opts)
    require("flash").setup(opts)
    require("util.flashfolds").setup()
  end,
}
