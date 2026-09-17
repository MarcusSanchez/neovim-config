return {
  "nvim-treesitter/nvim-treesitter-context",
  event = "VeryLazy",
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  config = function()
    require("treesitter-context").setup({
      -- You can add options here or leave empty for defaults
      mode = "cursor", -- Show context for where the cursor is
      -- two *symbols* (impl + fn), not one symbol spilling onto a second line:
      -- each context is capped at a single line, then two of them can stack
      max_lines = 2,
      multiline_threshold = 1,
      -- separator row benched in favor of a background shade on the context
      -- line itself (TreesitterContext in catppuccin.lua)
      -- separator = "─",
    })
  end,
}
