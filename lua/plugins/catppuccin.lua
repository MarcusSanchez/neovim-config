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
        all = function(colors)
          local fall = "#dabb9b"
          local cherry_blossom = "#ff6ca9"

          return {
            ["@function.builtin"] = { fg = colors.blue },
            ["@field"] = { fg = colors.red },
            ["@property"] = { fg = colors.red },
            ["@namespace"] = { fg = colors.text, style = { "italic" } },
            ["@variable"] = { fg = colors.subtext1 },
            ["@variable.member"] = { fg = colors.red },
            ["@parameter"] = { fg = fall },
            ["@variable.parameter"] = { fg = fall },
            ["@number"] = { fg = colors.sapphire },
            ["@operator"] = { fg = cherry_blossom },
            ["@type"] = { fg = colors.yellow },
            ["@punctuation.delimiter"] = { fg = colors.subtext1 },
            ["@punctuation.special"] = { fg = cherry_blossom },
            DiagnosticUnderlineError = { fg = colors.red, style = { "bold", "italic", "undercurl" } },
            DiagnosticUnderlineWarn = { style = { "underline" } },

            -- golang
            ["@lsp.typemod.variable.defaultLibrary.go"] = { fg = colors.peach },
            ["@lsp.typemod.variable.readonly.go"] = { fg = colors.peach }, -- sometimes used for constants
            ["@lsp.type.namespace.go"] = { fg = colors.subtext1, style = { "italic" } },
            ["@lsp.type.parameter.go"] = { fg = fall },
            ["@lsp.typemod.variable.member.go"] = { fg = colors.red },
            ["@lsp.typemod.variable.declaration.go"] = { fg = colors.red },
            ["@variable.member.go"] = { fg = colors.red },

            -- JS/TS/JSX/TSX
            ["@keyword.operator.tsx"] = { fg = colors.mauve },
            ["@keyword.operator.ts"] = { fg = colors.mauve },
            ["@tag.builtin"] = { fg = colors.red },
            ["@tag.attribute"] = { fg = fall },
            ["@tag.attribute.tsx"] = { fg = fall },
            ["@tag.tsx"] = { fg = colors.yellow },
            ["@tag.delimiter"] = { link = "@punctuation.bracket" },

            -- gleam
            ["@label.gleam"] = { fg = fall },
            ["@constructor.gleam"] = { fg = colors.yellow },
          }
        end,
      },
    })
    vim.cmd.colorscheme("catppuccin-mocha")
  end,
}
