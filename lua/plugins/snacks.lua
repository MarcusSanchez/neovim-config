local map = vim.keymap.set
local snacks = require("snacks")

return {
  "folke/snacks.nvim",

  map("n", "<leader>db", function()
    snacks.dashboard()
  end, { desc = "Open Snacks Dashboard" }),

  opts = {
    picker = {
      win = {
        input = {
          keys = {
            ["k"] = "list_down",
            ["j"] = "list_up",
          },
        },
        list = {
          keys = {
            ["k"] = "list_down",
            ["j"] = "list_up",
          },
        },
      },
    },
  },
}
