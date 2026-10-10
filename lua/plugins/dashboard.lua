-- The dashboard banner: the Costco one-liner (the cus experiments — the
-- isometric slice, then larry3d — live in git history if the mood returns;
-- keep any future ascii header right-stripped, trailing whitespace shifts
-- snacks' centering).
return {
  "folke/snacks.nvim",
  -- a function, not a table: the session check needs persistence.nvim, which
  -- lazy can only pull in once plugins are loading, not while specs are read
  opts = function(_, opts)
    local restoring = require("util.session").restoring()
    if restoring then
      -- options.lua lets nvim's stock intro show when the dashboard doesn't
      -- draw; here that would flash until the session lands — keep the
      -- screen an empty buffer instead
      vim.opt.shortmess:append("I")
    end
    opts.dashboard = vim.tbl_deep_extend("force", opts.dashboard or {}, {
      -- a bare `nvim` in a directory with a saved session restores it
      -- instead (lua/util/session.lua, run from config/autocmds.lua once
      -- everything has loaded); the dashboard only shows when there's
      -- nothing to pick up
      enabled = not restoring,
      preset = {
        header = "Welcome to Costco. I love you.",
      },
      sections = {
        { section = "header", padding = 3 },
        { section = "keys", gap = 1, padding = 1 },
        { section = "startup" },
      },
    })
  end,
}
