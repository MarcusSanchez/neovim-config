-- Rainbow brackets. Deliberate: the per-block query for Lua (keyword
-- blocks have no brackets), parens-only for TSX (tags get their own
-- colours), the local strategy for Vimscript (the plugin's own advice),
-- and Lua's higher priority so its block highlights win over treesitter's.
return {
  "HiPhish/rainbow-delimiters.nvim",
  event = "VeryLazy",
  main = "rainbow-delimiters.setup",
  opts = {
    strategy = {
      [""] = "rainbow-delimiters.strategy.global",
      vim = "rainbow-delimiters.strategy.local",
    },
    query = {
      [""] = "rainbow-delimiters",
      lua = "rainbow-blocks",
      tsx = "rainbow-parens",
    },
    priority = {
      [""] = 110,
      lua = 210,
    },
    highlight = {
      "RainbowDelimiterYellow",
      "RainbowDelimiterViolet",
      "RainbowDelimiterRed",
      "RainbowDelimiterBlue",
      "RainbowDelimiterCyan",
      "RainbowDelimiterOrange",
    },
  },
}
