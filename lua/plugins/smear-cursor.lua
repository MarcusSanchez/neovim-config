-- The ui.smear-cursor extra (lazyvim.json) is kept installed but off: the
-- trail didn't earn its keep. Flip `enabled` to try it again.
return {
  "sphamba/smear-cursor.nvim",
  event = "VeryLazy",
  enabled = false,
  cond = vim.g.neovide == nil,
  opts = {
    hide_target_hack = true,
    cursor_color = "none",
  },
  specs = {
    -- disable mini.animate cursor
    {
      "nvim-mini/mini.animate",
      optional = true,
      opts = {
        cursor = { enable = false },
      },
    },
  },
}
