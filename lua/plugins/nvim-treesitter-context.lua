return {
  "nvim-treesitter/nvim-treesitter-context",
  event = "VeryLazy",
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  config = function()
    require("treesitter-context").setup({
      -- You can add options here or leave empty for defaults
      mode = "cursor", -- Show context for where the cursor is
      max_lines = 1, -- How many lines the context window can span
      -- separator row benched in favor of a background shade on the context
      -- line itself (TreesitterContext in catppuccin.lua)
      -- separator = "─",
    })
  end,
}
