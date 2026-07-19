return {
  "folke/snacks.nvim",
  keys = {
    {
      "<leader>db",
      function()
        Snacks.dashboard()
      end,
      desc = "Open Snacks Dashboard",
    },
  },
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
