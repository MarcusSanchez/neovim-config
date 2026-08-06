return {
  "folke/snacks.nvim",
  opts = {
    dashboard = {
      preset = {
        header = "Welcome to Costco. I love you.",
      },
      sections = {
        { section = "header", padding = 3 },
        { section = "keys", gap = 1, padding = 1 },
        { section = "startup" },
      },
    },
  },
}
