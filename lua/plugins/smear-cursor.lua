return {
  "sphamba/smear-cursor.nvim",
  opts = {
    smear_between_buffers = false,
  },
  init = function()
    local smear = require("smear_cursor")

    smear.setup({
      color = "#2e5d9e",
      stiffness = 0.5,
      trailing_stiffness = 0.49,
      never_draw_over_target = false,
    })
  end,
}
