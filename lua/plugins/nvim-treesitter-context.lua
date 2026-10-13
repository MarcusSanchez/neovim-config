return {
  "nvim-treesitter/nvim-treesitter-context",
  event = "VeryLazy",
  opts = {
    mode = "cursor", -- show context for where the cursor is
    -- two *symbols* (impl + fn), not one symbol spilling onto a second line:
    -- each context is capped at a single line, then two of them can stack
    max_lines = 2,
    multiline_threshold = 1,
    -- separator row benched in favor of a background shade on the context
    -- line itself (TreesitterContext in catppuccin.lua)
    -- separator = "─",
  },
}
