return {
  "catppuccin/nvim",
  name = "catppuccin",
  lazy = false, -- Load during startup, not lazily
  priority = 1000, -- Load before other plugins
  semantic_tokens = true,
  config = function()
    require("catppuccin").setup({
      flavour = "mocha",
      transparent_background = true,
      integrations = {
        cmp = true,
        -- native_lsp = { enabled = true },
        semantic_tokens = true,
        gitsigns = true,
        nvimtree = true,
        treesitter = true,
        telescope = true,
        -- add more integrations as needed
      },
      highlight_overrides = {
        all = function(colors)
          return {
            ["@function.builtin"] = { fg = colors.blue },
          }
        end,
      },
    })
    vim.cmd.colorscheme("catppuccin-mocha") -- Use the full name for the flavor
  end,
}
