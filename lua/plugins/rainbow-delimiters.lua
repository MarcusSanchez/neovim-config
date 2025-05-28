return {
  "HiPhish/rainbow-delimiters.nvim",
  event = "VeryLazy",
  config = function()
    require("rainbow-delimiters.setup").setup({
      blacklist = {
        "html",
        "jsx",
        "tsx",
      },
      strategy = {
        [""] = "rainbow-delimiters.strategy.global",
        vim = "rainbow-delimiters.strategy.local",
      },
      query = {
        [""] = "rainbow-delimiters",
        lua = "rainbow-blocks",
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
    })
  end,
}
