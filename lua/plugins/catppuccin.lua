return {
  "catppuccin/nvim",
  name = "catppuccin",
  lazy = false,
  priority = 1000,
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
            ["@keyword"] = { fg = colors.mauve, style = { "italic" } },
            ["@function.builtin"] = { fg = colors.blue },
            ["@field"] = { fg = colors.red },
            ["@property"] = { fg = colors.red },
            ["@namespace"] = { fg = colors.subtext1, style = { "italic" } },
            ["@variable"] = { fg = colors.subtext1 },
            ["@variable.member"] = { fg = colors.red },
            ["@parameter"] = { fg = fall },
            ["@variable.parameter"] = { fg = fall },
            ["@number"] = { fg = colors.sapphire },
            ["@operator"] = { fg = cherry_blossom },
            ["@type"] = { fg = colors.yellow },
            ["@punctuation.delimiter"] = { fg = colors.subtext1 },
            ["@punctuation.special"] = { fg = cherry_blossom },
            DiagnosticUnderlineError = { style = { "undercurl" } },
            DiagnosticUnderlineWarn = { style = { "undercurl" } },
            DiagnosticUnderlineHint = { style = { "undercurl" } },

            -- golang
            ["@lsp.typemod.variable.defaultLibrary.go"] = { fg = colors.peach },
            ["@lsp.typemod.variable.readonly.go"] = { fg = colors.peach },
            ["@lsp.type.namespace.go"] = { fg = colors.subtext1, style = { "italic" } },
            ["@lsp.type.parameter.go"] = { fg = fall },
            ["@lsp.typemod.variable.member.go"] = { fg = colors.red },
            ["@lsp.typemod.variable.declaration.go"] = { fg = colors.red },
            ["@variable.member.go"] = { fg = colors.red },
            ["@lsp.mod.format.go"] = { fg = colors.pink },
            ["@lsp.typemod.string.format.go"] = { fg = colors.pink },

            -- JS/TS/JSX/TSX
            ["@keyword.operator.tsx"] = { fg = colors.mauve },
            ["@keyword.operator.ts"] = { fg = colors.mauve },
            ["@tag.builtin"] = { fg = colors.red },
            ["@tag.attribute"] = { fg = fall },
            ["@tag.attribute.tsx"] = { fg = fall },
            ["@tag.tsx"] = { fg = colors.yellow },
            ["@tag.delimiter"] = { link = "@punctuation.bracket" },
            ["@lsp.type.interface.typescript"] = { fg = colors.yellow },
            ["@keyword.operator.typescript"] = { fg = colors.mauve },
            ["@string.special.url.tsx"] = { fg = colors.green, style = { "underline" } },

            -- gleam
            ["@label.gleam"] = { fg = colors.red },
            ["@constructor.gleam"] = { fg = colors.yellow },

            -- protobuf
            ["@lsp.type.variable.proto"] = { fg = colors.red },

            -- zig
            ["@keyword.import.zig"] = { fg = colors.blue },
          }
        end,
      },
    })
    vim.cmd.colorscheme("catppuccin-mocha")
  end,
}
