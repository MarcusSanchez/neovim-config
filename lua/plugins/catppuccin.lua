return {
  "catppuccin/nvim",
  name = "catppuccin",
  lazy = false,
  priority = 1000,
  semantic_tokens = true,
  config = function()
    require("catppuccin").setup({
      flavour = "mocha",
      transparent_background = true,
      integrations = {
        cmp = true,
        semantic_tokens = true,
        gitsigns = true,
        nvimtree = true,
        treesitter = true,
        telescope = true,
      },
      highlight_overrides = {
        mocha = function(colors)
          return {
            ["@function.builtin"] = { fg = colors.blue },
            ["@field"] = { fg = colors.red },
            ["@property"] = { fg = colors.red },
            ["@namespace"] = { fg = colors.text, style = { "italic" } },
            ["@variable"] = { fg = colors.subtext1 },
            ["@parameter"] = { fg = "#dabb9b" },
            ["@variable.parameter"] = { fg = "#dabb9b" },
            ["@number"] = { fg = colors.sapphire },
            ["@operator"] = { fg = "#ff6ca9" },
            ["@type"] = { fg = colors.yellow },

            -- golang
            ["@lsp.typemod.variable.defaultLibrary.go"] = { fg = colors.peach },
            ["@lsp.typemod.variable.readonly.go"] = { fg = colors.peach }, -- sometimes used for constants
            ["@lsp.type.namespace.go"] = { fg = colors.subtext1, style = { "italic" } },
            ["@lsp.typemod.variable.member.go"] = { fg = colors.red },
            ["@lsp.typemod.variable.declaration.go"] = { fg = colors.red },
            ["@variable.member.go"] = { fg = colors.red },

            -- JS/TS/JSX/TSX
            ["@tag.builtin"] = { fg = colors.red },
            ["@tag.attribute"] = { fg = "#dabb9b" },
            ["@tag.attribute.tsx"] = { fg = "#dabb9b" },
            ["@tag.tsx"] = { fg = colors.yellow },
            -- ["@_jsx_attribute"] = { fg = "#dabb9b" },
            -- ["@_jsx_element"] = { fg = colors.red },
          }
        end,
      },
    })
    vim.cmd.colorscheme("catppuccin-mocha")
  end,
}
