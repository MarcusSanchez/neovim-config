return {
  "folke/snacks.nvim",
  vim.keymap.set("n", "<leader>db", function()
    require("snacks").dashboard()
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
